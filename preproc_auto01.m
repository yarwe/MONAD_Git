clc; clear all;
cd('C:\Users\yoelgo\Desktop\MONAD_Git')
env = setupEnviroment('OSF_simple');

%% Load single participant
ID          = env.data.ID{1};
filename    = [env.paths.raw ID env.data.prefix];
EEG         = load_data(env, filename);

clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
%% basic preproc
Pcfg            = [];
Pcfg.channel    = 'all';  % Do not remove ref1/ref2
Pcfg.detrend    = 'yes';
Pcfg.continuous = 'yes';
Pcfg.hpfilter    = 'yes';
Pcfg.dftfilter = 'yes';
Pcfg.dftfreq = [env.data.linenoise env.data.linenoise*2]; % line noise removal
Pcfg.hpfreq      = 0.5;
Pcfg.reref      = 'yes';
Pcfg.refchannel = {'ref1', 'ref2'};  
pEEG = ft_preprocessing(Pcfg, EEG);

%% high amplitude artifact detection
Zcfg = [];
Zcfg.continuous                   = 'yes';
Zcfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH', '-ref1', '-ref2'};
Zcfg.artfctdef.zvalue.cutoff      = 50;
Zcfg.artfctdef.zvalue.artpadding  = 0.1;
Zcfg.artfctdef.zvalue.zscore      = 'yes';
Zcfg.artfctdef.zvalue.interactive = 'yes';
[Zcfg, z_artifact] = ft_artifact_zvalue(Zcfg, pEEG);

%% reject atrifact 
cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
pEEG_zclean = ft_rejectartifact(cfg,pEEG);

save([env.paths.art ID '_Zartifact'], "z_artifact");
writeCSV_auto(env,ID,Pcfg, Zcfg, pEEG);
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
