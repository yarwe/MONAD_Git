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
% In your pipeline that is the *_fooof.mat files written by prepare_for_fooof.m
% (the ICA-cleaned FieldTrip struct `data_repaired`; the older *_clean.mat
% files hold the same thing as `dat_after_ICA`), which already is:
% demeaned/detrended, band-pass
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
    % The input is the *_fooof.mat files written by prepare_for_fooof.m, each
    % holding one FieldTrip raw struct (one continuous trial with NaN artifact
    % gaps). This block computes one PSD per subject over a posterior ROI.
    %
    % Nothing here is typed in by hand: which experiment/paradigm to read is
    % set in config_local.m, and collect_fooof_files() below turns that into
    % the two file lists - so the same script runs on OSF ('A1_fooof.mat' /
    % 'C1_fooof.mat') and on TalKennet ('030801_fooof.mat') unchanged.

    env = setupEnviroment11();
    addpath(fullfile(env.paths.git, 'additional_functions', 'FOOOF'));

    % Folder holding the *_fooof.mat files, either flat or split into
    % ASD/ and NT/ subfolders. prepare_for_fooof.m writes them here.
    fooof_root = fullfile(env.paths.preproc, 'FOOOF');

    roi = {'Oz','POz','Pz','O1','O2'};       % posterior ROI for alpha
    fs  = env.data.fsample;                  % per-file fsample overrides this

    [files1, files2, name1, name2] = collect_fooof_files(env, fooof_root);

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
function [files_nt, files_asd, name_nt, name_asd] = collect_fooof_files(env, fooof_root)
% List the *_fooof.mat files of each group, for whichever experiment is set
% in config_local.m. Every experiment writes the same <ID>_fooof.mat pattern,
% but what an ID looks like and how it maps onto a group differs:
%
%   OSF        'A1_fooof.mat' / 'C1_fooof.mat' - the leading letter is the
%              group ('A' = ASD, 'C' = NT), the same rule groupDataByExperiment
%              uses.
%   TalKennet  '030801_fooof.mat' - the numeric IDs carry no group, so
%              membership is read from Number_group_meg_eeg_biomarkers.csv in
%              the experiment-level folder.
%
% Both folder layouts are handled: the files may sit directly in
% <paradigm>/FOOOF/, or be pre-sorted into FOOOF/ASD/ and FOOOF/NT/.

name_nt = 'NT'; name_asd = 'ASD';

if ~exist(fooof_root, 'dir')
    error(['FOOOF folder not found: %s\n' ...
           'Run prepare_for_fooof.m first, or point fooof_root at the folder ' ...
           'holding the *_fooof.mat files.'], fooof_root);
end

sub_asd = fullfile(fooof_root, name_asd);
sub_nt  = fullfile(fooof_root, name_nt);

if exist(sub_asd, 'dir') || exist(sub_nt, 'dir')
    % Layout A: already sorted into per-group subfolders
    files_asd = list_fooof(sub_asd);
    files_nt  = list_fooof(sub_nt);
else
    % Layout B: one flat folder - split it by the experiment's grouping rule
    all_files = list_fooof(fooof_root);
    IDs       = string(fooof_ids(all_files));

    switch lower(env.exp)
        case 'osf'
            is_asd = startsWith(IDs, 'A');
            is_nt  = startsWith(IDs, 'C');
        case 'talkennet'
            tbl    = load_talkennet_groups(env);
            is_asd = ismember(IDs, tbl.Number(tbl.Group == "ASD"));
            is_nt  = ismember(IDs, tbl.Number(tbl.Group == "NT"));
        otherwise
            error(['Grouping is not defined for experiment ''%s''. Add a case ' ...
                   'for it in collect_fooof_files (see groupDataByExperiment ' ...
                   'for the same per-experiment rules).'], env.exp);
    end

    files_asd = all_files(is_asd);
    files_nt  = all_files(is_nt);

    skipped = all_files(~(is_asd | is_nt));
    if ~isempty(skipped)
        warning('%d file(s) in %s belong to no group and were skipped: %s', ...
            numel(skipped), fooof_root, strjoin(fooof_ids(skipped), ', '));
    end
end

if isempty(files_nt) || isempty(files_asd)
    error(['Found %d %s and %d %s file(s) under %s. Expected *_fooof.mat ' ...
           'files for both groups - check that prepare_for_fooof.m has run ' ...
           'for this experiment/paradigm.'], ...
           numel(files_nt), name_nt, numel(files_asd), name_asd, fooof_root);
end

fprintf('FOOOF input: %d %s + %d %s file(s) from %s\n', ...
    numel(files_nt), name_nt, numel(files_asd), name_asd, fooof_root);
end

% ------------------------------------------------------------------------
function files = list_fooof(folder)
% Full paths of every *_fooof.mat in folder ({} when the folder is absent).
files = {};
if ~exist(folder, 'dir'), return; end
d = dir(fullfile(folder, '*_fooof.mat'));
d = d(~[d.isdir]);
if isempty(d), return; end
files = fullfile(folder, {d.name});
end

% ------------------------------------------------------------------------
function ids = fooof_ids(files)
% Participant ID of each file: 'A1_fooof.mat' -> 'A1', '030801_fooof.mat' -> '030801'.
ids = cell(size(files));
for k = 1:numel(files)
    [~, nm] = fileparts(files{k});
    ids{k}  = erase(nm, '_fooof');
end
end

% ------------------------------------------------------------------------
function tbl = load_talkennet_groups(env)
% TalKennet group membership. The file describes the whole experiment, not one
% paradigm, so it lives in the experiment-level folder next to TK_customLay.mat
% (same file and same normalisation as groupDataByExperiment).
group_file = fullfile(env.paths.exp, 'Number_group_meg_eeg_biomarkers.csv');
if ~isfile(group_file)
    error('TalKennet group file not found: %s', group_file);
end
tbl        = readtable(group_file);
tbl.Number = string(pad(string(tbl.Number), 6, 'left', '0'));
tbl.Group  = string(tbl.Group);
tbl.Group(tbl.Group == "TD") = "NT";      % TD and NT are the same group
end

% ------------------------------------------------------------------------
function [specs, f, labels] = build_group_psd(files, roi, fs, win_sec, overlap)
% Compute one posterior-ROI PSD per subject from *_fooof.mat FieldTrip data.
specs = []; f = []; labels = {};
for k = 1:numel(files)
    d = load_ft_struct(files{k});
    if isempty(d), continue; end
    if isfield(d, 'fsample') && ~isempty(d.fsample), fs_k = d.fsample; else, fs_k = fs; end
    ch = find(ismember(d.label, roi));
    if isempty(ch), warning('No ROI channels in %s; skipping.', files{k}); continue; end
    % Average PSD across ROI channels (average power, then it is fit once)
    P = [];
    for c = ch(:)'
        [pxx, ff] = psd_nan(d.trial{1}(c,:), fs_k, win_sec, overlap);
        if isempty(P), P = zeros(numel(pxx), numel(ch)); f = ff; ci = 0; end
        ci = ci + 1; P(:,ci) = pxx; %#ok<AGROW>
    end
    specs(:, end+1) = mean(P, 2, 'omitnan'); %#ok<AGROW>
    id = fooof_ids(files(k));
    labels{end+1} = id{1}; %#ok<AGROW>
end
end

% ------------------------------------------------------------------------
function d = load_ft_struct(file)
% Load the one FieldTrip raw struct stored in file, whatever it is called.
% prepare_for_fooof.m saves `data_repaired`; the older *_clean.mat files save
% `dat_after_ICA`, so accept either (and any other single struct).
S      = load(file);
fields = fieldnames(S);
known  = intersect({'data_repaired', 'dat_after_ICA'}, fields, 'stable');
if ~isempty(known)
    d = S.(known{1});
elseif numel(fields) == 1
    d = S.(fields{1});
else
    warning('Cannot tell which variable holds the data in %s (found: %s); skipping.', ...
        file, strjoin(fields', ', '));
    d = []; return;
end
if iscell(d), d = d{1}; end                   % some files store it wrapped
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
