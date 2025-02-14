clc; clear all;
cd('C:\Users\yoelgo\Desktop\MONAD_Git')
env = setupEnviroment('OSF_simple');

%% Load single participant
ID          = env.data.ID{1};
filename    = [env.paths.raw ID env.data.prefix];
EEG         = load_data(env, filename);
csv_init(env, ID);

clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
%% basic preproc
cfg            = [];
cfg.channel     = 'all';  % Do not remove ref1/ref2
cfg.detrend     = 'yes';
cfg.continuous  = 'yes';
cfg.hpfilter    = 'yes';
cfg.demean      = 'yes';
cfg.dftfilter   = 'yes';
cfg.dftfreq     = [env.data.linenoise env.data.linenoise*2]; % line noise removal
cfg.hpfreq      = 0.5;
cfg.reref       = 'yes';
cfg.refchannel  = {'ref1', 'ref2'};  
pEEG = ft_preprocessing(cfg, EEG);

csv_addCol(env, ID, {'hpfilter', 'dftfilter', 'detrend', 'demean'}, {cfg.hpfreq, cfg.dftfreq(1), cfg.detrend, cfg.demean});

%% high amplitude artifact detection
cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH', '-ref1', '-ref2'};
cfg.artfctdef.zvalue.cutoff      = 50;
cfg.artfctdef.zvalue.artpadding  = 0.1;
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
[cfg, z_artifact] = ft_artifact_zvalue(cfg, pEEG);

Zrem = sum(cfg.artfctdef.zvalue.artifact(:, 2) - cfg.artfctdef.zvalue.artifact(:, 1))/...
    size(pEEG.time{1},2) * 100;
csv_addCol(env, ID, {'Zval', 'Zart_num', 'Zremoved(%)'}, {cfg.artfctdef.zvalue.cutoff, ...
    size(cfg.artfctdef.zvalue.artifact,1), Zrem});
%% reject atrifact 
cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
pEEG_zclean = ft_rejectartifact(cfg,pEEG);

%save([env.paths.art ID '_Zartifact'], "z_artifact");
%% Manual: View Data
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 720;
man_artifact = ft_databrowser(cfg,pEEG_zclean)
save([env.paths.art ID '_MANartifact'], "z_artifact");
%% Manual: Remove Artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_artifact.artfctdef.visual.artifact;
datRaw_ref_zart = ft_rejectartifact(cfg,datRaw_ref_zart);

% update csv
if isempty(man_artifact.artfctdef.visual.artifact); man_artifact.artfctdef.visual.artifact = '--'; end
Mrem = sum(man_artifact.artfctdef.visual.artifact(:, 2) - man_artifact.artfctdef.visual.artifact(:, 1))/...
    size(pEEG_zclean.time{1},2) * 100;
csv_addCol(env, ID, {'MAN_art_num', 'MANremoved(%)'}, {size(man_artifact.artfctdef.visual.artifact,1), Mrem});
%% Manual: Remove Channel (by trial or all)
% Run this cell only if there are channels to remove
% A code I built which can fix a channel (based on adjacent channels) in
% either a specific trial or in all trials. 
badchannel = {''};      % insert the bad channel(s) name(s) here
trl = 3                 % 'all' or trial number to fix channel
if ~isempty(badchannel)
    cfg = [];
    cfg.layout      = lay ;
    cfg.method      = 'triangulation';
    neighbours      = ft_prepare_neighbours(cfg, datRaw_ref_zart);
    
    cfg = [];
    cfg.badchannel  = badchannel;
    cfg.neighbours  = neighbours;
    cfg.method      =  'spline';
    cfg.elec        = ft_read_sens('C:\Users\fire-\OneDrive - rus10\#LIFE\MA\EEG_Experiment\fieldtrip-20230522\template\electrode\standard_1020.elc')
    if trl ~= 'all'
        cfg2 = []
        cfg2.trials = trl
        tmp = ft_selectdata(cfg2,datRaw_ref_zart)
        tmp = ft_channelrepair(cfg, tmp);
        datRaw_ref_zart.trial{trl} =  tmp.trial{1}
    else
        datRaw_ref_zart = ft_channelrepair(cfg, datRaw_ref_zart);
    end
end
%% Run ICA
cfg = [];
cfg.method  = 'runica';
cfg.channel = {'eeg', '-A1', '-A2'};
comp = ft_componentanalysis(cfg, datRaw_ref_zart);
%% view ICA components
% view time seriers and topopraphy of ICs
cfg = [];
cfg.viewmode = 'component';
cfg.allowoverlap = 'yes';
cfg.continuous = 'yes';
cfg.blocksize = 30;
cfg.channel = 1:10;
cfg.layout = lay;
ft_databrowser(cfg,comp);

%% reject components
cfg = [];
cfg.component = [1,4]
dat_after_ICA = ft_rejectcomponent(cfg, comp);

%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 720;
man_artifact = ft_databrowser(cfg,dat_after_ICA)


%% save data after preproc
save([paths.clean_path subj_name '_clean'], "dat_after_ICA");
save([paths.trig_path subj_name '_trig_table'], "trig_table");
save([paths.trig_path subj_name '_block_table'], "block_table");
save([paths.trig_path subj_name '_baseline_table'], "baseline_table");
save([paths.trig_path subj_name '_all_table'], "all_table");
disp(['Saved All Data!']);
