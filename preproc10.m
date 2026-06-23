%% Clear all 
% cd('C:\Users\yoelgo\Documents\GitHub\MONAD_Git');
% cd('C:\Users\yarde\Documents\GitHub\MONAD_Git\');
clc; clear all; close all;
main_monad_git_folder = input('What is the path of MONAD_Git folder? ', 's');
if isempty(main_monad_git_folder)
    main_monad_git_folder=pwd;
end
cd(main_monad_git_folder)

%%
addpath("additional_functions")
addpath("analysis_MONAD\MONAD_preproc\OSF_simple\new_clean\")
%% load enviroment according to the experiment
% experiment names: 
% 'OSF_simple', 'TalKennet',
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)
env = setupEnviroment11(input('Enter experiment name (OSF_simple or TalKennet): ', 's'));
addpath(env.paths.extra_func);

%% Load single participant
clc;
s = 1; % participant number to load
ID          = env.data.ID{s}; 
disp(ID);

% check if there is already clean data of that ID
if contains(ID, env.data.clean_names) %|| any(contains(all_data(2,:), env.data.clean_names))
    rerun = input('Data already cleaned. Rerun pre-processing? Press 1 for yes, 0 to exit. ');
    if ~rerun
        error([ID ' Data already cleaned: Stopped running script'])
    end
end

filename    = env.data.files{s};
EEG         = load_data12(env, filename);

% initiate the ID in the CSV
csv_init15(env, ID);

% clean previous data to not create confusions
clear pEEG_zclean pEEG_mcleanCh pEEG pEEG_mclean man_art2 man_art comp badCh Mart dat_after_ICA
% clear weird stuff that comes when you load EEGlab data
clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

%% Look at raw data before doing anything
fs = EEG.fsample; % Get sampling frequnecy
nEEG= length(env.lay.label); % number of EEG channels

% % Variance of EEG channels
% Look at variance of channels and mark potential outliers
var_chans_raw=plot_var_all_chans(ID, EEG, nEEG, 'outlier_methods', {'zscore'}, 'window_sec', 0);
% According to sliding window
plot_var_all_chans(ID, EEG, nEEG, 'window_sec', 1);

% Display EEG channels- raw waveform
cfg = [];
cfg.channel = 'eeg';
cfg.demean      = 'yes';
cfg.detrend     = 'yes';
cfg.viewmode = 'vertical'; % Or 'butterfly' for overlaid channels
cfg.position = [1 41 1680 933];
% cfg.ylim = 'maxmin'; % Automatically fit all channels' data into the y-axis range
cfg.ylim = [-3 3]; % Replace with appropriate min and max values for your data
ft_databrowser(cfg, EEG);

% % Power spectrum of raw data of chosen channels
% Channels where the line noise is most visible are usually O1,O2
choose_chans(EEG,fs,s);
% Overlayed- all channels
plot_spect_all_chans(ID,EEG,length(env.lay.label),EEG.fsample,[],[],0)

%% basic preproc: demean, detrend, re-reference to the mean of all channels, 
% band pass filter and notch filters for line noise
cfg             = [];
cfg.demean      = 'yes';
cfg.detrend     = 'yes';
cfg.reref       = 'yes';
cfg.refchannel  = 'all';

% Initial Band-pass filter: 1–200 Hz (to be able to see muscle artefact)
cfg.bpfilter    = 'yes';
cfg.bpfreq      = [1 200];
cfg.bpfilttype  = 'but';
cfg.bpfiltord   = 3;
cfg.bpfiltdir   = 'twopass'; % zero-phase

% Notch filters to remove 50Hz/60Hz and harmonics
cfg.bsfilter    = 'yes';
notch_freq = input(sprintf(['Is the data recorded in the US (60hz line noise) or in Israel/Europe (50hz)? \n' ...
    'Put the number 50 or 60 accordingly, to apply notch filter around it.']));
notch_freq_and_harmonics=(notch_freq* (1:4))';
cfg.bsfreq      = [notch_freq_and_harmonics-1, notch_freq_and_harmonics+1];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 3; % 3rd order
cfg.bsfiltdir   = 'twopass'; % zero-phase

pEEG = ft_preprocessing(cfg, EEG);
plot_spect_all_chans(ID,pEEG,64,EEG.fsample,[],[],0,[],'after: demean, detrend, filters')
plot_power_spectrum_comparison(EEG, pEEG, ID, 'demean, detrend, filters', 'Cz')

csv_addCol16(env, ID,...
    {'bpfilter', 'bsfilter','detrend', 'demean'},...
    {mat2str(cfg.bpfreq), mat2str(cfg.bsfreq), cfg.detrend, cfg.demean});

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
cfg.artfctdef.zvalue.cutoff      = 50; % Flag samples with |Z| > 50 as artifacts
cfg.artfctdef.zvalue.artpadding  = 0.2; % Include 0.2s before & after artifact
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
[cfg, z_artifact] = ft_artifact_zvalue(cfg, pEEG);

% calculate the percent of data removed from the total data
Zrem = sum(cfg.artfctdef.zvalue.artifact(:, 2) - cfg.artfctdef.zvalue.artifact(:, 1))/...
    size(pEEG.time{1},2) * 100;

% add information to CSV log
csv_addCol16(env, ID, {'Zval', 'Zart_num', 'Z_rem'}, {cfg.artfctdef.zvalue.cutoff, ...
    size(cfg.artfctdef.zvalue.artifact,1), Zrem});
% reject atrifact 
cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
pEEG_zclean = ft_rejectartifact(cfg,pEEG);

save([env.paths.art ID '_Zartifact'], "z_artifact");
%% Manual: first look at the data
cfg = [];
cfg.ylim  = [-30 30];
man_blocksize = 30;
cfg.blocksize = man_blocksize;
man_art = ft_databrowser(cfg,pEEG_zclean);

%% Manual: remove manual artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art.artfctdef.visual.artifact;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_zclean);

cfg = [];
cfg.channel = {'all', '-eogV', '-eogH', '-IZ'};
pEEG_mclean = ft_selectdata(cfg,pEEG_mclean)

Mart = man_art.artfctdef.visual.artifact;
% update csv
if isempty(Mart); Mart = '--'; end
Mrem = sum(Mart(:, 2) - Mart(:, 1))/...
    size(pEEG_mclean.time{1},2) * 100;

save([env.paths.art ID '_MANartifact'], "Mart");
csv_addCol16(env, ID, {'manual_art_num', 'manual_rem', 'ch_interpolate', 'interpolated_sections'}, {size(Mart,1), Mrem, '--', '--'});
clear z_artifact Zrem Mrem 

%% Manual: fix bad channels
cfg =[];
cfg.env = env;
cfg.man_blocksize = man_blocksize;
cfg.badchannel = {'P8'};   % one or more channels (e.g., {'P8'} or {'P8', 'Cz'})
cfg.segment    = 'all';    % all or specific segments from the manual view data {{n1, m1}, {n2, m2}}. Note: see the segment number in the data viewer before with the blocksize set to 30.
cfg.remchannel = 'no';     % yes/no

% fix the channels
[pEEG_mcleanCh, cellBadCh, cellSegment] = fixChannels14(cfg, pEEG_mclean);

% save to the CSV
csv_addCol16(env, ID, {'ch_interpolate', 'interpolated_sections'}, ...
    {cellBadCh, cellSegment});
csv_addCol16(env, ID, {'remchannel'}, {cfg.remchannel});
clear singleCell_seg badchannel

% save information in the data
pEEG_mcleanCh.hdr.fixedChannels = cfg.badchannel;
pEEG_mcleanCh.hdr.remChannel = cfg.remchannel;

% view the data again to ensure channel fix
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 30;
ft_databrowser(cfg,pEEG_mcleanCh)

%% Final band-pass filter: 1,100Hz
cfg=[];
cfg.bpfilter    = 'yes';
cfg.bpfreq      = [1 100];
cfg.bpfilttype  = 'but';
cfg.bpfiltord   = 3;
cfg.bpfiltdir   = 'twopass'; % zero-phase
pEEG_mcleanCh_fb = ft_preprocessing(cfg, pEEG_mcleanCh);

%% Run ICA
addpath([env.paths.ft_path 'external\eeglab\']);
cfg = [];
cfg.method  = 'runica';
cfg.numcomponent = 20;
%cfg.runica.maxsteps = 100;
comp = ft_componentanalysis(cfg, pEEG_mcleanCh);
%% view ICA components
% view time seriers and topopraphy of ICs
cfg = [];
cfg.viewmode = 'component';
cfg.allowoverlap = 'yes';
cfg.continuous = 'yes';
cfg.blocksize = 50;
cfg.layout = env.lay;
cfg.ylim  = [-550 550];
% Show the first 20 components
cfg.channel = comp.label(1:20);

ft_databrowser(cfg, comp);

% save the figure of the components for quality check.
fig = gcf;
saveas(fig, [env.paths.ICApng env.exp '_' ID '_ICAcomp.png']);

%% reject components
cfg = [];
cfg.component = input('Which Component number do you wish to reject? e.g., 2, [1,3,20] : '); % e.g., [1,3,20]
dat_after_ICA = ft_rejectcomponent(cfg, comp);

comp_idx = {arrayfun(@num2str, cfg.component, 'UniformOutput', false)};
comp_idx = strjoin(comp_idx{1}, ', ');
csv_addCol16(env, ID, {'ICA_comp'}, {comp_idx});
%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 100;
man_art2 = ft_databrowser(cfg,dat_after_ICA);

%% Manual: Remove Artifacts
cfg = []; 
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_art2.artfctdef.visual.artifact;
dat_after_ICA = ft_rejectartifact(cfg,dat_after_ICA);

%% keep data in array to be saved later
j=0;
j = j + 1;
all_data{1,j} = {dat_after_ICA};
all_data{2,j} = ID;
disp('data added!')

%% save all datasets
for i=1:length(all_data)
    ID = all_data{2,i};
    dat_after_ICA = all_data{1,i};
    save([env.paths.clean ID '_clean'], "dat_after_ICA");
end
%% or instead save the specific data you were working on now
save([env.paths.clean ID '_clean'], "dat_after_ICA");
save([env.paths.art ID '_ICAcomp'], "comp");
disp(['Saved Data!']);
