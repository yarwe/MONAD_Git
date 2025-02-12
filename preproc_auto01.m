clc; clear all;
cd('C:\Users\fire-\OneDrive - rus10\#LIFE\UCL RA\MONAD\MONAD_Git')
env = setupEnviroment('OSF_simple');

%% Load single participant
ID              = env.data.ID{1};
cfg             = [];
cfg.dataset     = [env.paths.raw ID env.data.prefix];
cfg.continuous  = 'yes';
%dat1 = ft_preprocessing(cfg);
data = ft_read_data(cfg.dataset);


%% chatGPT code
clear; clc;

% Add FieldTrip to MATLAB path
addpath('~/Documents/MATLAB/fieldtrip');
ft_defaults;

% Define paths
data_path = '~/Documents/';  % Path for .bdf files
output_path = '~/Documents/Processed/';  % Path to save processed data

% Subject identifiers
P = {'A1' 'A2' 'A3' 'A4' 'A5' 'A6' 'A7' 'A8' 'A9' 'A10' 'A11' 'A12' 'A13' 'A14' 'A15' 'A16' 'A17' 'A18' 'A19' 'A20' 'A21' 'A22' 'A23' 'A24' 'A25'...
     'C1' 'C2' 'C3' 'C4' 'C5' 'C6' 'C7' 'C8' 'C9' 'C10' 'C11' 'C12' 'C13' 'C14' 'C15' 'C16' 'C17' 'C18' 'C19' 'C20' 'C21' 'C22' 'C23' 'C24' 'C25' 'C26' 'C27' 'C28'};
 
% Recording types
mods = {'SimpleTone', 'ComplexSound'};

% Preprocessing loop
for subj = 1:length(P)
    for mod_idx = 1:length(mods)
        
        % File path
        file_path = fullfile(cfg.dataset);
        
        % Configuration for reading data
        cfg = [];
        cfg.dataset = file_path;
        cfg.continuous = 'yes';
        
        % Read header info to identify channels
        hdr = ft_read_header(file_path);
        
        % Define referencing to average mastoids (assuming 129 and 130 are mastoids)
        cfg.reref = 'yes';
        cfg.refchannel = {'EXG5', 'EXG6'}; % Adjust these names based on your channel labels
        cfg.refmethod = 'average';
        
        % Apply bandpass filter (0.1 - 100 Hz)
        cfg.hpfilter = 'yes';
        cfg.hpfreq = 0.1;
        cfg.lpfilter = 'yes';
        cfg.lpfreq = 100;
        
        % Preprocess data
        data = ft_preprocessing(cfg);
        
        % Save preprocessed data
        save_file = fullfile(output_path, [P{subj} '_' mods{mod_idx} '_filt.mat']);
        save(save_file, 'data', '-v7.3');
        
    end
end
%%
%% Seperate ECG and basic preproc
cfg = [];
cfg.channel = {'ECG1', 'ECG2'};
ECG_dat = ft_selectdata(cfg,dat1);
cfg = [];
cfg.detrend = 'yes';
cfg.demean = 'yes';
cfg.lpfilter = 'yes';
cfg.bsfilter = 'yes';
cfg.bsfreq = [49.5 50.5];
cfg.hpfilter = 'yes';
cfg.hpfreq   = 5;
cfg.lpfreq   = 45;
ECG_dat = ft_preprocessing(cfg,ECG_dat);


cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = 'all';
cfg.artfctdef.zvalue.cutoff      = 15;
cfg.artfctdef.zvalue.artpadding  = 0.1;
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
[cfg, z_artifact] = ft_artifact_zvalue(cfg, ECG_dat);

cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
ECG_dat = ft_rejectartifact(cfg,ECG_dat);

cfg = [];
cfg.channel = {'all', '-ECG1', '-ECG2'};
dat1 = ft_selectdata(cfg, dat1);

save([paths.ECG_path subj_name 'raw_ECG_dat'], "ECG_dat");
disp 'ECG data saved!'
%% Use trigger channels to seperate into blocks
% At the beggining and end of each part (basleine 1, drumming, basline 2)
% there is a long beep. At the end of the whole block there is a longer
% beep. Furhtermore, there is a trigger for each beat in the rhythm.
% trig_table = triggers of each drum beat.
% block_table = start and end of each drumming section.
% baseline_table = start and end of each baseline (1 and 2) section.
% alltime_table = start and end of each block (baseline1, rhythm, baseline2 combined)
cfg = [];
cfg.channel = {'AC_Trigger1', 'AC_Trigger2'};
trig_dat = ft_selectdata(cfg,dat1);
trig_dat = trig_dat.trial{1}(2,:);
[trig_table, block_table, baseline_table, alltime_table, all_table] = create_trig_table_S2(trig_dat);

%% redefine to blocks for preprocessing
% Here I keep only data from baseline1 baseline2 and rhythm.
cfg = [];
cfg.trl = alltime_table{:,:};
block_data = ft_redefinetrial(cfg, dat1);
%% basic preproc
cfg            = [];
cfg.channel    = 'EEG';
cfg.detrend    = 'yes';
cfg.continuous = 'yes';
cfg.hpfilter    = 'yes';
cfg.hpfreq      = 0.5;
cfg.dftfilter = 'yes';
cfg.dftfreq = [50 100]; % line noise removal
cfg.reref      = 'yes';
cfg.refchannel = {'A1' 'A2'}; % A1 and A2 are the ear-clips
raw = ft_preprocessing(cfg, block_data);

%% high amplitude artifact detection
cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = 'all';
cfg.artfctdef.zvalue.cutoff      = 50;
cfg.artfctdef.zvalue.artpadding  = 0.1;
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
[cfg, z_artifact] = ft_artifact_zvalue(cfg, raw);
%% reject atrifact 
cfg = []; 
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
datRaw_ref_zart = ft_rejectartifact(cfg,raw);

%% Manual: View Data
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 720;
man_artifact = ft_databrowser(cfg,datRaw_ref_zart)
save([artifact_path subj_name '_man_artifact'], "man_artifact");
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
