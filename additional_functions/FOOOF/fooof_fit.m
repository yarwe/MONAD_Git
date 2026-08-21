function res = fooof_fit(freqs, powspctrm, cfg)
% FOOOF_FIT  Parameterize one neural power spectrum into aperiodic + periodic parts.
%
% Native MATLAB re-implementation of the "fitting oscillations & one over f"
% (FOOOF / specparam) algorithm from:
%   Donoghue et al. (2020), "Parameterizing neural power spectra into periodic
%   and aperiodic components", Nature Neuroscience 23:1655-1665.
%
% The spectrum is modeled (in semilog space: linear frequency, log10 power) as
%       PSD(f) = L(f) + sum_n G_n(f)
% where L is the aperiodic component and each G_n is a Gaussian peak (eq. 1-3).
%   Aperiodic 'fixed':  L(f) = b - X*log10(f)                 params [offset exponent]
%   Aperiodic 'knee' :  L(f) = b - log10(k + f.^X)            params [offset knee exponent]
%   Gaussian         :  G(f) = a * exp( -(f-c).^2 / (2*w^2) )
%
% NO external toolboxes required: the nonlinear fits use fminsearch (base MATLAB).
%
% -------------------------------------------------------------------------
% INPUTS
%   freqs      - frequency vector (Hz), 1 x nFreq or nFreq x 1. Must be > 0.
%   powspctrm  - power at each frequency, LINEAR power (e.g. V^2/Hz from pwelch /
%                psd_nan). NOT dB, NOT already log-transformed. The function
%                log10-transforms internally, per the paper.
%   cfg        - (optional) struct of settings; any omitted field takes the
%                default listed below (defaults = paper's resting-state EEG
%                settings, Donoghue et al. 2020, Methods):
%     .freq_range        [2 40]     frequencies (Hz) to fit over
%     .aperiodic_mode    'fixed'    'fixed' (no knee) or 'knee'
%     .peak_width_limits [1 6]      min/max peak BANDWIDTH (=2*SD) in Hz
%     .max_n_peaks       6          max number of peaks to fit
%     .min_peak_height   0.05       min peak height over aperiodic (log10 power)
%     .peak_threshold    1.5        min height in units of SD of the flat spectrum
%     .verbose           false
%
% OUTPUT (struct res)
%   .aperiodic_params  [offset (knee) exponent]
%   .offset, .exponent, .knee   convenience scalars (knee = NaN in fixed mode)
%   .peak_params       nPk x 3 = [CenterFreq(Hz)  Power(a.u.)  Bandwidth(Hz)]
%                      (Power = aperiodic-adjusted peak height; Bandwidth = 2*SD)
%   .gaussian_params   nPk x 3 = [mean height SD]  (raw Gaussian params)
%   .r_squared         variance of the log-spectrum explained by the full model
%   .error             mean absolute error of the fit (log10 power units)
%   .freqs             fitted frequency vector (Hz)
%   .log_spectrum      log10 power that was fit
%   .ap_fit            aperiodic component, log10 power  (for plotting)
%   .peak_fit          summed Gaussians, log10 power     (for plotting)
%   .fooofed_spectrum  full model = ap_fit + peak_fit    (for plotting)
%   .cfg               the resolved settings actually used
%
% See also: fooof_group, plot_fooof_fit, psd_nan

% ----------------------------- defaults ----------------------------------
if nargin < 3 || isempty(cfg), cfg = struct(); end
def = struct('freq_range',[2 40], 'aperiodic_mode','fixed', ...
             'peak_width_limits',[1 6], 'max_n_peaks',6, ...
             'min_peak_height',0.05, 'peak_threshold',1.5, 'verbose',false);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(cfg, fn{i}) || isempty(cfg.(fn{i})), cfg.(fn{i}) = def.(fn{i}); end
end

% Gaussian SD limits derived from bandwidth (BW) limits, since BW = 2*SD.
std_lims = cfg.peak_width_limits / 2;

% Internal constants (paper / reference-implementation defaults)
AP_PERC_THRESH   = 2.5;   % percentile of flattened spectrum kept for robust ap fit
CF_BOUND         = 1.5;   % multi-Gaussian CF is bounded to +/- 2*CF_BOUND*SD of guess
BW_STD_EDGE      = 1.0;   % drop peaks whose center is within this many SD of the edge
GAUSS_OVERLAP    = 0.75;  % drop the smaller of two peaks closer than this many SD

% ----------------------------- prep data ---------------------------------
freqs = freqs(:); powspctrm = powspctrm(:);
sel   = freqs >= cfg.freq_range(1) & freqs <= cfg.freq_range(2) & freqs > 0 ...
        & isfinite(powspctrm) & powspctrm > 0;
f  = freqs(sel);
lp = log10(powspctrm(sel));            % semilog: linear freq, log10 power
if numel(f) < 5
    error('fooof_fit:tooFewPoints', ...
        'Only %d valid frequency points in range [%g %g] Hz.', numel(f), cfg.freq_range);
end
freq_res = median(diff(f));

% ------------------- step 1: robust aperiodic fit ------------------------
ap0       = simple_ap_fit(f, lp, cfg.aperiodic_mode);      % first pass on full spectrum
init_ap   = ap_model(f, ap0, cfg.aperiodic_mode);
flat      = lp - init_ap;
flat(flat < 0) = 0;                                        % clamp sub-fit residuals
thr       = prctile_local(flat, AP_PERC_THRESH);
mask      = flat <= thr;                                   % baseline (non-peak) points
if nnz(mask) < 3, mask = true(size(f)); end
ap_robust = simple_ap_fit(f(mask), lp(mask), cfg.aperiodic_mode, ap0);

% ------------------- step 2: iterative peak search -----------------------
ap_curve = ap_model(f, ap_robust, cfg.aperiodic_mode);
flat_spec = lp - ap_curve;                                 % aperiodic-adjusted spectrum
flat_iter = flat_spec;
guess = zeros(0,3);                                        % rows [center height sd]

% max_n_peaks may be Inf (library default); cap the loop at the number of
% frequency bins so "1:Inf" never triggers MATLAB's for-loop warning. The
% noise-floor break below is what actually stops the search in practice.
for p = 1:min(cfg.max_n_peaks, numel(f))
    [mx, idx] = max(flat_iter);
    if mx <= cfg.peak_threshold * std(flat_iter), break; end   % relative noise floor
    if mx <= cfg.min_peak_height,                 break; end   % absolute floor
    gc = f(idx); ga = mx;

    % Estimate SD from the FWHM, using the shorter half-width (robust to overlap)
    half = 0.5 * mx;
    li = find(flat_iter(1:idx) <= half, 1, 'last');
    ri = find(flat_iter(idx:end) <= half, 1, 'first'); if ~isempty(ri), ri = ri + idx - 1; end
    if isempty(li), left = idx - 1; else, left = idx - li; end
    if isempty(ri), right = numel(f) - idx; else, right = ri - idx; end
    short = max(min(left, right), 1);
    fwhm  = short * 2 * freq_res;
    gw    = fwhm / (2*sqrt(2*log(2)));
    gw    = min(max(gw, std_lims(1)), std_lims(2));            % clamp to SD limits

    guess = [guess; gc ga gw]; %#ok<AGROW>
    flat_iter = flat_iter - gaussian(f, ga, gc, gw);          % subtract & iterate
end

% ------------------- step 3: clean up peak guesses -----------------------
guess = drop_edge_peaks(guess, f(1), f(end), BW_STD_EDGE);
guess = drop_overlap_peaks(guess, GAUSS_OVERLAP);

% ------------------- step 4: multi-Gaussian refit ------------------------
if ~isempty(guess)
    gauss_params = fit_multi_gaussian(f, flat_spec, guess, std_lims, CF_BOUND);
    gauss_params = drop_edge_peaks(gauss_params, f(1), f(end), BW_STD_EDGE);
    gauss_params = drop_overlap_peaks(gauss_params, GAUSS_OVERLAP);
else
    gauss_params = zeros(0,3);
end

% ------------------- step 5: final aperiodic re-fit ----------------------
peak_curve = gaussians_sum(f, gauss_params);
spec_no_peaks = lp - peak_curve;
ap_final = simple_ap_fit(f, spec_no_peaks, cfg.aperiodic_mode, ap_robust);

% ------------------- assemble model & goodness of fit --------------------
ap_curve_final = ap_model(f, ap_final, cfg.aperiodic_mode);
model = ap_curve_final + peak_curve;

ss_res = sum((lp - model).^2);
ss_tot = sum((lp - mean(lp)).^2);
r2 = 1 - ss_res / ss_tot;                 % coefficient of determination
err = mean(abs(lp - model));              % MAE (paper's fit error metric)

% Transform Gaussian params -> reported peak params (CF, power, BW=2*SD),
% sorted by center frequency for readability.
if ~isempty(gauss_params)
    [~, ord] = sort(gauss_params(:,1));
    gauss_params = gauss_params(ord, :);
    peak_params = [gauss_params(:,1), gauss_params(:,2), 2*gauss_params(:,3)];
else
    peak_params = zeros(0,3);
end

% ----------------------------- pack output -------------------------------
res.aperiodic_params = ap_final;
res.offset   = ap_final(1);
res.exponent = ap_final(end);
if strcmpi(cfg.aperiodic_mode,'knee'), res.knee = ap_final(2); else, res.knee = NaN; end
res.peak_params      = peak_params;
res.gaussian_params  = gauss_params;
res.r_squared        = r2;
res.error            = err;
res.freqs            = f;
res.log_spectrum     = lp;
res.ap_fit           = ap_curve_final;
res.peak_fit         = peak_curve;
res.fooofed_spectrum = model;
res.cfg              = cfg;

if cfg.verbose
    fprintf(['fooof_fit: %d peak(s), R^2=%.3f, MAE=%.3f | offset=%.2f exp=%.2f\n'], ...
        size(peak_params,1), r2, err, res.offset, res.exponent);
end
end % ===================== end main function =============================


% ========================= local helper functions =======================
function y = ap_model(f, p, mode)
% Aperiodic component in log10 power.
if strcmpi(mode,'knee')
    y = p(1) - log10(p(2) + f.^p(3));     % [offset knee exponent]
else
    y = p(1) - p(2) * log10(f);           % [offset exponent]
end
end

function g = gaussian(f, a, c, w)
g = a * exp( -(f - c).^2 ./ (2 * w.^2) );
end

function s = gaussians_sum(f, gp)
s = zeros(size(f));
for i = 1:size(gp,1)
    s = s + gaussian(f, gp(i,2), gp(i,1), gp(i,3));
end
end

function p = simple_ap_fit(f, lp, mode, seed)
% Unconstrained aperiodic fit via fminsearch (SSE objective).
if nargin < 4 || isempty(seed)
    off0 = lp(1);
    slope = (lp(end) - lp(1)) / (log10(f(end)) - log10(f(1)));
    exp0 = max(-slope, 0.1);              % exponent = -slope (log-log), keep positive
    if strcmpi(mode,'knee'), seed = [off0 0 exp0]; else, seed = [off0 exp0]; end
end
opts = optimset('MaxFunEvals',5000,'MaxIter',5000,'Display','off');
p = fminsearch(@(q) sum((lp - ap_model(f, q, mode)).^2), seed, opts);
end

function gp = fit_multi_gaussian(f, flat, guess, std_lims, cf_bound)
% Joint refit of all Gaussians to the flattened spectrum, with soft bounds
% (each peak stays close to its seed), minimizing squared error.
n  = size(guess,1);
lo = zeros(n,3); hi = zeros(n,3);
for i = 1:n
    lo(i,:) = [guess(i,1) - 2*cf_bound*guess(i,3), 0,      std_lims(1)];
    hi(i,:) = [guess(i,1) + 2*cf_bound*guess(i,3), inf,    std_lims(2)];
end
seed = reshape(guess', 1, []);            % [c1 a1 w1 c2 a2 w2 ...]
lov  = reshape(lo',    1, []);
hiv  = reshape(hi',    1, []);
opts = optimset('MaxFunEvals',10000,'MaxIter',10000,'Display','off');
best = fminsearch(@obj, seed, opts);
gp   = reshape(min(max(best, lov), hiv)', 3, [])';   % clamp final into bounds

    function sse = obj(q)
        qc  = min(max(q, lov), hiv);      % clamp for model evaluation
        penalty = sum(max(0, lov - q).^2 + max(0, q - hiv).^2);  % push back to bounds
        gpp = reshape(qc, 3, [])';
        model = gaussians_sum(f, gpp);
        sse = sum((flat - model).^2) + 1e3 * penalty;
    end
end

function gp = drop_edge_peaks(gp, fmin, fmax, edge_std)
% Remove peaks whose center is within edge_std standard deviations of an edge.
if isempty(gp), return; end
keep = (gp(:,1) - edge_std*gp(:,3) > fmin) & (gp(:,1) + edge_std*gp(:,3) < fmax);
gp = gp(keep, :);
end

function gp = drop_overlap_peaks(gp, overlap_std)
% If two peak centers are within overlap_std * mean(SD), drop the lower one.
if size(gp,1) < 2, return; end
[~, ord] = sort(gp(:,1)); gp = gp(ord, :);
drop = false(size(gp,1),1);
for i = 1:size(gp,1)-1
    sep = gp(i+1,1) - gp(i,1);
    bnd = overlap_std * mean(gp([i i+1],3));
    if sep < bnd
        if gp(i,2) < gp(i+1,2), drop(i) = true; else, drop(i+1) = true; end
    end
end
gp = gp(~drop, :);
end

function v = prctile_local(x, p)
% Percentile without the Statistics Toolbox (linear interpolation on sorted data).
x = sort(x(:));
n = numel(x);
if n == 1, v = x; return; end
idx = (p/100) * (n - 1) + 1;             % 1-based fractional index
lo = floor(idx); hi = ceil(idx);
if lo == hi, v = x(lo); else, v = x(lo) + (idx - lo) * (x(hi) - x(lo)); end
end
