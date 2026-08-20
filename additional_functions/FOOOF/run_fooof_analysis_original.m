%% run_fooof_analysis_original.m
% Same NT-vs-ASD FOOOF comparison as run_fooof_analysis.m, but fit with the
% ORIGINAL Python FOOOF (fooof_mat wrapper) using the LIBRARY DEFAULT settings.
%
% Purpose: check that the results are not an artifact of (a) the native MATLAB
% re-implementation, or (b) the resting-EEG-tuned settings used in the main
% script. Here everything is the original code with its own defaults.
%
% Requires:
%   * Python with `fooof` installed, MATLAB pointed at it (handled below)
%   * ./fooof_mat on the path (the official wrapper)
%   * fooof_psd_cache.mat  (built by running run_fooof_analysis.m once)
%
% LIBRARY DEFAULTS used here (vs the main script's resting-EEG settings):
%     peak_width_limits : [0.5 12]   (main script: [1 6])
%     max_n_peaks       : Inf        (main script: 6)
%     min_peak_height   : 0.0        (main script: 0.05)
%     peak_threshold    : 2.0        (main script: 1.5)   <-- the paper's algorithm default
%     aperiodic_mode    : 'fixed'
% (Passing an empty settings struct to fooof() would fill in exactly these.)

clear; clc; close all;

%% -------------------- 0. Point MATLAB at Python --------------------
PYEXE = 'C:\Users\yarde\AppData\Local\Programs\Python\Python38\python.exe';
try
    pe = pyenv;
    if pe.Status ~= "Loaded" || ~strcmp(char(pe.Executable), PYEXE)
        pe = pyenv('Version', PYEXE, 'ExecutionMode', 'OutOfProcess');
    end
catch ME
    warning(ME.identifier,'%s',ME.message); pe = pyenv;
end
try
    fmod = py.importlib.import_module('fooof');
    fprintf('Using Python fooof %s\n', char(py.getattr(fmod,'__version__')));
catch
    error(['Cannot import Python ''fooof''. Install it:\n   "%s" -m pip install fooof'], PYEXE);
end
addpath(fullfile(pwd,'fooof_mat'));

%% -------------------- 1. Original (library-default) settings --------------------
cfg = [];
cfg.freq_range        = [2 40];     % same fit range as the main analysis
cfg.aperiodic_mode    = 'fixed';
cfg.peak_width_limits = [0.5 12];   % library default
cfg.max_n_peaks       = Inf;        % library default
cfg.min_peak_height   = 0.0;        % library default
cfg.peak_threshold    = 2.0;        % library / paper algorithm default
cfg.alpha_band        = [7 14];

% Outlier-exclusion rule (see fooof_exclude.m). Default = the paper's rule.
cfg.exclusion         = 'sd';       % 'sd' (2.5-SD-from-mean, paper) | 'r2' | 'none'
cfg.exclusion_nsd     = 2.5;        % SD multiplier for 'sd' mode
cfg.exclusion_logic   = 'or';       % flag if R^2 OR error is an outlier ('and' = both)
cfg.r2_thresh         = 0.90;       % used only if exclusion = 'r2'

%% -------------------- 2. Load cached PSDs --------------------
CACHE = fullfile(pwd,'fooof_psd_cache.mat');
if ~isfile(CACHE)
    error(['%s not found. Run run_fooof_analysis.m once first to build the ' ...
           'PSD cache from the raw files.'], CACHE);
end
load(CACHE,'S1','S2','S1_cz','S2_cz','f','lab1','lab2');
name1 = 'NT'; name2 = 'ASD';
COL_CTRL = [0.15 0.60 0.20];        % green (controls / NT)
COL_ASD  = [0.00 0.45 0.74];        % blue  (ASD)

%% -------------------- 3. Fit both groups (posterior ROI) --------------------
cfg1 = cfg; cfg1.labels = lab1; cfg1.group_name = name1; cfg1.color = COL_CTRL;
cfg2 = cfg; cfg2.labels = lab2; cfg2.group_name = name2; cfg2.color = COL_ASD;

G1 = fooof_group_original(f, S1, cfg1);
G2 = fooof_group_original(f, S2, cfg2);
disp(G1.table); disp(G2.table);

%% -------------------- 4. Plots (all subjects) --------------------
plot_fooof_group_fits(G1, G2);
stats = plot_fooof_group_comparison(G1, G2); %#ok<NASGU>
set(gcf,'Name','ORIGINAL fooof, library defaults - all subjects');

%% -------------------- 5. Comparison WITHOUT outliers --------------------
[keep1, ex1] = fooof_exclude(G1, cfg);
[keep2, ex2] = fooof_exclude(G2, cfg);
fprintf('\n--- Outlier exclusion (mode: %s) ---\n', cfg.exclusion);
if strcmpi(cfg.exclusion,'sd')
    fprintf('%s: R^2 cut < %.3f, error cut > %.4f  -> excluded: %s\n', name1, ...
        ex1.r2_cut, ex1.err_cut, join_or_none(ex1.excluded_labels));
    fprintf('%s: R^2 cut < %.3f, error cut > %.4f  -> excluded: %s\n', name2, ...
        ex2.r2_cut, ex2.err_cut, join_or_none(ex2.excluded_labels));
else
    fprintf('%s excluded: %s\n', name1, join_or_none(ex1.excluded_labels));
    fprintf('%s excluded: %s\n', name2, join_or_none(ex2.excluded_labels));
end
G1c = fooof_subset_group(G1, keep1);
G2c = fooof_subset_group(G2, keep2);
stats_clean = plot_fooof_group_comparison(G1c, G2c); %#ok<NASGU>
set(gcf,'Name','ORIGINAL fooof - outliers excluded');

%% -------------------- 6. Aperiodic from Cz --------------------
cfg1cz = cfg1; cfg1cz.group_name = [name1 ' (Cz)'];
cfg2cz = cfg2; cfg2cz.group_name = [name2 ' (Cz)'];
G1cz = fooof_group_original(f, S1_cz, cfg1cz);
G2cz = fooof_group_original(f, S2_cz, cfg2cz);
kz1 = fooof_exclude(G1cz, cfg);
kz2 = fooof_exclude(G2cz, cfg);
G1czc = fooof_subset_group(G1cz, kz1);
G2czc = fooof_subset_group(G2cz, kz2);
stats_cz = plot_fooof_group_comparison(G1czc, G2czc); %#ok<NASGU>
set(gcf,'Name','ORIGINAL fooof - Cz aperiodic');

fprintf('\nDone (original FOOOF, library defaults). Compare against run_fooof_analysis.m.\n');

function s = join_or_none(c)
if isempty(c), s = '(none)'; else, s = strjoin(c, ', '); end
end
