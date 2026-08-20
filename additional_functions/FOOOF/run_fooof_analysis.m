%% run_fooof_analysis.m
% Driver script: parameterize EEG power spectra with FOOOF (specparam) and
% compare periodic (alpha center frequency / power / bandwidth) and aperiodic
% (offset / exponent) parameters between two groups.
%
% Implements Donoghue et al. (2020), Nat Neurosci 23:1655-1665, in native
% MATLAB (no Python, no FOOOF toolbox). Uses:
%   fooof_fit.m                  - fit one spectrum
%   fooof_group.m                - fit a whole group + extract alpha/aperiodic
%   plot_fooof_fit.m             - one subject's fit
%   plot_fooof_group_fits.m      - fits for each group
%   plot_fooof_group_comparison.m- between-group parameter comparison + stats
%
% =========================================================================
% WHICH EEG DATA TO USE (read this first)
% =========================================================================
% Use PREPROCESSED, artifact-cleaned, continuous resting-state data -- NOT raw.
% In your pipeline that is the ICA-cleaned FieldTrip struct `dat_after_ICA`
% (the *_clean.mat files), which already is: demeaned/detrended, band-pass
% filtered, line-noise notched, bad segments set to NaN, bad channels
% interpolated, and eye-ICA components removed. That is exactly the right input.
%
% Key points, and WHY they matter for FOOOF specifically:
%   1. FEED LINEAR POWER (V^2/Hz), not dB and not pre-log'd. fooof_fit takes
%      log10 internally (the algorithm works in semilog space). Your psd_nan.m
%      already returns linear PSD -- perfect. Do NOT pass 10*log10(...).
%   2. WELCH PSD with the paper's settings: 2 s windows, 50% overlap, Hann.
%      psd_nan(x, fs, 2, 0.5) does exactly this AND skips NaN artifact windows.
%   3. FIT RANGE 2-40 Hz, aperiodic mode 'fixed' (no knee). Scalp EEG over this
%      range is well fit by a straight 1/f line, so a knee is not needed. Keep
%      the range BELOW your 50/60 Hz notch -- the notch dip corrupts the
%      aperiodic fit if included. (Widen to a knee model only for very broad
%      ranges / intracranial data.)
%   4. DON'T OVER-PROCESS the aperiodic component away. A ~1 Hz high-pass and
%      the notch are fine. Avoid aggressive high-pass (>~1 Hz), heavy smoothing,
%      or spectral whitening -- they change offset/exponent, which are real
%      signals here, not nuisance.
%   5. CHANNELS: the paper reads alpha from a posterior channel (Oz/POz/Pz) and
%      the aperiodic component from Cz. Either pick a channel or average the PSD
%      over a small posterior ROI (recommended for your data). Average the
%      *power* across channels, then fit once per subject.
%   6. Enough clean data: aim for >= ~30-60 s of NaN-free resting EEG so Welch
%      averages many windows and the spectrum is smooth. psd_nan prints how much
%      clean time it used -- check it.
% =========================================================================

clear; clc; close all;

%% -------------------- 0. Choose a mode --------------------
% Set to true to run a quick self-test on SIMULATED spectra (no data needed),
% which verifies the algorithm recovers known ground-truth parameters.
% Set to false to run on your real EEG data (fill in Section 2).
RUN_SELFTEST = false;

%% -------------------- 1. Analysis settings --------------------
cfg = [];
cfg.freq_range        = [2 40];     % fit range (Hz)
cfg.aperiodic_mode    = 'fixed';    % 'fixed' or 'knee'
cfg.peak_width_limits = [1 6];      % min/max bandwidth (Hz)
cfg.max_n_peaks       = 6;
cfg.min_peak_height   = 0.05;       % log10 power
cfg.peak_threshold    = 1.5;        % in SD of the flattened spectrum
cfg.alpha_band        = [7 14];     % window for picking the alpha peak (Hz)

% Outlier-exclusion rule (see fooof_exclude.m). Default = the paper's rule.
cfg.exclusion         = 'sd';       % 'sd' (2.5-SD-from-mean, paper) | 'r2' | 'none'
cfg.exclusion_nsd     = 2.5;        % SD multiplier for 'sd' mode
cfg.exclusion_logic   = 'or';       % flag if R^2 OR error is an outlier ('and' = both)
cfg.r2_thresh         = 0.90;       % used only if exclusion = 'r2'

fs      = 250;                      % only used by the SELF-TEST; real-data fs is
                                    % read from each file's .fsample
win_sec = 2;  overlap = 0.5;        % Welch window / overlap (paper settings)

if RUN_SELFTEST
    %% -------------------- SELF-TEST: simulated data --------------------
    % Build two groups whose ground-truth alpha CF and aperiodic exponent
    % differ, then confirm FOOOF recovers the difference.
    f = (0:0.5:60)';  f(1) = [];             % 0.5 Hz resolution, drop DC
    rng(7);
    % Group 1: alpha ~10 Hz, exponent ~1.4 ; Group 2: alpha ~9 Hz, exponent ~1.0
    S1 = sim_group(f, 14, [ -21.5 1.4 ], [10.0 0.55 1.2], 0.02);
    S2 = sim_group(f, 10, [ -21.5 1.0 ], [ 9.0 0.40 1.4], 0.02);
    lab1 = compose('sim1_%02d', (1:14)');    lab1 = cellstr(lab1);
    lab2 = compose('sim2_%02d', (1:10)');    lab2 = cellstr(lab2);
    name1 = 'GroupA'; name2 = 'GroupB';
else
    %% -------------------- 2. REAL DATA: build PSD matrices --------------
    % Point each group at its FOLDER of *.mat files -- every .mat in the folder
    % is treated as one subject, no need to list files. Each file holds a
    % FieldTrip struct (auto-detected by content, e.g. `data_repaired` or
    % `dat_after_ICA`) with the continuous recording; the sampling rate is read
    % from each file. Adjust the folders / ROI as needed.

    roi_alpha = {'Oz','POz','Pz','O1','O2'};               % posterior ROI for alpha
    roi_ap    = {'Cz'};                                    % Cz for aperiodic (paper)
    folder1 = 'C:\Users\yarde\Documents\MONAD_Git\Data\TalKennet\tactile\FOOOF\NT';   % group 1
    folder2 = 'C:\Users\yarde\Documents\MONAD_Git\Data\TalKennet\tactile\FOOOF\ASD';  % group 2
    name1 = 'NT'; name2 = 'ASD';

    % PSD cache: computing the spectra reads ~3 GB from disk, so the results
    % are cached. Delete fooof_psd_cache.mat to force a re-read (e.g. after
    % changing the ROI, folders, or Welch settings).
    CACHE = fullfile(pwd, 'fooof_psd_cache.mat');
    if isfile(CACHE)
        fprintf('Loading cached PSDs from %s (delete it to force re-read).\n', CACHE);
        load(CACHE, 'S1','S2','S1_cz','S2_cz','f','lab1','lab2');
    else
        % One load per file computes both ROIs (posterior + Cz).
        [C1, f,  lab1] = build_group_psd(folder1, {roi_alpha, roi_ap}, win_sec, overlap);
        [C2, f2, lab2] = build_group_psd(folder2, {roi_alpha, roi_ap}, win_sec, overlap);
        assert(isequal(f, f2), ['The two groups produced different frequency axes ' ...
            '(different sampling rate or window?). Cannot compare directly.']);
        S1 = C1{1};  S1_cz = C1{2};      % posterior-ROI and Cz power spectra
        S2 = C2{1};  S2_cz = C2{2};
        save(CACHE, 'S1','S2','S1_cz','S2_cz','f','lab1','lab2');
        fprintf('Cached PSDs to %s\n', CACHE);
    end
end

%% -------------------- 3. Fit FOOOF per group --------------------
% Group colors travel with each group struct, so every plot uses them.
% Group 1 (controls / NT) -> GREEN ; Group 2 (ASD) -> BLUE.
COL_CTRL = [0.15 0.60 0.20];   % green
COL_ASD  = [0.00 0.45 0.74];   % blue
cfg1 = cfg; cfg1.labels = lab1; cfg1.group_name = name1; cfg1.color = COL_CTRL;
cfg2 = cfg; cfg2.labels = lab2; cfg2.group_name = name2; cfg2.color = COL_ASD;

G1 = fooof_group(f, S1, cfg1);
G2 = fooof_group(f, S2, cfg2);

disp(G1.table);
disp(G2.table);

%% -------------------- 4. Plots --------------------
% (a) One example single-subject fit (first subject of group 1)
plot_fooof_fit(G1.fits(1).r, sprintf('%s - %s', name1, G1.labels{1}), G1.color);

% (b) Fits for each group (individual + mean + mean aperiodic)
plot_fooof_group_fits(G1, G2);

% (c) Between-group comparison of the five parameters (+ stats)
stats = plot_fooof_group_comparison(G1, G2); %#ok<NASGU>

%% -------------------- 5. Comparison WITHOUT outliers --------------------
% Drop fit-failure subjects, then re-plot the comparison on the clean subset.
% The exclusion rule is set by cfg.exclusion (see fooof_exclude.m); the default
% is the paper's 2.5-SD-from-mean rule.
[keep1, ex1] = fooof_exclude(G1, cfg);
[keep2, ex2] = fooof_exclude(G2, cfg);
fprintf('\n--- Outlier exclusion (mode: %s) ---\n', cfg.exclusion);
if strcmpi(cfg.exclusion,'sd')
    fprintf('%s: R^2 cut < %.3f, error cut > %.4f  -> excluded: %s\n', name1, ...
        ex1.r2_cut, ex1.err_cut, ternary(isempty(ex1.excluded_labels),'(none)',strjoin(ex1.excluded_labels,', ')));
    fprintf('%s: R^2 cut < %.3f, error cut > %.4f  -> excluded: %s\n', name2, ...
        ex2.r2_cut, ex2.err_cut, ternary(isempty(ex2.excluded_labels),'(none)',strjoin(ex2.excluded_labels,', ')));
else
    fprintf('%s excluded: %s\n', name1, ternary(isempty(ex1.excluded_labels),'(none)',strjoin(ex1.excluded_labels,', ')));
    fprintf('%s excluded: %s\n', name2, ternary(isempty(ex2.excluded_labels),'(none)',strjoin(ex2.excluded_labels,', ')));
end

G1c = fooof_subset_group(G1, keep1);
G2c = fooof_subset_group(G2, keep2);
stats_clean = plot_fooof_group_comparison(G1c, G2c); %#ok<NASGU>
set(gcf, 'Name', 'FOOOF comparison (outliers excluded)');

%% -------------------- 6. Aperiodic component from Cz --------------------
% The paper reads the aperiodic component (offset, exponent) from Cz, not the
% posterior ROI. Fit Cz spectra and compare, using the same exclusion rule.
if exist('S1_cz','var')
    cfg1cz = cfg1; cfg1cz.group_name = [name1 ' (Cz)'];
    cfg2cz = cfg2; cfg2cz.group_name = [name2 ' (Cz)'];
    G1cz = fooof_group(f, S1_cz, cfg1cz);
    G2cz = fooof_group(f, S2_cz, cfg2cz);

    kz1 = fooof_exclude(G1cz, cfg);
    kz2 = fooof_exclude(G2cz, cfg);
    fprintf('\n--- Cz aperiodic (exclusion mode: %s) ---\n', cfg.exclusion);
    fprintf('%s: kept %d/%d.  %s: kept %d/%d.\n', ...
        name1, nnz(kz1), numel(kz1), name2, nnz(kz2), numel(kz2));

    G1czc = fooof_subset_group(G1cz, kz1);
    G2czc = fooof_subset_group(G2cz, kz2);
    stats_cz = plot_fooof_group_comparison(G1czc, G2czc); %#ok<NASGU>
    set(gcf, 'Name', 'Cz aperiodic comparison (look at offset & exponent)');
end

fprintf('\nDone. Inspect the figures and the printed comparison tables.\n');


%% ======================= local helper functions =======================
function [specsC, f, labels] = build_group_psd(source, rois, win_sec, overlap)
% Compute ROI-averaged PSDs per subject, for one or more ROIs, in a single
% load per file. `source` is a FOLDER path (every *.mat in it is one subject)
% or a cell array of explicit file paths. `rois` is a cell array of ROIs, each
% ROI being a cellstr of channel names (e.g. {{'Oz','POz'}, {'Cz'}}).
% Returns specsC: 1 x numel(rois) cell, each [nFreq x nSubj] linear-power PSD.
if ischar(source) || isstring(source)
    L = dir(fullfile(char(source), '*.mat'));
    files = fullfile(char(source), {L.name});
    if isempty(files), error('No .mat files found in folder: %s', char(source)); end
else
    files = source;                            % already a cell of file paths
end
if ~iscell(rois{1}), rois = {rois}; end        % allow a single ROI cellstr

nRoi = numel(rois);
specsC = repmat({[]}, 1, nRoi); f = []; labels = {};
for k = 1:numel(files)
    d = load_ft_struct(files{k});
    if isempty(d)
        warning('No FieldTrip struct (with .label/.trial) in %s; skipping.', files{k});
        continue;
    end
    fs = d.fsample;                            % sampling rate read from the file
    roiPow = cell(1,nRoi); ok = true;
    for r = 1:nRoi
        ch = find(ismember(d.label, rois{r}));
        if isempty(ch)
            warning('None of channels {%s} in %s; skipping subject.', ...
                strjoin(rois{r}, ','), files{k});
            ok = false; break;
        end
        P = zeros(0, numel(ch)); ci = 0;
        for c = ch(:)'
            [pxx, ff] = psd_nan(d.trial{1}(c,:), fs, win_sec, overlap);
            if isempty(f), f = ff; end
            if isempty(P), P = zeros(numel(pxx), numel(ch)); end
            ci = ci + 1; P(:,ci) = pxx;
        end
        roiPow{r} = mean(P, 2, 'omitnan');     % average power across ROI channels
    end
    if ~ok, continue; end
    for r = 1:nRoi, specsC{r}(:, end+1) = roiPow{r}; end %#ok<AGROW>
    [~, nm] = fileparts(files{k});
    labels{end+1} = regexprep(nm, '_(fooof|clean)$', ''); %#ok<AGROW> % strip suffix
    fprintf('  loaded %s (fs=%g)\n', labels{end}, fs);
end
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

function d = load_ft_struct(file)
% Load a .mat and return the first variable that looks like a FieldTrip raw
% struct (has .label and .trial). Handles arbitrary variable names, e.g.
% `data_repaired`, `dat_after_ICA`. Ensures a .fsample field is present.
d = [];
S = load(file);
fn = fieldnames(S);
for i = 1:numel(fn)
    v = S.(fn{i});
    if iscell(v) && ~isempty(v), v = v{1}; end          % unwrap {struct}
    if isstruct(v) && isfield(v,'label') && isfield(v,'trial')
        if ~isfield(v,'fsample') || isempty(v.fsample)
            v.fsample = round(1 / median(diff(v.time{1})));  % derive if missing
        end
        d = v; return;
    end
end
end

function specs = sim_group(f, n, ap, pk, noise)
% Simulate n spectra: aperiodic [offset exponent] + one Gaussian [CF PW BW],
% with small per-subject jitter and multiplicative noise. Returns LINEAR power.
specs = zeros(numel(f), n);
for s = 1:n
    off = ap(1) + 0.2*randn;  ex = ap(2) + 0.08*randn;
    cf  = pk(1) + 0.5*randn;  pw = max(pk(2) + 0.06*randn, 0.05);  bw = pk(3);
    logp = off - ex*log10(f) + pw*exp(-(f-cf).^2 ./ (2*(bw/2)^2));
    logp = logp + noise*randn(size(f));       % additive noise in log space
    specs(:,s) = 10.^logp;                     % back to linear power
end
end
