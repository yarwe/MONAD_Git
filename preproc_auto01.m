clc; clear all;
cd('C:\Users\yoelgo\Desktop\MONAD_Git');
env = setupEnviroment('OSF_simple');
%% Load single participant
ID          = env.data.ID{10};
filename    = [env.paths.raw ID env.data.prefix];
EEG         = load_data(env, filename);
csv_init(env, ID);

clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
%% basic preproc
cfg            = [];
cfg.channel     = {'all'};  % Do not remove ref1/ref2
cfg.detrend     = 'yes';
cfg.continuous  = 'yes';
cfg.hpfilter    = 'yes';
cfg.demean      = 'yes';
cfg.dftfilter   = 'yes';
cfg.dftfreq     = [env.data.linenoise env.data.linenoise*2]; % line noise removal
cfg.lpfilter    = 'yes';
cfg.lpfreq      = 80;
cfg.hpfreq      = 0.5; 
pEEG = ft_preprocessing(cfg, EEG);

csv_addCol(env, ID, {'hpfilter', 'lpfilter', 'dftfilter','detrend', 'demean'}, {cfg.hpfreq, cfg.lpfreq ,cfg.dftfreq(1), cfg.detrend, cfg.demean});

cfg = []; 
cfg.reref       = 'yes';
cfg.refchannel  = {'ref1' 'ref2'}; 
pEEG = ft_preprocessing(cfg,pEEG); 

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
csv_addCol(env, ID, {'Zval', 'Zart_num', 'Z_rem'}, {cfg.artfctdef.zvalue.cutoff, ...
    size(cfg.artfctdef.zvalue.artifact,1), Zrem});
%% reject atrifact 
cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
pEEG_zclean = ft_rejectartifact(cfg,pEEG);

save([env.paths.art ID '_Zartifact'], "z_artifact");
%% Manual: View Data
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 30;
man_art = ft_databrowser(cfg,pEEG_zclean)

man_art = man_art.artfctdef.visual.artifact;
%save([env.paths.art ID '_MANartifact'], "man_art");
%% Manual: Remove Artifacts
%man_art = load([env.paths.art ID '_MANartifact']);
%man_art = man_art.man_art;
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_zclean);

cfg = [];
cfg.channel = {'all', '-eogV', '-eogH', '-ref1', '-ref2'};
pEEG_mclean = ft_selectdata(cfg,pEEG_mclean)


% update csv
if isempty(man_art); man_art = '--'; end
Mrem = sum(man_art(:, 2) - man_art(:, 1))/...
    size(pEEG_zclean.time{1},2) * 100;
csv_addCol(env, ID, {'manual_art_num', 'manual_rem', 'ch_interpolate'}, {size(man_art,1), Mrem, '--'});
clear z_artifact Zrem Mrem man_art 
%% Manual: Remove Channel (by trial or all)
% Run this cell only if there are channels to remove
% A code I built which can fix a channel (based on adjacent channels) in
% either a specific trial or in all trials. 
badchannel = {''};      % insert the bad channel(s) name(s) here
trl = 'all'                 % 'all' or trial number to fix channel
if ~isempty(badchannel)
    cfg = [];
    cfg.layout      = env.lay;
    cfg.method      = 'triangulation';
    neighbours      = ft_prepare_neighbours(cfg, pEEG_mclean);
    
    cfg = [];
    cfg.badchannel  = badchannel;
    cfg.neighbours  = neighbours;
    cfg.method      =  'spline';
    cfg.elec        = ft_read_sens("C:\Users\yoelgo\Documents\fieldtrip-20250114\template\electrode\standard_1020.elc")
    if trl ~= 'all'
        cfg2 = []
        cfg2.trials = trl
        tmp = ft_selectdata(cfg2,pEEG_mclean)
        tmp = ft_channelrepair(cfg, tmp);
        pEEG_mclean.trial{trl} =  tmp.trial{1}
    else
        pEEG_mclean = ft_channelrepair(cfg, pEEG_mclean);
    end
end

csv_addCol(env, ID, {'ch_interpolate'}, {badchannel});
%% Run ICA
addpath([env.paths.ft_path 'external\eeglab\']);
cfg = [];
cfg.method  = 'runica';
comp = ft_componentanalysis(cfg, pEEG_mclean);
%% view ICA components
% view time seriers and topopraphy of ICs
cfg = [];
cfg.viewmode = 'component';
cfg.allowoverlap = 'yes';
cfg.continuous = 'yes';
cfg.blocksize = 50;
cfg.layout = env.lay;
ft_databrowser(cfg,comp);
%save([env.paths.art ID '_ICAcomp'], "comp");

%%
%%%%%%%%
onlyInA = setdiff(env.lay.label, pEEG_mclean.label);
onlyInA = setdiff(pEEG_mclean.label, env.lay.label);

cfg = [];
cfg.channel = pEEG_mclean.label{13}
cfg.latency = [10 100];
signal1 = ft_selectdata(cfg, pEEG_mclean)


cfg = [];
cfg.latency = [10 100];
cfg.channel = pEEG_mclean.label{12}
signal2 = ft_selectdata(cfg, pEEG_mclean)

[r, p_corr] = corr(signal1.trial{1}', signal2.trial{1}');
%%
cfg=[];
cfg.method='summary'; %channel %trial %summary
cfg.keepchannels = 'nan';
cfg.channel = {dat_after_ICA.label{33:62}};
cfg.layout = env.lay;
data_2 = ft_rejectvisual(cfg, dat_after_ICA);
%%%%%%%%
%% reject components
cfg = [];
cfg.component = [1]
dat_after_ICA = ft_rejectcomponent(cfg, comp);


csv_addCol(env, ID, {'ICA_comp'}, {strjoin(string(cfg.component), ', ')});
%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 720;
man_art = ft_databrowser(cfg,dat_after_ICA)

%% Manual: Remove Artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_art.artfctdef.visual.artifact;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_mclean);

%%
pEEG_mclean.trial = pEEG_mclean.trial{1}(:,35588:end)
pEEG_mclean.time  = pEEG_mclean.time{1}(:,35588:end);
%% save data after preproc
save([paths.clean_path subj_name '_clean'], "dat_after_ICA");
save([paths.trig_path subj_name '_trig_table'], "trig_table");
save([paths.trig_path subj_name '_block_table'], "block_table");
save([paths.trig_path subj_name '_baseline_table'], "baseline_table");
save([paths.trig_path subj_name '_all_table'], "all_table");
disp(['Saved All Data!']);
