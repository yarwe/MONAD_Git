function [env] = setupEnvironment(exp)

% List of possible experiment names
experiments = {'OSF_simple', 'OSF_complex', 'NIMH'};
% Check if the provided experiment name exists in the list
if ~ismember(exp, experiments)
    error('Experiment name does not exist');  % Break and display error message
end

addpath('C:\Users\yoelgo\Desktop\MONAD_Git\additional_functions\');
ft_path       = 'C:\Users\yoelgo\Documents\fieldtrip-20250114\';
addpath(ft_path);
ft_defaults;
maindir              = 'R:\Yarden\';
preprocDir           = [maindir 'analysis_MONAD\MONAD_preproc'];
env.exp = exp;

% Check if the folder for exp exists, if not, create it and the subfolders
exp_folder = [maindir 'analysis_MONAD\MONAD_preproc\' exp '\'];
if ~exist(exp_folder, 'dir')
    % Create the main folder for the experiment
    mkdir(exp_folder);
    % Create subfolders
    env.paths.auto      = [exp_folder 'automated\'];
    env.paths.manual    = [exp_folder 'manual\'];
    env.paths.art       = [exp_folder 'artifacts\'];
    env.paths.clean     = [exp_folder 'clean\'];
    % Create the directories
    mkdir(env.paths.auto);
    mkdir(env.paths.manual);
    mkdir(env.paths.art);
    mkdir(env.paths.clean);
end

% Existing code for handling specific experiments
if strcmp('OSF_simple', exp)
    env.paths.raw       = [maindir 'OSF data\Simple\'];
    env.paths.preproc   = exp_folder;  % Use the dynamically created folder
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.art       = [env.paths.preproc 'artifacts\'];
    env.paths.clean     = [env.paths.preproc 'clean\'];

    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);

    env.data.type       = 'bdf';
    env.data.names      = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID         = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files      = fullfile(env.paths.raw, env.data.names);
    env.data.prefix     = '_Simpletone.bdf';
    env.data.linenoise  = 50;
    
    env.elec.ref        = [129 130];

elseif strcmp('OSF_complex', exp)
    env.paths.raw       = [maindir 'OSF data\Complex\'];
    env.paths.preproc   = [preprocDir 'Analysis_Monad\MONAD_preproc\OSF_complex\'];
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.ICA       = [env.paths.preproc 'ICA\'];
    env.paths.clean     = [env.paths.preproc 'clean\'];

    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);

    env.data.type       = 'bdf';
    env.data.names      = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID         = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files      = fullfile(env.paths.raw, env.data.names);
    env.data.prefix     = '_ComplexSound.bdf';

end

end
