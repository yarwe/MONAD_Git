%% MONAD Preprocessing Pipeline - Visualization Examples
% This script generates exemplary plots showcasing each stage of the EEG preprocessing pipeline
% Data locations (not directly accessed, referenced for user):
%   Clean data: analysis_MONAD/MONAD_preproc/{e.g., OSF_simple,TalKennet}/new_clean/
%   Raw data:   e.g., NIMH data/eeg_sub_files01/tac_vib/ (FIF format)
%               or OSF data/Simple/ (BDF format)

clear all; close all; clc;

%% Setup paths and parameters
main_monad_git_folder = input('What is the path of MONAD_Git folder? ', 's');
cd(main_monad_git_folder);
addpath("additional_functions");
addpath("C:\Users\yarde\Documents\MATLAB\") % For functions look_eyeblinks_af_ICA

% User inputs for which dataset and subject to visualize
experiment = input('Enter experiment name (OSF_simple or TalKennet): ', 's');
subject_id = input('Enter subject ID to visualize (e.g., 011201, A10): ', 's');

% Define data paths
clean_data_path = fullfile(pwd, 'analysis_MONAD', 'MONAD_preproc', experiment, 'new_clean\');

%% Load
% Load environment
env = setupEnviroment11(experiment);
addpath(env.paths.extra_func);

% Load datasets
find_subject_idx = @(subject_id, id_list) find(strcmp(id_list, subject_id), 1);
s=find_subject_idx(subject_id, env.data.ID);
while isempty(s)
    warning('Subject %s do not exist.',subject_id)
    subject_id = input('Enter subject ID to visualize (e.g., 011201, A10): ', 's');
    s=find_subject_idx(subject_id, env.data.ID);
end
filename_raw    = env.data.files{s};
EEG_raw         = load_data12(env, filename_raw);
clear EEG ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

EEG_pre_clean=load(fullfile(clean_data_path, subject_id + "_clean"));
EEG_clean = EEG_pre_clean.dat_after_ICA{1};   

clear EEG_pre_clean
%% ========================================================================
%                         PLOTTING FUNCTIONS
% =========================================================================

%% 1. SIGNAL BEFORE/AFTER DETREND, FILTERS, ICA etc.
% Individual and group-level comparison
plot_signal_comparison(EEG_raw, EEG_clean, subject_id, 'T8')

%% 2. POWER SPECTRUM BEFORE/AFTER DETREND, FILTERS, ICA etc.
plot_power_spectrum_comparison(EEG_raw, EEG_clean, subject_id, 'Cz')

%% 3. ICA COMPONENTS - TOPOGRAPHY AND TIME SERIES
plot_ica_components(comp, env.lay, 10, subject_id)

%% 4.a FP1/FP2 BEFORE AND AFTER pre-processing
plot_frontal_channels_ica(EEG_raw, EEG_clean, subject_id, [20000, 60000])

%% 4.b. - PLOT eye blinks before anf after ICA, focusing on only eye-blinks epochs
chans_blinks={'Fp1','Fp2'}; 
thres_lowpass_eyeblink_detect=[];
look_eye_blinks_af_ICA(s, chans_blinks, thres_lowpass_eyeblink_detect,EEG_raw,EEG_clean,fs,0,[],[],1)

%% 5. AUTOMATIC ARTIFACT REJECTION VISUALIZATION
plot_automatic_artifacts(EEG_raw, EEG_clean.cfg.previous.previous{1}.previous.previous.previous.artfctdef.visual.artifact, subject_id, 3)

%% 6. MANUAL ARTIFACT REJECTION VISUALIZATION
plot_manual_artifacts(EEG_raw, EEG_clean.cfg.previous{1}.previous.previous.artfctdef.visual.artifact, subject_id, [4 6 7])
