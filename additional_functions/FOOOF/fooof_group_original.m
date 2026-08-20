function G = fooof_group_original(freqs, specs, cfg)
% FOOOF_GROUP_ORIGINAL  Same as fooof_group, but fits with the ORIGINAL Python
% FOOOF (via the fooof_mat wrapper) instead of the native fooof_fit.m.
%
% Requires: Python with the `fooof` package installed, MATLAB configured to use
% it (see run_fooof_analysis_original.m), and ./fooof_mat on the path.
%
% Produces a group struct with the SAME fields as fooof_group, so all the
% existing plot functions (plot_fooof_group_fits / _comparison) work unchanged.
%
% cfg fields used:
%   .freq_range, .aperiodic_mode                    (fit range / mode)
%   .peak_width_limits, .max_n_peaks, .min_peak_height, .peak_threshold
%   .alpha_band, .labels, .group_name, .color
%
% See also: fooof_group, fooof.m (wrapper)

if nargin < 3 || isempty(cfg), cfg = struct(); end
if ~isfield(cfg,'alpha_band') || isempty(cfg.alpha_band), cfg.alpha_band = [7 14]; end
if ~isfield(cfg,'group_name'), cfg.group_name = ''; end
if ~isfield(cfg,'labels'),     cfg.labels = {};      end
if ~isfield(cfg,'aperiodic_mode') || isempty(cfg.aperiodic_mode), cfg.aperiodic_mode = 'fixed'; end
if ~isfield(cfg,'freq_range') || isempty(cfg.freq_range), cfg.freq_range = [2 40]; end

% Build the settings struct passed to the wrapper. Empty fields -> the library
% defaults are filled in by fooof_check_settings (peak_width_limits=[0.5 12],
% max_n_peaks=Inf, min_peak_height=0, peak_threshold=2, aperiodic_mode='fixed').
settings = struct();
if isfield(cfg,'peak_width_limits'), settings.peak_width_limits = cfg.peak_width_limits; end
if isfield(cfg,'max_n_peaks'),       settings.max_n_peaks       = cfg.max_n_peaks;       end
if isfield(cfg,'min_peak_height'),   settings.min_peak_height   = cfg.min_peak_height;   end
if isfield(cfg,'peak_threshold'),    settings.peak_threshold    = cfg.peak_threshold;    end
settings.aperiodic_mode = cfg.aperiodic_mode;
settings.verbose = false;

freqs = freqs(:); nSubj = size(specs,2);
offset=nan(nSubj,1); exponent=nan(nSubj,1);
alpha_cf=nan(nSubj,1); alpha_pw=nan(nSubj,1); alpha_bw=nan(nSubj,1);
r2=nan(nSubj,1); err=nan(nSubj,1); has_alpha=false(nSubj,1);
fits = struct([]);

for s = 1:nSubj
    fr = fooof(freqs', specs(:,s)', cfg.freq_range, settings, true);   % Python fit

    % Repack into the same r-struct shape the plot functions expect.
    r = struct();
    r.freqs            = fr.freqs(:);
    r.log_spectrum     = fr.power_spectrum(:);     % log10 power (wrapper units)
    r.fooofed_spectrum = fr.fooofed_spectrum(:);   % log10 power
    r.ap_fit           = fr.ap_fit(:);             % log10 power
    r.peak_params      = fr.peak_params;           % [CF PW BW]
    r.offset           = fr.aperiodic_params(1);
    r.exponent         = fr.aperiodic_params(end);
    if strcmpi(cfg.aperiodic_mode,'knee'), r.knee = fr.aperiodic_params(2); else, r.knee = NaN; end
    % Recompute a TRUE R^2 (the wrapper reports a Pearson r), so it matches the
    % native pipeline's definition and the exclusion threshold is comparable.
    ss_res = sum((r.log_spectrum - r.fooofed_spectrum).^2);
    ss_tot = sum((r.log_spectrum - mean(r.log_spectrum)).^2);
    r.r_squared = 1 - ss_res/ss_tot;
    r.error     = fr.error;
    fits(s).r = r; %#ok<AGROW>

    offset(s)=r.offset; exponent(s)=r.exponent; r2(s)=r.r_squared; err(s)=r.error;

    pk = r.peak_params;
    if ~isempty(pk)
        in = pk(:,1) >= cfg.alpha_band(1) & pk(:,1) <= cfg.alpha_band(2);
        if any(in)
            cand = pk(in,:); [~,k] = max(cand(:,2));
            alpha_cf(s)=cand(k,1); alpha_pw(s)=cand(k,2); alpha_bw(s)=cand(k,3);
            has_alpha(s)=true;
        end
    end
end

G.fits=fits; G.offset=offset; G.exponent=exponent;
G.alpha_cf=alpha_cf; G.alpha_pw=alpha_pw; G.alpha_bw=alpha_bw;
G.r_squared=r2; G.error=err; G.has_alpha=has_alpha;
G.alpha_band=cfg.alpha_band; G.group_name=cfg.group_name;
if isfield(cfg,'color') && ~isempty(cfg.color), G.color=cfg.color(:)'; else, G.color=[]; end
G.cfg=cfg;

if isempty(cfg.labels)
    G.labels = arrayfun(@(k) sprintf('S%02d',k), (1:nSubj)', 'UniformOutput', false);
else
    G.labels = cfg.labels(:);
end
G.table = table(G.labels, offset, exponent, alpha_cf, alpha_pw, alpha_bw, r2, err, has_alpha, ...
    'VariableNames', {'ID','offset','exponent','alpha_CF','alpha_PW','alpha_BW','R2','MAE','has_alpha'});

gname = cfg.group_name; if isempty(gname), gname='group'; end
fprintf('FOOOF(original) %s: %d subj, %d with alpha (%.0f%%). Mean R^2=%.3f.\n', ...
    gname, nSubj, nnz(has_alpha), 100*nnz(has_alpha)/nSubj, mean(r2,'omitnan'));
end
