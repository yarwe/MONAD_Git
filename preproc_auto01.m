%% Clear all 
cd('C:\Users\yoelgo\Documents\GitHub\MONAD_Git');
%cd('C:\Users\yarde\Documents\GitHub\MONAD_Git\');
clc; clear all; close all;
%%
env = setupEnviroment('OSF_simple');
addpath(env.paths.extra_func);
%% Load single participant
% skipped ID{1} in the OSF_simple because the ICA didn't converge
% skipped ID{18} since he was very noisy.
ID          = env.data.ID{22};
filename    = [env.paths.raw ID env.data.prefix];
EEG         = load_data(env, filename);
csv_init(env, ID);

clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

%% basic preproc
cfg             = [];
cfg.channel     = 'all';  % Do not remove ref1/ref2
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

csv_addCol(env, ID,...
    {'hpfilter', 'lpfilter', 'dftfilter','detrend', 'demean'},...
    {cfg.hpfreq, cfg.lpfreq ,cfg.dftfreq(1), cfg.detrend, cfg.demean});

cfg = []; 
cfg.reref       = 'yes';
cfg.refchannel  = {'ref1' 'ref2'}; 
pEEG = ft_preprocessing(cfg,pEEG); 

cfg = [];
cfg.channel = {'all', '-ref1', '-ref2'};
pEEG = ft_selectdata(cfg, pEEG);

%% high amplitude artifact detection
cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH', '-ref1', '-ref2'};
cfg.artfctdef.zvalue.cutoff      = 50;
cfg.artfctdef.zvalue.artpadding  = 0.2;
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
man_blocksize = 30;
cfg.blocksize = man_blocksize;
man_art = ft_databrowser(cfg,pEEG_zclean)

man_art = man_art.artfctdef.visual.artifact;
save([env.paths.art ID '_MANartifact'], "man_art");
%% Manual: Remove Artifacts
%man_art = load([env.paths.art ID '_MANartifact']);
%man_art = man_art.man_art;
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_zclean);

cfg = [];
cfg.channel = {'all', '-eogV', '-eogH'};
pEEG_mclean = ft_selectdata(cfg,pEEG_mclean)


% update csv
if isempty(man_art); man_art = '--'; end
Mrem = sum(man_art(:, 2) - man_art(:, 1))/...
    size(pEEG_zclean.time{1},2) * 100;
csv_addCol(env, ID, {'manual_art_num', 'manual_rem', 'ch_interpolate', 'interpolated_sections'}, {size(man_art,1), Mrem, '--', '--'});
clear z_artifact Zrem Mrem man_art 
%% Manual: Remove Channel (by trial or all)
% Run this cell only if there are channels to remove
% A code I built which can fix a channel (based on adjacent channels) in
% either a specific trial or in all trials. 
badchannel = {''};      % insert the bad channel(s) name(s) here
segment = {38 'lst'};                 % 'all' or trial number to fix channel

if ~isempty(badchannel)
    cfg = [];
    cfg.layout      = env.lay;
    cfg.method      = 'triangulation';
    neighbours      = ft_prepare_neighbours(cfg, pEEG_mclean);
    
    cfg = [];
    cfg.badchannel  = badchannel;
    cfg.neighbours  = neighbours;
    cfg.method      =  'spline';
    cfg.elec        = ft_read_sens([env.paths.ft_path 'template\electrode\standard_1020.elc']);
    if ~any(strcmp(segment,'all'))
        if strcmp(segment{2}, 'lst')
            segment{2} = ceil(EEG.time{1}(end)/man_blocksize);
        end
        segment{1} = segment{1} * man_blocksize;
        segment{2} = segment{2} * man_blocksize;
        cfg2 = [];
        cfg2.latency = [segment{1}, segment{2}];
        tmp = ft_selectdata(cfg2,pEEG_mclean);
        tmp = ft_channelrepair(cfg, tmp);

        [~, t1] = min(abs(pEEG_mclean.time{1} - segment{1}));
        [~, t2] = min(abs(pEEG_mclean.time{1} - segment{2}));
        chan_idx = find(strcmp(badchannel, pEEG_mclean.label));
        pEEG_mclean.trial{1}(chan_idx,t1:t2) =  tmp.trial{1}(chan_idx,:);
    else
        pEEG_mclean = ft_channelrepair(cfg, pEEG_mclean);
    end
end
singleCell = {mat2str(cell2mat(segment))};
csv_addCol(env, ID, {'ch_interpolate', 'interpolated_sections'}, {badchannel, singleCell});
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
fig = gcf;
saveas(fig, [env.paths.ICApng env.exp '_' ID '_components.png']);


%% reject components
cfg = [];
cfg.component = [1];
dat_after_ICA = ft_rejectcomponent(cfg, comp);

csv_addCol(env, ID, {'ICA_comp'}, {string(cfg.component)});
%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 100;
man_art = ft_databrowser(cfg,dat_after_ICA)

%% Manual: Remove Artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_art.artfctdef.visual.artifact;
%pEEG_mclean = ft_rejectartifact(cfg,pEEG_mclean);

%% save data after preproc
save([env.paths.clean ID '_clean'], "dat_after_ICA");
save([env.paths.art ID '_ICAcomp'], "comp");
disp(['Saved Data!']);