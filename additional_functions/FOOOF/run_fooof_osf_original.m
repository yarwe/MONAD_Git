%% run_fooof_osf_original.m
% FOOOF on the OSF (simple) resting-state data, using the ORIGINAL Python
% engine (fooof_mat wrapper) with the library-DEFAULT settings. Compares
% Controls (NT) vs ASD for two ROIs -- central and occipital -- showing the
% results for ALL subjects and after BAD-FIT exclusion only.
%
% ---------------------------------------------------------------------------
% HOW TO RUN THIS YOURSELF
%   1. Python `fooof` must be installed and MATLAB must be pointed at it.
%      Edit PYEXE below to your Python. (One-off: "<python> -m pip install fooof".)
%   2. The official wrapper folder `fooof_mat` must sit next to this script.
%   3. Just run the script. The FIRST run reloads every *_fooof.mat and caches
%      the ROI power spectra to fooof_osf_cache.mat; later runs load the cache
%      and are instant. Delete that .mat to force a re-read (e.g. new ROI).
%   4. To change ROIs, engine settings, or the exclusion rule, edit Section 1.
% ---------------------------------------------------------------------------

clear; clc; close all;

%% -------------------- 0. Point MATLAB at Python --------------------
PYEXE = 'C:\Users\yarde\AppData\Local\Programs\Python\Python38\python.exe';
try
    pe = pyenv;
    if pe.Status ~= "Loaded" || ~strcmp(char(pe.Executable), PYEXE)
        pe = pyenv('Version', PYEXE, 'ExecutionMode', 'OutOfProcess');
    end
catch ME, warning(ME.identifier,'%s',ME.message); end
try
    py.importlib.import_module('fooof');
catch
    error(['Cannot import Python ''fooof''. Install it:\n   "%s" -m pip install fooof'], PYEXE);
end
here = fileparts(mfilename('fullpath')); addpath(fullfile(here,'fooof_mat'));

%% -------------------- 1. Settings --------------------
folderNT  = 'C:\Users\yarde\Documents\MONAD_Git\Data\OSF\simple\FOOOF\NT';   % Controls (C*)
folderASD = 'C:\Users\yarde\Documents\MONAD_Git\Data\OSF\simple\FOOOF\ASD';  % ASD (A*)
nameNT = 'NT'; nameASD = 'ASD';

% ROIs to analyze (name -> channel list)
rois = struct( ...
    'central',   {{'Cz','C1','C2','FCz','FC1','FC2'}}, ...
    'occipital', {{'Oz','POz','Pz','O1','O2'}} );

win_sec = 2; overlap = 0.5;               % Welch (paper settings)

% ORIGINAL engine, LIBRARY-DEFAULT fit settings
cfg = [];
cfg.freq_range        = [2 40];
cfg.aperiodic_mode    = 'fixed';
cfg.peak_width_limits = [0.5 12];         % library default
cfg.max_n_peaks       = Inf;              % library default
cfg.min_peak_height   = 0.0;              % library default
cfg.peak_threshold    = 2.0;              % library default
cfg.alpha_band        = [7 14];

% Exclusion: BAD FIT ONLY (fit-quality; no alpha/other criteria).
cfg.exclusion       = 'sd';               % paper's 2.5-SD-from-mean rule on R^2/error
cfg.exclusion_nsd   = 2.5;
cfg.exclusion_logic = 'or';

COL_NT = [0.15 0.60 0.20]; COL_ASD = [0.00 0.45 0.74];   % green / blue

%% -------------------- 2. Build (or load) ROI power spectra --------------------
roiNames = fieldnames(rois);
CACHE = fullfile(here, 'fooof_osf_cache.mat');
if isfile(CACHE)
    fprintf('Loading OSF PSDs from cache (delete %s to rebuild).\n', CACHE);
    load(CACHE, 'PSD_NT','PSD_ASD','f','labNT','labASD');
else
    roiList = struct2cell(rois);          % 1 x nRoi cell of channel-cellstrs
    [PSD_NT,  f,  labNT ] = osf_build(folderNT,  roiList, win_sec, overlap);
    [PSD_ASD, f2, labASD] = osf_build(folderASD, roiList, win_sec, overlap);
    assert(isequal(f,f2), 'NT and ASD produced different frequency axes.');
    save(CACHE, 'PSD_NT','PSD_ASD','f','labNT','labASD');
    fprintf('Cached OSF PSDs to %s\n', CACHE);
end

%% -------------------- 3. Fit + compare, per ROI --------------------
for r = 1:numel(roiNames)
    rn = roiNames{r};
    fprintf('\n########## ROI: %s (%s) ##########\n', rn, strjoin(rois.(rn), ','));

    cfgN = cfg; cfgN.labels=labNT;  cfgN.group_name=[nameNT  ' ' rn]; cfgN.color=COL_NT;
    cfgA = cfg; cfgA.labels=labASD; cfgA.group_name=[nameASD ' ' rn]; cfgA.color=COL_ASD;
    GN = fooof_group_original(f, PSD_NT{r},  cfgN);
    GA = fooof_group_original(f, PSD_ASD{r}, cfgA);

    % ALL subjects
    fprintf('--- %s: ALL subjects (NT=%d, ASD=%d) ---\n', rn, numel(GN.offset), numel(GA.offset));
    plot_fooof_group_comparison(GN, GA);
    set(gcf,'Name',sprintf('OSF %s - all subjects', rn));

    % BAD-FIT exclusion only
    [kN, exN] = fooof_exclude(GN, cfg);
    [kA, exA] = fooof_exclude(GA, cfg);
    fprintf('--- %s: bad-fit excluded (%s) ---\n', rn, cfg.exclusion);
    fprintf('   NT excluded : %s\n', join_or_none(exN.excluded_labels));
    fprintf('   ASD excluded: %s\n', join_or_none(exA.excluded_labels));
    plot_fooof_group_comparison(fooof_subset_group(GN,kN), fooof_subset_group(GA,kA));
    set(gcf,'Name',sprintf('OSF %s - bad-fit excluded', rn));
end
fprintf('\nDone. One "all" and one "excluded" comparison figure per ROI.\n');

%% ======================= local helpers =======================
function [specsC, f, labels] = osf_build(folder, rois, win_sec, overlap)
% ROI-averaged PSD per subject for each ROI, one file load per subject.
L = dir(fullfile(folder,'*.mat')); files = fullfile(folder,{L.name});
if isempty(files), error('No .mat files in %s', folder); end
nRoi = numel(rois); specsC = repmat({[]},1,nRoi); f=[]; labels={};
for k = 1:numel(files)
    d = osf_load(files{k}); if isempty(d), continue; end
    fs = d.fsample; roiPow = cell(1,nRoi); ok = true;
    for r = 1:nRoi
        ch = find(ismember(d.label, rois{r}));
        if isempty(ch), warning('ROI channels missing in %s; skipping.', files{k}); ok=false; break; end
        P = []; ci = 0;
        for c = ch(:)'
            [pxx,ff] = psd_nan(d.trial{1}(c,:), fs, win_sec, overlap);
            if isempty(f), f=ff; end
            if isempty(P), P=zeros(numel(pxx),numel(ch)); end
            ci=ci+1; P(:,ci)=pxx;
        end
        roiPow{r} = mean(P,2,'omitnan');
    end
    if ~ok, continue; end
    for r=1:nRoi, specsC{r}(:,end+1)=roiPow{r}; end %#ok<AGROW>
    [~,nm]=fileparts(files{k}); labels{end+1}=regexprep(nm,'_(fooof|clean)$',''); %#ok<AGROW>
end
end

function d = osf_load(file)
d=[]; S=load(file); fn=fieldnames(S);
for i=1:numel(fn)
    v=S.(fn{i}); if iscell(v)&&~isempty(v), v=v{1}; end
    if isstruct(v)&&isfield(v,'label')&&isfield(v,'trial')
        if ~isfield(v,'fsample')||isempty(v.fsample), v.fsample=round(1/median(diff(v.time{1}))); end
        d=v; return;
    end
end
end

function s = join_or_none(c)
if isempty(c), s='(none)'; else, s=strjoin(c,', '); end
end
