function [env] = setupEnvironment(exp)
% 'OSF_simple', 'TalKennet', 'NMSG' (Neural Markers of Shared Gaze...)
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)
% List of possible experiment names
experiments = {'OSF_simple', 'TalKennet', 'NMSG', 'IAASA'};
% Check if the provided experiment name exists in the list
if ~ismember(exp, experiments)
    error('Experiment name does not exist');  % Break and display error message
end

% setup paths according to user.
[user, dat_ay_letter] = user_func();

if strcmp(user, 'yoel')
    git_path    = 'C:\Users\yoelgo\Documents\GitHub\MONAD_Git\';
    matlab_path = 'C:\Program Files\MATLAB\';
    ft_path     = [matlab_path 'fieldtrip-20250114\fieldtrip-20250114\'];
    eeglab_path = [matlab_path 'eeglab_current\eeglab2025.0.0\'];
    maindir     = [dat_ay_letter ':\Yarden\'];
    
else
    git_path    = 'C:\Users\yarde\Documents\GitHub\MONAD_Git\'; % additinal_functions path in MONAD_Git
    matlab_path = 'C:\Users\yarde\Documents\MATLAB\';
    ft_path     = [matlab_path 'fieldtrip-20210614\'];
    eeglab_path = [matlab_path 'biosig4octmat-3.8.4\biosig\eeglab\'];
    maindir     = 'C:\Users\yarde\Documents\GitHub\MONAD_Git\'; % [dat_ay_letter ':\Yarden\'];
    % Yarden additions to her PC due to issues with biosig
    original_dir = pwd;
    cd('C:\Users\yarde\Documents\MATLAB\biosig4octmat-3.8.4');
    biosig_installer;
    cd(original_dir);
end

extra_func_path = [git_path 'additional_functions\'];
addpath(extra_func_path); % Yarden commented
addpath(ft_path);
ft_defaults();

preprocDir           = [maindir 'analysis_MONAD\MONAD_preproc'];
env.exp              = exp;
env.paths.extra_func = extra_func_path;
env.paths.eeglab     = eeglab_path;
env.dat_ay           = dat_ay_letter;
% Check if the folder for this exp exists, if not, create it and the subfolders
exp_folder = [preprocDir '\' exp '\'];
if ~exist(exp_folder, 'dir')
    % Create the main folder for the experiment
    mkdir(exp_folder);
    % Create subfolders
    env.paths.auto      = [exp_folder 'automated\'];
    env.paths.manual    = [exp_folder 'manual\'];
    env.paths.art       = [exp_folder 'artifacts\'];
    env.paths.clean     = [exp_folder 'clean\'];
    env.paths.ICApng    = [exp_folder 'ICApng\'];
    % Create the directories
    mkdir(env.paths.auto);
    mkdir(env.paths.manual);
    mkdir(env.paths.art);
    mkdir(env.paths.clean);
    mkdir(env.paths.ICApng);
end
env.paths.maindir = maindir;
%c = uisetcolor
env.plots.lineASD = [0.4000    0.6667    0.8000];
env.plots.lineNT  = [0.6118    0.8118    0.5843];
env.plots.lineSCZ =  [0.9000    0.6667    0.9];

% Existing code for handling specific experiments
if strcmp('OSF_simple', exp)
    env.paths.raw       = [maindir 'OSF data\Simple\'];
    env.paths.preproc   = exp_folder;  % Use the dynamically created folder
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.art       = [env.paths.preproc 'new_art\'];
    env.paths.clean     = [env.paths.preproc 'new_clean\'];
    env.paths.ICApng    = [env.paths.preproc 'new_ICApng\'];
    env.paths.LAVI      = [maindir 'analysis_MONAD\LAVI\'];
    env.paths.ft_path = ft_path;

    
    
    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);
    env.lay.height = env.lay.height(1:64);
    env.lay.label  = env.lay.label(1:64);
    env.lay.pos    = env.lay.pos(1:64,:);
    env.lay.width  = env.lay.width(1:64);

    env.data.type        = 'bdf';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.bdf')).name};    
    env.data.ID          = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    % change clean_names to participant IDs
    env.data.clean_names = cellfun(@(x) extractBefore(x, '_'), env.data.clean_names, 'UniformOutput', false);
    env.data.prefix      = '_Simpletone.bdf';
    env.data.linenoise   = 50;
    env.data.fsample     = 512;

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical
    IDs = erase(env.data.clean_names(:), '_clean.mat');
    env.data.group_table = table(IDs, replace(extractBefore(IDs, 2), {'A', 'C'}, ...
        {'ASD', 'NT'}), 'VariableNames', {'ID', 'group'});

    
    env.elec          = ft_read_sens([env.paths.ft_path '\template\electrode\standard_1020.elc']);
    
elseif strcmp('TalKennet', exp)
    env.paths.exp       = [maindir 'NIMH data\'];
    env.paths.raw       = [maindir 'NIMH data\Package_1235544-Tal Kenet MEG EEG biomarkers\eeg_sub_files01\'];
    env.paths.preproc   = exp_folder;  % Use the dynamically created folder
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.art       = [env.paths.preproc 'artifacts\'];
    env.paths.clean     = [env.paths.preproc 'clean\'];
    env.paths.ICApng    = [env.paths.preproc 'ICApng\'];
    env.paths.LAVI      = [maindir 'analysis_MONAD\LAVI\'];
    env.paths.ft_path = ft_path;
    
    env.lay  = load([maindir 'NIMH data\Package_1235544-Tal Kenet MEG EEG biomarkers\TK_customLay.mat']);
    env.lay  = env.lay.layout;
    env.elec = ft_read_sens([env.paths.ft_path '\template\electrode\standard_1020.elc']);

    env.data.type        = 'fif';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.fif')).name};    
    env.data.ID          = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    env.data.prefix      = '';
    env.data.linenoise   = 50;
    env.data.fsample     = 1000;

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical
    IDs = erase(env.data.clean_names(:), '_clean.mat');
    env.data.group_table = table(IDs, replace(extractBefore(IDs, 2), {'A', 'C'}, ...
        {'ASD', 'NT'}), 'VariableNames', {'ID', 'group'});

elseif strcmp('NMSG', exp)
    env.paths.exp       = [maindir 'NIMH data\'];
    env.paths.raw       = [maindir 'NIMH data\NMSG\eeg_sub_files01'];
    env.paths.preproc   = exp_folder;  % Use the dynamically created folder
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.art       = [env.paths.preproc 'artifacts\'];
    env.paths.clean     = [env.paths.preproc 'clean\'];
    env.paths.ICApng    = [env.paths.preproc 'ICApng\'];
    env.paths.LAVI      = [maindir 'analysis_MONAD\LAVI\'];
    env.paths.ft_path = ft_path;
    
    env.lay  = load([env.paths.ft_path 'template\layout\GSN-HydroCel-128.mat']);
    env.elec = ft_read_sens([env.paths.ft_path '\template\electrode\standard_1020.elc']);

    env.data.type        = 'mat';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.mat')).name};
    env.data.ID          = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    env.data.prefix      = '';
    env.data.linenoise   = 50;
    env.data.fsample     = 512;

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical


elseif strcmp('IAASA', exp)
    env.paths.exp       = [maindir 'NIMH data\'];
    env.paths.raw       = [maindir 'NIMH data\Package_1235552_Influence_of_Attention_and_Aroudal_on_Sensory_Abnormailities_in_ASD\eeg_sub_files01'];
    env.paths.preproc   = exp_folder;  % Use the dynamically created folder
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.art       = [env.paths.preproc 'artifacts\'];
    env.paths.clean     = [env.paths.preproc 'clean\'];
    env.paths.ICApng    = [env.paths.preproc 'ICApng\'];
    env.paths.LAVI      = [maindir 'analysis_MONAD\LAVI\'];
    env.paths.ft_path = ft_path;
    
        
    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);
    env.lay.height = env.lay.height(1:64);
    env.lay.label  = env.lay.label(1:64);
    env.lay.pos    = env.lay.pos(1:64,:);
    env.lay.width  = env.lay.width(1:64);
    env.elec = ft_read_sens([env.paths.ft_path '\template\electrode\standard_1020.elc']);

    env.data.type        = 'bdf';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID          = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    env.data.prefix      = '';
    env.data.linenoise   = 50;
    env.data.fsample     = 1024;

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical




end
