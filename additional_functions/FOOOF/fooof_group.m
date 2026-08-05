function G = fooof_group(freqs, specs, cfg)
% FOOOF_GROUP  Fit FOOOF to every subject in a group and extract key parameters.
%
% Runs fooof_fit on each subject's power spectrum, then pulls out, per subject:
%   - the aperiodic parameters (offset, exponent)
%   - the periodic parameters of the dominant ALPHA peak
%     (center frequency, aperiodic-adjusted power, bandwidth)
%   - overall fit quality (R^2, MAE)
%
% INPUTS
%   freqs - frequency vector (Hz), shared by all subjects (nFreq x 1).
%   specs - LINEAR power spectra, nFreq x nSubj  (one column per subject),
%           e.g. built by stacking psd_nan() / pwelch() outputs.
%   cfg   - (optional) struct. All fooof_fit settings are accepted and passed
%           through (see fooof_fit). Additional group-level fields:
%     .alpha_band  [7 14]   frequency window used to pick the alpha peak (Hz)
%     .labels      {}       optional cellstr of subject IDs (nSubj)
%     .group_name  ''       optional name for printouts / plots
%
% OUTPUT (struct G)
%   .fits          1 x nSubj struct array, each element a full fooof_fit result
%   .offset        nSubj x 1
%   .exponent      nSubj x 1
%   .alpha_cf      nSubj x 1   alpha center frequency (NaN if no alpha peak)
%   .alpha_pw      nSubj x 1   alpha aperiodic-adjusted power
%   .alpha_bw      nSubj x 1   alpha bandwidth (2*SD)
%   .r_squared     nSubj x 1
%   .error         nSubj x 1
%   .has_alpha     nSubj x 1 logical
%   .labels, .group_name, .alpha_band, .cfg
%   .table         summary MATLAB table (one row per subject)
%
% See also: fooof_fit, plot_fooof_group_fits, plot_fooof_group_comparison

if nargin < 3 || isempty(cfg), cfg = struct(); end
if ~isfield(cfg,'alpha_band')  || isempty(cfg.alpha_band),  cfg.alpha_band  = [7 14]; end
if ~isfield(cfg,'group_name'),                              cfg.group_name  = '';     end
if ~isfield(cfg,'labels'),                                  cfg.labels      = {};     end

freqs = freqs(:);
nSubj = size(specs, 2);
if size(specs,1) ~= numel(freqs)
    error('fooof_group:size','specs must be nFreq x nSubj (nFreq=%d).', numel(freqs));
end

offset = nan(nSubj,1); exponent = nan(nSubj,1);
alpha_cf = nan(nSubj,1); alpha_pw = nan(nSubj,1); alpha_bw = nan(nSubj,1);
r2 = nan(nSubj,1); err = nan(nSubj,1); has_alpha = false(nSubj,1);
fits = struct([]);

for s = 1:nSubj
    r = fooof_fit(freqs, specs(:,s), cfg);
    fits(s).r = r; %#ok<AGROW>

    offset(s)   = r.offset;
    exponent(s) = r.exponent;
    r2(s)       = r.r_squared;
    err(s)      = r.error;

    % Dominant alpha peak = highest-power peak whose CF is inside alpha_band
    pk = r.peak_params;                      % [CF PW BW]
    if ~isempty(pk)
        in = pk(:,1) >= cfg.alpha_band(1) & pk(:,1) <= cfg.alpha_band(2);
        if any(in)
            cand = pk(in, :);
            [~, k] = max(cand(:,2));         % pick by power
            alpha_cf(s) = cand(k,1);
            alpha_pw(s) = cand(k,2);
            alpha_bw(s) = cand(k,3);
            has_alpha(s) = true;
        end
    end
end

% Pack the struct array as .fits (each element .r for convenience)
G.fits       = fits;
G.offset     = offset;
G.exponent   = exponent;
G.alpha_cf   = alpha_cf;
G.alpha_pw   = alpha_pw;
G.alpha_bw   = alpha_bw;
G.r_squared  = r2;
G.error      = err;
G.has_alpha  = has_alpha;
G.alpha_band = cfg.alpha_band;
G.group_name = cfg.group_name;
G.cfg        = cfg;

% Subject labels
if isempty(cfg.labels)
    G.labels = arrayfun(@(k) sprintf('S%02d', k), (1:nSubj)', 'UniformOutput', false);
else
    G.labels = cfg.labels(:);
end

% Summary table
G.table = table(G.labels, offset, exponent, alpha_cf, alpha_pw, alpha_bw, ...
                r2, err, has_alpha, ...
    'VariableNames', {'ID','offset','exponent','alpha_CF','alpha_PW', ...
                      'alpha_BW','R2','MAE','has_alpha'});

% Console summary
gname = cfg.group_name; if isempty(gname), gname = 'group'; end
fprintf('\nFOOOF %s: %d subjects, %d with an alpha peak (%.0f%%). Mean R^2 = %.3f.\n', ...
    gname, nSubj, nnz(has_alpha), 100*nnz(has_alpha)/nSubj, mean(r2,'omitnan'));
end
