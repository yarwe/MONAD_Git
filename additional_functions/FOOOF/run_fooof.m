%% run_fooof.m  —  Unified FOOOF group analysis (any dataset, any ROI, either engine)
%
% One script for all datasets. Configure the CONFIG block below and run.
% It compares Controls/NT (green) vs ASD (blue) for each ROI you list, showing
% ALL subjects and after bad-fit exclusion, using either the original Python
% FOOOF or the native MATLAB fooof_fit.
%
% ---------------------------------------------------------------------------
% HOW TO RUN
%   Edit the CONFIG block, then run this script. That's it.
%   * CFG.dataset : 'OSF' | 'TalKennet' | 'combined'   (combined = pool both)
%   * CFG.engine  : 'original' (peer-reviewed Python FOOOF) | 'native' (fooof_fit.m)
%   * CFG.settings: 'library' (FOOOF defaults) | 'resting' (paper resting-EEG)
%   * CFG.rois    : struct of ROI name -> channel list (add/remove freely)
%   First run per dataset reloads the raw *_fooof.mat and caches the ROI power
%   spectra (fooof_cache_<dataset>.mat); later runs are instant. Delete that
%   cache to force a rebuild (e.g. after changing ROIs or the Welch window).
%
% Requires (only when CFG.engine='original'): Python `fooof` installed, MATLAB
% pointed at it (CFG.python), and the fooof_mat/ folder next to this script.
% ---------------------------------------------------------------------------

clear; clc; close all;

%% ===================== CONFIG (edit this) =====================
CFG.dataset  = 'OSF';         % 'OSF' | 'TalKennet' | 'combined'
CFG.engine   = 'native';    % 'original' | 'native'
CFG.settings = 'resting';     % 'library' | 'resting'
CFG.exclusion= 'none';          % bad-fit exclusion: 'sd' (paper 2.5-SD) | 'r2' | 'none'
CFG.show_fits= false;         % also draw the individual+mean fit overlay per ROI

% --- Optional fit-parameter overrides (leave [] to use the CFG.settings preset).
%     Presets:  'library' -> width [0.5 12], max Inf, min_height 0,    threshold 2.0
%               'resting' -> width [1 6],    max 6,   min_height 0.05, threshold 1.5
%     Set any of these to force just that one parameter (e.g. threshold = 1.5),
%     keeping the rest of the chosen preset. Useful for replicating an old run.
CFG.peak_threshold    = [];   % e.g. 1.5  (peak-detection floor, in SD of flat spectrum)
CFG.peak_width_limits = [];   % e.g. [1 6]
CFG.max_n_peaks       = [];   % e.g. 6
CFG.min_peak_height   = [];   % e.g. 0.05

CFG.rois = struct( ...
    'central',   {{'Cz','C1','C2','FCz','FC1','FC2'}}, ...
    'occipital', {{'Oz','POz','Pz','O1','O2'}} );

CFG.freq_range = [2 40];      % FOOOF fit range (Hz)
CFG.alpha_band = [7 14];      % window to pick the alpha peak
CFG.win_sec = 2; CFG.overlap = 0.5;              % Welch window / overlap
CFG.python  = 'C:\Users\yarde\AppData\Local\Programs\Python\Python38\python.exe';

% Dataset registry: each dataset has an NT (control) and ASD folder.
ROOT = 'C:\Users\yarde\Documents\MONAD_Git\Data';
add_func_path='C:\Users\yarde\Documents\MONAD_Git\additional_functions\';
addpath(add_func_path)
addpath([add_func_path 'FOOOF'])
DATA.OSF.tag='OSF';  DATA.OSF.NT=[ROOT '\OSF\simple\FOOOF\NT'];        DATA.OSF.ASD=[ROOT '\OSF\simple\FOOOF\ASD'];
DATA.TalKennet.tag='TK'; DATA.TalKennet.NT=[ROOT '\TalKennet\tactile\FOOOF\NT']; DATA.TalKennet.ASD=[ROOT '\TalKennet\tactile\FOOOF\ASD'];
%% =============================================================

here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end

% Resolve which dataset folders make up each group.
switch lower(CFG.dataset)
    case 'osf',       sets = {DATA.OSF};
    case 'talkennet', sets = {DATA.TalKennet};
    case 'combined',  sets = {DATA.OSF, DATA.TalKennet};
    otherwise, error('CFG.dataset must be OSF, TalKennet, or combined.');
end
NTfolders  = cellfun(@(s) s.NT,  sets, 'UniformOutput', false);
ASDfolders = cellfun(@(s) s.ASD, sets, 'UniformOutput', false);
tags       = cellfun(@(s) s.tag, sets, 'UniformOutput', false);

% Common frequency grid, so datasets with different sampling rates can be
% pooled (Welch resolution = 1/win_sec is identical across fs; only Nyquist
% differs, so cropping/interpolating to a shared grid aligns them exactly).
df = 1/CFG.win_sec; f = (0:df:45)';

roiNames = fieldnames(CFG.rois);
roiList  = cellfun(@(n) CFG.rois.(n), roiNames, 'UniformOutput', false);

%% ---- engine setup ----
if strcmpi(CFG.engine,'original')
    try
        pe = pyenv;
        if pe.Status ~= "Loaded" || ~strcmp(char(pe.Executable), CFG.python)
            pe = pyenv('Version', CFG.python, 'ExecutionMode', 'OutOfProcess');
        end
    catch ME, warning(ME.identifier,'%s',ME.message); end
    try, py.importlib.import_module('fooof');
    catch, error('Cannot import Python fooof. Run:  "%s" -m pip install fooof', CFG.python); end
    addpath(fullfile(here,'fooof_mat'));
    Gfit = @fooof_group_original;
else
    Gfit = @fooof_group;
end

%% ---- build (or load) ROI power spectra ----
CACHE = fullfile(here, sprintf('fooof_cache_%s.mat', CFG.dataset));
if isfile(CACHE)
    S = load(CACHE);
    if isequal(S.roiNames, roiNames) && isequal(S.f, f)
        PSD_NT=S.PSD_NT; PSD_ASD=S.PSD_ASD; labNT=S.labNT; labASD=S.labASD;
        fprintf('Loaded %s PSDs from cache.\n', CFG.dataset);
    else
        fprintf('Cache ROI/grid mismatch -> rebuilding.\n'); clear S; rebuild=true;
    end
end
if ~exist('PSD_NT','var')
    [PSD_NT,  labNT ] = build_group(NTfolders,  tags, roiList, f, CFG.win_sec, CFG.overlap);
    [PSD_ASD, labASD] = build_group(ASDfolders, tags, roiList, f, CFG.win_sec, CFG.overlap);
    save(CACHE, 'PSD_NT','PSD_ASD','labNT','labASD','f','roiNames');
    fprintf('Cached %s PSDs to %s\n', CFG.dataset, CACHE);
end

%% ---- engine fit settings ----
switch lower(CFG.settings)
    case 'library', pw=[0.5 12]; mx=Inf; mph=0.0;  pt=2.0;   % FOOOF library defaults
    case 'resting', pw=[1 6];    mx=6;   mph=0.05; pt=1.5;   % paper resting-EEG
    otherwise, error('CFG.settings must be library or resting.');
end
% Apply any explicit overrides (a set CFG.* field wins over the preset).
if ~isempty(CFG.peak_threshold),    pt  = CFG.peak_threshold;    end
if ~isempty(CFG.peak_width_limits), pw  = CFG.peak_width_limits; end
if ~isempty(CFG.max_n_peaks),       mx  = CFG.max_n_peaks;       end
if ~isempty(CFG.min_peak_height),   mph = CFG.min_peak_height;   end
fprintf(['Engine: %s | fit: width=%s, max_n_peaks=%g, min_peak_height=%g, ' ...
         'peak_threshold=%g\n'], CFG.engine, mat2str(pw), mx, mph, pt);

base = struct('freq_range',CFG.freq_range,'aperiodic_mode','fixed', ...
    'peak_width_limits',pw,'max_n_peaks',mx,'min_peak_height',mph,'peak_threshold',pt, ...
    'alpha_band',CFG.alpha_band,'exclusion',CFG.exclusion,'exclusion_nsd',2.5,'exclusion_logic','or');
COL_NT=[0.15 0.60 0.20]; COL_ASD=[0.00 0.45 0.74];

%% ---- fit + compare, per ROI ----
fprintf('\n=== Dataset: %s | engine: %s | settings: %s ===\n', CFG.dataset, CFG.engine, CFG.settings);
for r = 1:numel(roiNames)
    rn = roiNames{r};
    fprintf('\n########## ROI: %s (%s) ##########\n', rn, strjoin(CFG.rois.(rn),','));

    cN=base; cN.labels=labNT;  cN.group_name=['NT '  rn]; cN.color=COL_NT;
    cA=base; cA.labels=labASD; cA.group_name=['ASD ' rn]; cA.color=COL_ASD;
    GN = Gfit(f, PSD_NT{r},  cN);
    GA = Gfit(f, PSD_ASD{r}, cA);

    fprintf('--- %s: ALL subjects (NT=%d, ASD=%d) ---\n', rn, numel(GN.offset), numel(GA.offset));
    plot_fooof_group_comparison(GN, GA);
    set(gcf,'Name',sprintf('%s | %s | ALL', CFG.dataset, rn));

    [kN,exN]=fooof_exclude(GN,base); [kA,exA]=fooof_exclude(GA,base);
    fprintf('--- %s: bad-fit excluded (%s) | NT out: %s | ASD out: %s ---\n', rn, CFG.exclusion, ...
        none_if_empty(exN.excluded_labels), none_if_empty(exA.excluded_labels));
    plot_fooof_group_comparison(fooof_subset_group(GN,kN), fooof_subset_group(GA,kA));
    set(gcf,'Name',sprintf('%s | %s | excluded', CFG.dataset, rn));

    if CFG.show_fits   % optional: individual + group-mean fit overlay
        plot_fooof_group_fits(GN, GA);
        set(gcf,'Name',sprintf('%s | %s | fits', CFG.dataset, rn));
    end
end
fprintf('\nDone. One "all" and one "excluded" figure per ROI.\n');

%% ======================= local helpers =======================
function [specsC, labels] = build_group(folders, tags, rois, f, win_sec, overlap)
% Pool subjects from one or more folders; return ROI-averaged PSDs (interpolated
% onto the shared grid f) as a 1 x nRoi cell of [nFreq x nSubj].
nRoi=numel(rois); specsC=repmat({[]},1,nRoi); labels={};
for j=1:numel(folders)
    L=dir(fullfile(folders{j},'*.mat')); files=fullfile(folders{j},{L.name});
    if isempty(files), warning('No .mat files in %s', folders{j}); continue; end
    pre=''; if numel(folders)>1 && ~isempty(tags{j}), pre=[tags{j} ':']; end
    for k=1:numel(files)
        d=load_ft(files{k}); if isempty(d), continue; end
        fs=d.fsample; roiPow=cell(1,nRoi); ok=true;
        for r=1:nRoi
            ch=find(ismember(d.label, rois{r}));
            if isempty(ch), warning('ROI %s channels missing in %s; skipping.', mat2str(r), files{k}); ok=false; break; end
            P=[]; ci=0; ff=[];
            for c=ch(:)'
                [pxx0,ff]=psd_nan(d.trial{1}(c,:), fs, win_sec, overlap);
                if isempty(P), P=zeros(numel(pxx0),numel(ch)); end
                ci=ci+1; P(:,ci)=pxx0;
            end
            roiAvg=mean(P,2,'omitnan');
            roiPow{r}=interp1(ff, roiAvg, f, 'linear');   % align to shared grid
        end
        if ~ok, continue; end
        for r=1:nRoi, specsC{r}(:,end+1)=roiPow{r}; end %#ok<AGROW>
        [~,nm]=fileparts(files{k}); labels{end+1}=[pre regexprep(nm,'_(fooof|clean)$','')]; %#ok<AGROW>
    end
end
end

function d = load_ft(file)
d=[]; S=load(file); fn=fieldnames(S);
for i=1:numel(fn)
    v=S.(fn{i}); if iscell(v)&&~isempty(v), v=v{1}; end
    if isstruct(v)&&isfield(v,'label')&&isfield(v,'trial')
        if ~isfield(v,'fsample')||isempty(v.fsample), v.fsample=round(1/median(diff(v.time{1}))); end
        d=v; return;
    end
end
end

function s = none_if_empty(c)
if isempty(c), s='(none)'; else, s=strjoin(c,', '); end
end
