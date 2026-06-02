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
if isstruct(EEG_pre_clean)
    EEG_clean = EEG_pre_clean.dat_after_ICA;
elseif iscell(EEG_pre_clean)
    EEG_clean = EEG_pre_clean.dat_after_ICA{1};   
end
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
plot_ica_components(comp, cfg_layout, 10, subject_id)

%% 4. FP1/FP2 BEFORE AND AFTER pre-processing
plot_frontal_channels_ica(raw_data_path, clean_data_path, subject_id)

%% 5. AUTOMATIC ARTIFACT REJECTION VISUALIZATION
plot_automatic_artifacts(data_with_artifacts, artifact_samples, subject_id, max_segments)

%% 6. MANUAL ARTIFACT REJECTION VISUALIZATION
plot_manual_artifacts(data_before_removal, artifact_samples, subject_id, max_segments)

%% ========================================================================
%                      MAIN EXECUTION
% =========================================================================

% Example usage - User selects which plots to generate
disp('================================');
disp('Available plots:');
disp('1. Signal before/after filtering');
disp('2. Power spectrum before/after ICA');
disp('3. ICA components topography & time series');
disp('4. FP1/FP2 before and after ICA');
disp('5. Automatic artifact detection');
disp('6. Manual artifact rejection');
disp('0. Generate all plots');
disp('================================');

plot_choice = input('Select plot(s) to generate (e.g., 1 or [1,2,4] or 0 for all): ');

if plot_choice == 0
    plot_choice = [1, 2, 3, 4, 5, 6];
end

% Load data for chosen subject
% NOTE: User should load clean and raw data from the specified paths
% This is pseudocode showing the structure

disp(sprintf('\nLoading data for subject: %s', subject_id));
disp('Please load raw and clean data from:');
disp(sprintf('  Raw: %s', raw_data_path));
disp(sprintf('  Clean: %s', clean_data_path));

% Placeholder for actual data loading
disp('Data loading structure (user must implement based on their data format):');
disp('  raw_data = ft_read_data(raw_file); % For BDF or FIF files');
disp('  clean_data = load([clean_path, subject_id, ''_clean'']); % For .mat files');

disp(sprintf('\nTo use these functions, load your data and call:'));
if ismember(1, plot_choice)
    disp('  plot_filter_comparison(raw_data, filtered_data, subject_id);');
end
if ismember(2, plot_choice)
    disp('  plot_power_spectrum_comparison(raw_data, ica_data, subject_id, ''Cz'');');
end
if ismember(3, plot_choice)
    disp('  plot_ica_components(comp_structure, layout, 10, subject_id);');
end
if ismember(4, plot_choice)
    disp('  plot_frontal_channels_ica(raw_data, ica_data, subject_id);');
end
if ismember(5, plot_choice)
    disp('  plot_automatic_artifacts(data, z_artifact_samples, subject_id, 5);');
end
if ismember(6, plot_choice)
    disp('  plot_manual_artifacts(data, manual_artifact_samples, subject_id, 5);');
end
