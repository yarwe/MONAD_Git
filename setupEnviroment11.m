function [env] = setupEnviroment11()
%SETUPENVIROMENT11  Build the MONAD analysis environment struct.
%
%   env = setupEnviroment11()
%
%   Every setting that has to be configured by hand - toolbox locations, the
%   repository location, and which experiment/paradigm to analyse - is read
%   from config_local.m in the repository root. That file is git-ignored, so
%   each machine keeps its own copy; see config_template.m for the fields and
%   how to create one.
%
%   All data lives under a single git-ignored folder, <repo root>/Data. The
%   config file holds no data paths at all - they are all derived from it.
%   Every experiment uses the same layout:
%
%     Data/<exp>/                        experiment-level files, shared by all
%                                        paradigms (e.g. TK_customLay.mat)
%     Data/<exp>/<paradigm>/             LAVI/FFT arrays for this run
%     Data/<exp>/<paradigm>/<data_type>  raw, clean, art, ICApng, ica_comp,
%                                        prev_dat
%
%   Experiment names:
%     'OSF', 'TalKennet', 'NMSG', 'SFARI_EEG_multi'
%     'NMSG'  (Neural Markers of Shared Gaze...)
%     'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)

cfg = load_local_config();

% Possible experiments and, for each, its possible paradigms - mirroring the
% Data/<exp>/<paradigm>/ folder structure. An empty paradigm list means the
% paradigms for that experiment have not been filled in yet, so any folder
% name is accepted; fill the list in to have it checked.
experiments = {
    'OSF'             , {'simple','complex'}
    'TalKennet'       , {'tactile', 'aud', 'rest'}
    'NMSG'            , {}
    'IAASA'           , {}
    'SFARI_EEG_multi' , {'ASSR_run', 'FAST_run', 'Beepflash_run', 'AVSRT_run', 'Motor_run', 'IC_run', 'rest'}
    };
exp_names = experiments(:, 1)';

exp      = cfg.exp;
paradigm = cfg.paradigm;

% Check if the configured experiment name exists in the list
exp_idx = find(strcmp(exp, exp_names), 1);
if isempty(exp_idx)
    error('Experiment name ''%s'' does not exist. Set cfg.exp in config_local.m to one of: %s', ...
        exp, strjoin(exp_names, ', '));
end
paradigms = experiments{exp_idx, 2};

% Every experiment's data is split by paradigm, so a paradigm is always needed
if isempty(paradigm)
    error(['Paradigm is empty. Set cfg.paradigm in config_local.m - it names ' ...
           'the Data/%s/<paradigm>/ folder this run reads from.'], exp);
end

% Experiments whose paradigms are listed above are checked against that list
if ~isempty(paradigms) && ~ismember(paradigm, paradigms)
    error('Paradigm ''%s'' does not exist for %s. Set cfg.paradigm in config_local.m to one of: %s', ...
        paradigm, exp, strjoin(paradigms, ', '));
end

%% setup toolbox paths according to the machine config
git_path    = dirpath(cfg.git_path);
matlab_path = dirpath(cfg.matlab_path);
ft_path     = dirpath(cfg.ft_path);
eeglab_path = dirpath(cfg.eeglab_path);
maindir     = git_path;   % the repository root - everything is relative to it

extra_func_path = dirpath(git_path, 'additional_functions');
addpath(extra_func_path);
% Add path to zapline clean plus
addpath(dirpath(cfg.zapline_path));

% On machines that need BioSig reinstalled at start-up (cfg.biosig_path set)
biosig_path = optional_field(cfg, 'biosig_path', '');
if ~isempty(biosig_path)
    original_dir = pwd;
    cd(biosig_path);
    biosig_installer;
    cd(original_dir);
end

env.exp              = exp;
env.paradigm         = paradigm;
env.user             = cfg.user;
% Number of parfor workers. Empty means "let MATLAB choose its default".
env.n_workers        = optional_field(cfg, 'n_workers', []);
env.paths.git        = git_path;
env.paths.matlab     = matlab_path;
env.paths.extra_func = extra_func_path;
env.paths.eeglab     = eeglab_path;
env.paths.ft_path    = ft_path;
env.paths.maindir    = maindir;
env.paths.csv_log    = dirpath(maindir, 'csv_log');
% The LAVI toolbox is source code tracked in git, not data
env.paths.LAVI       = dirpath(git_path, 'analysis_MONAD', 'LAVI');

% Initialize eeglab
addpath(genpath(env.paths.eeglab));
%eeglab; close all;

% Initialize fieldtrip
addpath(ft_path);
ft_defaults();

%% data locations - every data file lives under maindir/Data
env.paths.data = dirpath(maindir, 'Data');
% Experiment-level folder, for files shared by all paradigms (custom layouts)
env.paths.exp  = dirpath(env.paths.data, exp);
% Working folder for this run. Holds the data_type subfolders below and the
% LAVI/FFT arrays written by create_datArr21.
work_dir = dirpath(env.paths.exp, paradigm);

env.paths.preproc  = work_dir;
env.paths.raw      = dirpath(work_dir, 'raw');
env.paths.clean    = dirpath(work_dir, 'clean');
env.paths.art      = dirpath(work_dir, 'art');
env.paths.ICApng   = dirpath(work_dir, 'ICApng');
env.paths.ica_comp = dirpath(work_dir, 'ica_comp');
env.paths.prev_dat = dirpath(work_dir, 'prev_dat');

%c = uisetcolor
env.plots.lineASD = [0.4000    0.6667    0.8000];
env.plots.lineNT  = [0.6118    0.8118    0.5843];
env.plots.lineSCZ =  [0.9000    0.6667    0.9];

% Per-experiment layout, electrodes and data properties. All folder paths are
% the same for every experiment now, so only the differences live below.
if strcmp('OSF', exp)
    cfg_lay = [];
    cfg_lay.layout = fullfile(ft_path, 'template', 'layout', 'biosemi64.lay');
    env.lay = ft_prepare_layout(cfg_lay);
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
    env.data.linenoise   = 60;
    env.data.fsample     = 512;
    env.nEEG= length(env.lay.label); % number of EEG channels

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical
    IDs = erase(env.data.clean_names(:), '_clean.mat');
    env.data.group_table = table(IDs, replace(extractBefore(IDs, 2), {'A', 'C'}, ...
        {'ASD', 'NT'}), 'VariableNames', {'ID', 'group'});

    env.elec          = ft_read_sens(fullfile(ft_path, 'template', 'electrode', 'standard_1020.elc'));

elseif strcmp('TalKennet', exp)
    % Custom layout, shared by all paradigms of this experiment
    env.lay  = load(fullfile(env.paths.exp, 'TK_customLay.mat'));
    env.lay  = env.lay.layout;
    % Fix Iz- written as IZ and later not recognized as EEG channel
    IZ_ind=find(strcmp(env.lay.label,'IZ'));
    if ~isempty(IZ_ind)
        env.lay.label(IZ_ind)={'Iz'};
    end

    env.elec = ft_read_sens(fullfile(ft_path, 'template', 'electrode', 'standard_1020.elc'));

    env.data.type        = 'fif';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.fif')).name};
    env.data.ID          = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    env.data.prefix      = '';
    env.data.linenoise   = 60;
    env.data.fsample     = 1000;
    env.nEEG= length(env.lay.cfg.elec.label); % number of EEG channels

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical
    IDs = erase(env.data.clean_names(:), '_clean.mat');
    env.data.group_table = table(IDs, replace(extractBefore(IDs, 2), {'A', 'C'}, ...
        {'ASD', 'NT'}), 'VariableNames', {'ID', 'group'});

elseif strcmp('SFARI_EEG_multi', exp)
    cfg_lay = [];
    cfg_lay.layout = fullfile(ft_path, 'template', 'layout', 'biosemi64.lay');
    env.lay = ft_prepare_layout(cfg_lay);
    env.lay.height = env.lay.height(1:64);
    env.lay.label  = env.lay.label(1:64);
    env.lay.pos    = env.lay.pos(1:64,:);
    env.lay.width  = env.lay.width(1:64);

    env.data.type        = 'bdf';
    env.data.names       = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID = cellfun(@(x) regexprep(x, '^sub-(.*?)_.*$', '$1'), env.data.names, 'UniformOutput', false);
    env.data.files       = fullfile(env.paths.raw, env.data.names);
    env.data.clean_names = {dir(fullfile(env.paths.clean, '*.mat')).name};
    env.data.clean_files = fullfile(env.paths.clean, env.data.clean_names);
    % change clean_names to participant IDs
    env.data.clean_names = cellfun(@(x) extractBefore(x, '_'), env.data.clean_names, 'UniformOutput', false);
    env.data.prefix      = '_task-ASSR_run-01_eeg.bdf';
    env.data.linenoise   = 60;
    env.data.fsample     = 512;

    % determine group ('ASD'/'NT'), ASD and Neuro-Typical
    IDs = erase(env.data.clean_names(:), '_clean.mat');
    env.data.group_table = table(IDs, replace(extractBefore(IDs, 2), {'A', 'C'}, ...
        {'ASD', 'NT'}), 'VariableNames', {'ID', 'group'});

elseif strcmp('NMSG', exp)
    env.lay  = load(fullfile(ft_path, 'template', 'layout', 'GSN-HydroCel-128.mat'));
    env.elec = ft_read_sens(fullfile(ft_path, 'template', 'electrode', 'standard_1020.elc'));

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
    cfg_lay = [];
    cfg_lay.layout = fullfile(ft_path, 'template', 'layout', 'biosemi64.lay');
    env.lay = ft_prepare_layout(cfg_lay);
    env.lay.height = env.lay.height(1:64);
    env.lay.label  = env.lay.label(1:64);
    env.lay.pos    = env.lay.pos(1:64,:);
    env.lay.width  = env.lay.width(1:64);
    env.elec = ft_read_sens(fullfile(ft_path, 'template', 'electrode', 'standard_1020.elc'));

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

% Check all paths: warn if missing for read-only paths, create if missing for output paths
error_paths = {'git', 'matlab', 'extra_func', 'eeglab', 'maindir', 'LAVI', 'ft_path', 'data', 'raw'};
path_fields = fieldnames(env.paths);
for i = 1:numel(path_fields)
    field = path_fields{i};
    p     = env.paths.(field);
    if ~exist(p, 'dir')
        if ismember(field, error_paths)
            warning('Required folder does not exist: %s = %s', field, p);
        else
            mkdir(p);
            fprintf('Created folder: %s\n', p);
        end
    end
end

end

% ------------------------------------------------------------------------
function cfg = load_local_config()
%LOAD_LOCAL_CONFIG  Read config_local.m from the repository root.

repo_root = fileparts(mfilename('fullpath'));
cfg_file  = fullfile(repo_root, 'config_local.m');

if ~exist(cfg_file, 'file')
    error(['config_local.m was not found in %s\n' ...
           'Every machine needs its own copy: copy config_template.m to ' ...
           'config_local.m, rename the function inside it to config_local, ' ...
           'and fill in the paths for this machine. config_local.m is ' ...
           'git-ignored on purpose, so it is never committed.'], repo_root);
end

% Make sure the repository root is reachable, so config_local can be called
% even when MATLAB is not currently in it
addpath(repo_root);
cfg = config_local();

required = {'user', 'git_path', 'matlab_path', 'ft_path', 'eeglab_path', ...
            'zapline_path', 'exp', 'paradigm'};
missing  = required(~isfield(cfg, required));
if ~isempty(missing)
    error(['config_local.m is missing required field(s): %s\n' ...
           'See config_template.m for the full list.'], strjoin(missing, ', '));
end

end

% ------------------------------------------------------------------------
function p = dirpath(varargin)
%DIRPATH  fullfile() for a folder, with a guaranteed trailing separator.
%   Downstream code concatenates these paths directly, e.g.
%   [env.paths.preproc 'LAVI_arr.mat'], so the trailing separator matters.

p = fullfile(varargin{:});
if ~isempty(p) && ~any(p(end) == '/\')
    p = [p filesep];
end

end

% ------------------------------------------------------------------------
function val = optional_field(cfg, name, default)
%OPTIONAL_FIELD  Value of cfg.(name), or default when absent or empty.

if isfield(cfg, name) && ~isempty(cfg.(name))
    val = cfg.(name);
else
    val = default;
end

end
