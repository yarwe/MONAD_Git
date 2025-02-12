function [env] = setupEnvironment(exp)

addpath('C:\Users\yoelgo\Desktop\MONAD_Git\additional_functions\');
ft_path       = 'C:\Users\yoelgo\Documents\fieldtrip-20250114\';
addpath(ft_path);
ft_defaults;

maindir              = 'R:\Yarden\';
preprocDir           = [maindir 'MONAD_preproc\'];

env.exp = exp;
if strcmp('OSF_simple', exp)
% OSF Simple
    env.paths.raw       = [maindir 'OSF data\Simple\'];
    env.paths.preproc   = [preprocDir 'Analysis_Monad\OSF_simple\'];
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.ICA       = [env.paths.preproc 'ICA\'];

    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);

    env.data.type       = 'bdf';
    env.data.names      = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID         = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files      = fullfile(env.paths.raw, env.data.names);
    env.data.prefix     = '_Simpletone.bdf';

elseif strcmp('OSF_complex', exp)
    env.paths.raw       = [maindir 'OSF data\Complex\'];
    env.paths.preproc   = [preprocDir 'Analysis_Monad\MONAD_preproc\OSF_complex\'];
    env.paths.auto      = [env.paths.preproc 'automated\'];
    env.paths.manual    = [env.paths.preproc 'manual\'];
    env.paths.ICA       = [env.paths.preproc 'ICA\'];
    env.paths.clean     = [env.paths.preproc 'clean\']

    cfg = [];
    cfg.layout = fullfile([ft_path '\template\layout\biosemi64.lay']);
    env.lay = ft_prepare_layout(cfg);

    env.data.type       = 'bdf';
    env.data.names      = {dir(fullfile(env.paths.raw, '*.bdf')).name};
    env.data.ID         = cellfun(@(x) regexprep(x, '_.*', ''), env.data.names, 'UniformOutput', false);
    env.data.files      = fullfile(env.paths.raw, env.data.names);
    env.data.prefix     = '_ComplexSound.bdf';

end

    



%paths.elec          = [paths.maindir 'fieldtrip-20230522\template\electrode\standard_1020.elc'];
%elec = ft_read_sens(paths.elec);

end
