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
%   * CFG.rois    : struct of ROI name -> channel list. A channel list may be
%                   the string 'all' = every shared electrode (intersected
%                   across datasets when CFG.dataset='combined').
%   First run per dataset reloads the raw *_fooof.mat and caches PER-CHANNEL
%   spectra (fooof_cache_<dataset>.mat); changing ROIs/electrodes is then
%   instant (no rebuild). The cache rebuilds only if the montage or the Welch
%   window/frequency grid changes.
%
% Requires (only when CFG.engine='original'): Python `fooof` installed, MATLAB
% pointed at it (CFG.python), and the fooof_mat/ folder next to this script.
% ---------------------------------------------------------------------------

clear; clc; close all;

%% ===================== CONFIG (edit this) =====================
CFG.dataset  = 'OSF';         % 'OSF' | 'TalKennet' | 'combined'
CFG.engine   = 'original';    % 'original' | 'native'
CFG.settings = 'resting';     % 'library' | 'resting'
CFG.exclusion= 'sd';          % bad-fit exclusion: 'sd' (paper 2.5-SD) | 'r2' | 'none'
CFG.show_fits= true;         % also draw the individual+mean fit overlay per ROI
CFG.save_tables = true;       % write CSV summary tables (all + excluded) per run
CFG.run_label   = '';         % optional tag added to output filenames (keep runs separate)

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
    'frontal',{{'Fp1','Fpz','Fp2','AF7','AF3','AFz','AF4','AF8','F7','F5','F3','F1','Fz','F2','F4','F6','F8'}},...
    'central',   {{'FC3','FC1','FCz','FC2','FC4','C3','C1','Cz','C2','C4','CP1','CPz','CP2'}}, ...
    'temporalL', {{'FT7','FC5','T7','C5','TP7','CP5','P7','P9'}},...
    'temporalR', {{'FT8','FC6','T8','C6','TP8','CP6','P8','P10'}},...
    'parietal', {{'CP3','CP4','P5','P3','P1','Pz','P2','P4','P6'}},...
    'occipital', {{'PO7','PO3','POz','PO4','PO8','O1','Oz','O2','Iz'}});

CFG.freq_range = [2 40];      % FOOOF fit range (Hz)
% Bands to analyze. EACH band gets its own periodic figure (center freq, power,
% bandwidth). Names are free-form; add/remove as you like.
CFG.bands = struct('delta',[1,4],'theta',[4,8],'alpha',[8 13],'beta',[13 30], 'gamma',[30 40]);   % e.g. struct('theta',[4 8],'alpha',[8 13],'beta',[13 30])
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

%% ---- build (or load) PER-CHANNEL power spectra ----
% The cache stores PSDs for EVERY shared channel, so any ROI (including 'all')
% is just an instant re-average. It rebuilds only when the dataset's montage or
% the frequency grid changes -- NOT when you change ROIs/electrodes.
CACHE = fullfile(here, sprintf('fooof_cache_%s.mat', CFG.dataset));
if isfile(CACHE)
    S = load(CACHE);
    if isfield(S,'commonChans') && isequal(S.f, f)
        chanNT=S.chanNT; chanASD=S.chanASD; labNT=S.labNT; labASD=S.labASD;
        commonChans=S.commonChans;
        fprintf('Loaded %s per-channel PSDs from cache (%d channels).\n', CFG.dataset, numel(commonChans));
    else
        fprintf('Cache mismatch -> rebuilding.\n'); clear S;
    end
end
if ~exist('chanNT','var')
    % Shared montage across the run's dataset(s): montage of the first file of
    % each dataset, intersected (so combined runs use only shared electrodes).
    montages = cell(1,numel(sets));
    for si = 1:numel(sets)
        Ld = dir(fullfile(sets{si}.NT,'*.mat'));
        dref = load_ft(fullfile(sets{si}.NT, Ld(1).name)); montages{si} = dref.label(:);
    end
    commonChans = montages{1};
    for si = 2:numel(montages), commonChans = intersect(commonChans, montages{si}, 'stable'); end
    [chanNT,  labNT ] = build_channel_psd(NTfolders,  tags, commonChans, f, CFG.win_sec, CFG.overlap);
    [chanASD, labASD] = build_channel_psd(ASDfolders, tags, commonChans, f, CFG.win_sec, CFG.overlap);
    save(CACHE, 'chanNT','chanASD','labNT','labASD','f','commonChans');
    fprintf('Cached %s per-channel PSDs (%d channels) to %s\n', CFG.dataset, numel(commonChans), CACHE);
end

% Resolve any ROI whose value is 'all' to the shared-channel set (all shared
% electrodes), then finalize the ROI list.
rfn = fieldnames(CFG.rois);
for i = 1:numel(rfn)
    v = CFG.rois.(rfn{i});
    if (ischar(v) || isstring(v)) && strcmpi(char(v),'all')
        CFG.rois.(rfn{i}) = commonChans(:)';
    end
end
roiNames = fieldnames(CFG.rois);
roiList  = cellfun(@(n) CFG.rois.(n), roiNames, 'UniformOutput', false); %#ok<NASGU>

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
    'bands',CFG.bands,'exclusion',CFG.exclusion,'exclusion_nsd',2.5,'exclusion_logic','or');
COL_NT=[0.15 0.60 0.20]; COL_ASD=[0.00 0.45 0.74];

%% ---- fit + compare, per ROI ----
bnames = fieldnames(CFG.bands);
fprintf('\n=== Dataset: %s | engine: %s | settings: %s | bands: %s ===\n', ...
    CFG.dataset, CFG.engine, CFG.settings, strjoin(bnames',', '));
% Accumulators for the summary tables (per ROI): all-subjects and excluded.
roiLbl=cell(1,numel(roiNames)); allNT=roiLbl; allASD=roiLbl; exNT=roiLbl; exASD=roiLbl;
for r = 1:numel(roiNames)
    rn = roiNames{r}; chans = CFG.rois.(rn);
    chanLabel = sprintf('%s (%s)', [upper(rn(1)) rn(2:end)], strjoin(chans,','));
    fprintf('\n########## ROI: %s ##########\n', chanLabel);

    cN=base; cN.labels=labNT;  cN.group_name='NT';  cN.color=COL_NT;
    cA=base; cA.labels=labASD; cA.group_name='ASD'; cA.color=COL_ASD;
    GN = Gfit(f, roi_average(chanNT,  commonChans, chans), cN);
    GA = Gfit(f, roi_average(chanASD, commonChans, chans), cA);

    % ----- ALL subjects: aperiodic figure + one periodic figure per band -----
    fprintf('--- %s: ALL subjects (NT=%d, ASD=%d) ---\n', rn, numel(GN.offset), numel(GA.offset));
    plot_fooof_aperiodic(GN, GA, chanLabel);
    set(gcf,'Name',sprintf('%s | %s | ALL | aperiodic', CFG.dataset, rn));
    for bi = 1:numel(bnames)
        plot_fooof_periodic(GN, GA, bnames{bi}, chanLabel);
        set(gcf,'Name',sprintf('%s | %s | ALL | %s', CFG.dataset, rn, bnames{bi}));
    end

    % ----- bad-fit excluded -----
    [kN,exN]=fooof_exclude(GN,base); [kA,exA]=fooof_exclude(GA,base);
    fprintf('--- %s: bad-fit excluded (%s) | NT out: %s | ASD out: %s ---\n', rn, CFG.exclusion, ...
        none_if_empty(exN.excluded_labels), none_if_empty(exA.excluded_labels));
    GNx = fooof_subset_group(GN,kN); GAx = fooof_subset_group(GA,kA);
    roiLbl{r}=chanLabel; allNT{r}=GN; allASD{r}=GA; exNT{r}=GNx; exASD{r}=GAx;
    plot_fooof_aperiodic(GNx, GAx, chanLabel);
    set(gcf,'Name',sprintf('%s | %s | excluded | aperiodic', CFG.dataset, rn));
    for bi = 1:numel(bnames)
        plot_fooof_periodic(GNx, GAx, bnames{bi}, chanLabel);
        set(gcf,'Name',sprintf('%s | %s | excluded | %s', CFG.dataset, rn, bnames{bi}));
    end

    if CFG.show_fits   % optional: individual + group-mean fit overlay
        plot_fooof_group_fits(GN, GA);
        set(gcf,'Name',sprintf('%s | %s | fits', CFG.dataset, rn));
    end
end

%% ---- summary tables (all subjects + excluded), saved to CSV ----
if CFG.save_tables
    bandstr = strjoin(bnames',',');
    tdir = fullfile(here,'summary_tables');
    % Filename encodes dataset+engine+settings+ROI names (+ optional run_label)
    % so different electrode sets don't overwrite each other.
    lab = ''; if ~isempty(CFG.run_label), lab = ['_' CFG.run_label]; end
    roitag = strjoin(roiNames','-');
    if numel(roitag) > 40, roitag = sprintf('%dROIs', numel(roiNames)); end
    tag  = sprintf('%s_%s_%s_%s%s', CFG.dataset, CFG.engine, CFG.settings, roitag, lab);
    nNT = numel(allNT{1}.offset); nASD = numel(allASD{1}.offset);

    optA = struct('name1','NT','name2','ASD');
    optA.titleStr = sprintf(['%s | NT (N=%d) vs ASD (N=%d) | engine=%s, settings=%s, ' ...
        'bands=[%s] | ALL subjects (no exclusions)'], CFG.dataset, nNT, nASD, ...
        CFG.engine, CFG.settings, bandstr);
    optA.csvpath = fullfile(tdir, sprintf('fooof_summary_%s_ALL.csv', tag));
    fooof_summary_table(roiLbl, allNT, allASD, optA);

    optE = optA;
    optE.titleStr = sprintf(['%s | NT (started N=%d) vs ASD (started N=%d) | engine=%s, ' ...
        'settings=%s, bands=[%s] | AFTER bad-fit exclusion (rule=%s); per-cell n = included NT/ASD'], ...
        CFG.dataset, nNT, nASD, CFG.engine, CFG.settings, bandstr, CFG.exclusion);
    optE.csvpath = fullfile(tdir, sprintf('fooof_summary_%s_EXCLUDED.csv', tag));
    fooof_summary_table(roiLbl, exNT, exASD, optE);
end

fprintf('\nDone. Figures + CSV summary tables (all & excluded) written.\n');

%% ======================= local helpers =======================
function [chanPSD, labels] = build_channel_psd(folders, tags, chans, f, win_sec, overlap)
% Per-channel PSD for the shared channel set `chans`, for every subject pooled
% across folders. Returns chanPSD: nFreq x nChan x nSubj (channels in `chans`
% order), interpolated onto the shared grid f, and the subject labels.
nCh=numel(chans); chanPSD=zeros(numel(f),nCh,0); labels={};
for j=1:numel(folders)
    L=dir(fullfile(folders{j},'*.mat')); files=fullfile(folders{j},{L.name});
    if isempty(files), warning('No .mat files in %s', folders{j}); continue; end
    pre=''; if numel(folders)>1 && ~isempty(tags{j}), pre=[tags{j} ':']; end
    for k=1:numel(files)
        d=load_ft(files{k}); if isempty(d), continue; end
        [tf,loc]=ismember(chans, d.label);
        if ~all(tf), warning('Channels %s missing in %s; skipping subject.', ...
                strjoin(chans(~tf),','), files{k}); continue; end
        M=zeros(numel(f),nCh);
        for c=1:nCh
            [pxx,ff]=psd_nan(d.trial{1}(loc(c),:), d.fsample, win_sec, overlap);
            M(:,c)=interp1(ff,pxx,f,'linear');
        end
        chanPSD(:,:,end+1)=M; %#ok<AGROW>
        [~,nm]=fileparts(files{k}); labels{end+1}=[pre regexprep(nm,'_(fooof|clean)$','')]; %#ok<AGROW>
    end
end
end

function P = roi_average(chanPSD, chanLabels, roiChans)
% Average per-channel PSDs (nFreq x nChan x nSubj) over the ROI channels that
% exist in the cached montage. Returns nFreq x nSubj.
[tf,loc]=ismember(roiChans, chanLabels); loc=loc(tf);
if isempty(loc), error('roi_average: none of the ROI channels are in the montage.'); end
if numel(loc) < numel(roiChans)
    warning('roi_average: %d of %d ROI channels not in montage; averaging the rest.', ...
        numel(roiChans)-numel(loc), numel(roiChans));
end
P = squeeze(mean(chanPSD(:,loc,:), 2, 'omitnan'));   % nFreq x nSubj
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
