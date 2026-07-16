%% Clear all 
cd('C:\Users\yoelgo\Documents\GitHub\MONAD_Git');
%cd('C:\Users\yarde\Documents\GitHub\MONAD_Git\');
clc; clear all; close all;

%% %% Add paths

% addpath("analysis_MONAD\MONAD_preproc\OSF_simple\new_clean\")

%% Notch filters to remove 50Hz/60Hz and harmonics
cfg.bsfilter    = 'yes';
notch_freq = input(sprintf(['Is the data recorded in the US (60hz line noise) or in Israel/Europe (50hz)? \n' ...
    'Put the number 50 or 60 accordingly, to apply notch filter around it.']));
notch_freq_and_harmonics=(notch_freq* (1:2))';
cfg.bsfreq      = [notch_freq_and_harmonics-1, notch_freq_and_harmonics+1];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 3; % 3rd order
cfg.bsfiltdir   = 'twopass'; % zero-phase

%%
% exp: 'OSF_simple', 'TalKennet', 'NMSG' (Neural Markers of Shared Gaze...)
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)
env = setupEnviroment('NMSG');
addpath(env.paths.extra_func);

%% Automatic Artefact dection - high amplitude artifact detection
% GUI explaination:
% < or > : jump to previous/next flagged segment
% artifact: Accept Marked "red" areas as artefacts.
% << >>: Scroll through entire recording
% keep trial: Mark as CLEAN - False positive - Z-score wrongly flagged normal data
% reject full: Confirm Z-score detection was correct, but rejects the FULL
% segment (even the clean parts).
% reject part: Draw custom artifact boundaries (drag on plot). Use if Z-score boundaries are currently wrong
% threshold: Adjust cutoff: Change the Z-score threshold on the fly with < and >
% stop: Done reviewing - Exit the GUI and save your corrections
cfg = [];
cfg.continuous                   = 'yes'; % Data is continuous (no trial boundaries)
cfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH'};
cfg.artfctdef.zvalue.cutoff      = 6; % Flag samples with |Z| > 50 as artifacts
cfg.artfctdef.zvalue.artpadding  = 0.2; % Include 0.2s before & after artifact
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
[cfg, z_artifact] = ft_artifact_zvalue(cfg, EEG);

%% Load single participant
% skipped OSF_simple ID{1} in the OSF_simple because the ICA didn't stop
% skipped OSF_simple ID{18} since he was very noisy.
% skipped OSF_simple ID{23} in the OSF_simple because the ICA lrate didn't converge
% skipped OSF_simple ID{24} in the OSF_simple because the ICA lrate didn't converge
% skipped OSF_simple ID{25} in the OSF_simple because the ICA didn't stop
% skipped OSF_simple ID{40} in the OSF_simple because the ICA didn't stop
% skipped OSF_simple ID{43} in the OSF_simple because the ICA lrate didn't converge
% skipped OSF_simple ID{44} had wierd topography in ICA
% skipped OSF_simple ID{45} had wierd topography in ICA
% skipped OSF_simple ID{47} had wierd topography in ICA
% skipped OSF_simple ID{50} in the OSF_simple because the ICA lrate didn't converge
% skipped OSF_simple ID{52} in the OSF_simple because the ICA lrate didn't converge
s = 5;
ID          = env.data.ID{s}; 
filename    = env.data.files{s};
EEG         = load_data(env, filename);
%csv_init(env, ID);

clear s ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

%% basic preproc
cfg             = [];
cfg.channel     = 'all';  % Do not remove ref1/ref2
cfg.detrend     = 'yes';
cfg.continuous  = 'yes';
cfg.hpfilter    = 'yes';
cfg.demean      = 'yes';
%cfg.dftfilter   = 'yes';
%cfg.dftfreq     = [env.data.linenoise env.data.linenoise*2]; % line noise removal
cfg.lpfilter    = 'yes';
cfg.lpfreq      = 80;
cfg.hpfreq      = 0.6;
pEEG = ft_preprocessing(cfg, EEG);

%csv_addCol(env, ID,...
%    {'hpfilter', 'lpfilter', 'dftfilter','detrend', 'demean'},...
%    {cfg.hpfreq, cfg.lpfreq ,cfg.dftfreq(1), cfg.detrend, cfg.demean});


%% high amplitude artifact detection
cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH'};
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
man_art = ft_databrowser(cfg,pEEG_zclean);

%% Manual: Remove Artifacts
%man_art = load([env.paths.art ID '_MANartifact']);
%man_art = man_art.man_art;
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art.artfctdef.visual.artifact;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_zclean);

cfg = [];
cfg.channel = {'all', '-eogV', '-eogH'};
pEEG_mclean = ft_selectdata(cfg,pEEG_mclean)

man_art = man_art.artfctdef.visual.artifact;
% update csv
if isempty(man_art); man_art = '--'; end
Mrem = sum(man_art(:, 2) - man_art(:, 1))/...
    size(pEEG_zclean.time{1},2) * 100;

save([env.paths.art ID '_MANartifact'], "man_art");
csv_addCol(env, ID, {'manual_art_num', 'manual_rem', 'ch_interpolate', 'interpolated_sections'}, {size(man_art,1), Mrem, '--', '--'});
clear z_artifact Zrem Mrem 
%% Manual: Remove Channel (by trial or all)
% Run this cell only if there are channels to remove
% A code I built which can fix a channel (based on adjacent channels) in
% either a specific trial or in all trials. 
badchannel = {'O2', 'P10'};      % insert the bad channel(s) name(s) here
seg = {{0 'lst'},{0 'lst'}};                 % 'all' or trial number to fix channel
%seg = {{0,'lst'}};                 % 'all' or trial number to fix channel
if ~isempty(badchannel)
    cfg = [];
    cfg.layout      = env.lay;
    cfg.method      = 'triangulation';
    neighbours      = ft_prepare_neighbours(cfg, pEEG_mclean);

    for i=1:length(badchannel)
        cfg = [];
        cfg.badchannel  = {badchannel{i}};
        cfg.neighbours  = neighbours;
        cfg.method      =  'spline';
        cfg.elec        = ft_read_sens([env.paths.ft_path 'template\electrode\standard_1020.elc']);
        segment = seg{i};
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
        chan_idx = find(strcmp(badchannel{i}, pEEG_mclean.label));
        pEEG_mclean.trial{1}(chan_idx,t1:t2) =  tmp.trial{1}(chan_idx,:);
    end
else
    pEEG_mclean = ft_channelrepair(cfg, pEEG_mclean);
end

singleCell_seg = cellfun(@mat2str, [seg{:}], 'UniformOutput', false);
singleCell_seg = {strjoin(singleCell_seg, ',')};

if length(badchannel) > 1; badchannel = {strjoin(badchannel, ', ')}; end
csv_addCol(env, ID, {'ch_interpolate', 'interpolated_sections'}, {badchannel, singleCell_seg});
clear singleCell_seg badchannel

%%
%cfg = [];
%cfg.badchannel  = {'Fpz'};
%cfg.neighbours  = neighbours;
%cfg.method      =  'spline';
%cfg.elec        = ft_read_sens([env.paths.ft_path 'template\electrode\standard_1020.elc']);
%pEEG_mclean = ft_channelrepair(cfg,pEEG_mclean);
%% Run ICA
addpath([env.paths.ft_path 'external\eeglab\']);
cfg = [];
cfg.method  = 'runica';
cfg.runica.maxsteps = 100;
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

comp_idx = {arrayfun(@num2str, cfg.component, 'UniformOutput', false)};
comp_idx = strjoin(comp_idx{1}, ', ');
csv_addCol(env, ID, {'ICA_comp'}, {comp_idx});
%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 100;
%man_art2 = ft_databrowser(cfg,pEEG_mclean)
%man_art2 = ft_databrowser(cfg,dat_after_ICA);
man_art2 = ft_databrowser(cfg,vEEG)
%% Manual: Remove Artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_art2.artfctdef.visual.artifact;
dat_after_ICA = ft_rejectartifact(cfg,dat_after_ICA);

%% save data after preproc
save([env.paths.clean ID '_clean'], "dat_after_ICA");
save([env.paths.art ID '_ICAcomp'], "comp");
disp(['Saved Data!']);

%%
cfg =[];
cfg.channel = 1:64
x = ft_selectdata(cfg,pEEG)

%%
vEEG = EEG
vEEG.trial{1} = vEEG.trial{1}*10^6

vEEG.label = env.lay.layout.label(1:70)