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
cfg.alpha_band        = [8 13];     % window for picking the alpha peak (Hz)

fs      = 250;                      % <-- your sampling rate (Hz)
win_sec = 2;  overlap = 0.5;        % Welch window / overlap (paper settings)

%% Choose data folder
if ~RUN_SELFTEST
    env = setupEnviroment11();
    cd(env.paths.git)
    addpath(env.paths.extra_func); addpath(fullfile(env.paths.ft_path, 'external', 'eeglab'));
    fs=env.data.fsample;
end

%% Run
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
    % Fill these two cell arrays with the *_clean.mat files for each group,
    % then this block computes one PSD per subject over a posterior ROI.
    %
    % Each *_clean.mat contains `dat_after_ICA` (a FieldTrip raw struct, one
    % continuous trial with NaN artifact gaps). Adjust paths / ROI as needed.

    roi   = {'Oz','POz','Pz','O1','O2'};     % posterior ROI for alpha
    name1 = 'NT'; name2 = 'ASD';
    files1 = { ... % <-- group 1 clean files
        % 'C:\...\clean\103301_clean.mat', ...
        };
    files2 = { ... % <-- group 2 clean files
        % 'C:\...\clean\030809_clean.mat', ...
        };
    

    [S1, f, lab1] = build_group_psd(files1, roi, fs, win_sec, overlap);
    [S2, ~, lab2] = build_group_psd(files2, roi, fs, win_sec, overlap);
end

%% -------------------- 3. Fit FOOOF per group --------------------
cfg1 = cfg; cfg1.labels = lab1; cfg1.group_name = name1;
cfg2 = cfg; cfg2.labels = lab2; cfg2.group_name = name2;

G1 = fooof_group(f, S1, cfg1);
G2 = fooof_group(f, S2, cfg2);

disp(G1.table);
disp(G2.table);

%% -------------------- 4. Plots --------------------
% (a) One example single-subject fit (first subject of group 1)
plot_fooof_fit(G1.fits(1).r, sprintf('%s - %s', name1, G1.labels{1}));

% (b) Fits for each group (individual + mean + mean aperiodic)
plot_fooof_group_fits(G1, G2);

% (c) Between-group comparison of the five parameters (+ stats)
stats = plot_fooof_group_comparison(G1, G2); %#ok<NASGU>

fprintf('\nDone. Inspect the three figures and the printed comparison table.\n');


%% ======================= local helper functions =======================
function [specs, f, labels] = build_group_psd(files, roi, fs, win_sec, overlap)
% Compute one posterior-ROI PSD per subject from *_clean.mat FieldTrip data.
specs = []; f = []; labels = {};
for k = 1:numel(files)
    S = load(files{k});
    d = S.dat_after_ICA;
    if iscell(d), d = d{1}; end               % some files store it wrapped
    ch = find(ismember(d.label, roi));
    if isempty(ch), warning('No ROI channels in %s; skipping.', files{k}); continue; end
    % Average PSD across ROI channels (average power, then it is fit once)
    P = [];
    for c = ch(:)'
        [pxx, ff] = psd_nan(d.trial{1}(c,:), fs, win_sec, overlap);
        if isempty(P), P = zeros(numel(pxx), numel(ch)); f = ff; ci = 0; end
        ci = ci + 1; P(:,ci) = pxx; %#ok<AGROW>
    end
    specs(:, end+1) = mean(P, 2, 'omitnan'); %#ok<AGROW>
    [~, nm] = fileparts(files{k}); labels{end+1} = nm; %#ok<AGROW>
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
