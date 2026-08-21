function G = fooof_group(freqs, specs, cfg)
% FOOOF_GROUP  Fit FOOOF to every subject and extract per-band + aperiodic params.
%
% Runs fooof_fit on each subject's spectrum, then per subject pulls out the
% aperiodic parameters (offset, exponent) and, for EACH requested band, the
% dominant peak (center frequency, aperiodic-adjusted power, bandwidth).
%
% INPUTS
%   freqs - frequency vector (Hz), shared by all subjects (nFreq x 1).
%   specs - LINEAR power spectra, nFreq x nSubj (one column per subject).
%   cfg   - (optional) struct. All fooof_fit settings are passed through, plus:
%     .bands       struct of band name -> [lo hi], e.g.
%                  struct('theta',[4 8],'alpha',[8 13],'beta',[13 30]).
%                  (Back-compat: if absent, cfg.alpha_band is used; else [8 13].)
%     .labels, .group_name, .color   optional metadata carried on the output.
%
% OUTPUT (struct G)
%   .offset, .exponent, .r_squared, .error   nSubj x 1
%   .peaks.<band>.cf / .pw / .bw / .present  nSubj x 1 (per band)
%   .band_names, .band_ranges
%   .fits (1 x nSubj, each .r a full fooof_fit result), .labels, .group_name,
%   .color, .cfg, .table (console summary)
%
% See also: fooof_fit, fooof_pick_peak, plot_fooof_periodic, plot_fooof_aperiodic

if nargin < 3 || isempty(cfg), cfg = struct(); end
if ~isfield(cfg,'group_name'), cfg.group_name = ''; end
if ~isfield(cfg,'labels'),     cfg.labels = {};     end
bands  = fooof_resolve_bands(cfg);
bnames = fieldnames(bands);

freqs = freqs(:); nSubj = size(specs,2);
if size(specs,1) ~= numel(freqs)
    error('fooof_group:size','specs must be nFreq x nSubj (nFreq=%d).', numel(freqs));
end

offset = nan(nSubj,1); exponent = nan(nSubj,1);
r2 = nan(nSubj,1); err = nan(nSubj,1);
for b = 1:numel(bnames)
    peaks.(bnames{b}) = struct('cf',nan(nSubj,1),'pw',nan(nSubj,1), ...
                               'bw',nan(nSubj,1),'present',false(nSubj,1));
end
fits = struct([]);

for s = 1:nSubj
    r = fooof_fit(freqs, specs(:,s), cfg);
    fits(s).r = r; %#ok<AGROW>
    offset(s)=r.offset; exponent(s)=r.exponent; r2(s)=r.r_squared; err(s)=r.error;
    for b = 1:numel(bnames)
        [cf,pw,bw,pr] = fooof_pick_peak(r.peak_params, bands.(bnames{b}));
        peaks.(bnames{b}).cf(s)=cf; peaks.(bnames{b}).pw(s)=pw;
        peaks.(bnames{b}).bw(s)=bw; peaks.(bnames{b}).present(s)=pr;
    end
end

G.offset=offset; G.exponent=exponent; G.r_squared=r2; G.error=err;
G.peaks = peaks; G.band_names = bnames; G.band_ranges = bands;
G.fits = fits; G.group_name = cfg.group_name;
if isfield(cfg,'color') && ~isempty(cfg.color), G.color=cfg.color(:)'; else, G.color=[]; end
G.cfg = cfg;
if isempty(cfg.labels)
    G.labels = arrayfun(@(k) sprintf('S%02d',k),(1:nSubj)','UniformOutput',false);
else
    G.labels = cfg.labels(:);
end
G.table = table(G.labels, offset, exponent, r2, err, ...
    'VariableNames', {'ID','offset','exponent','R2','MAE'});

gname = cfg.group_name; if isempty(gname), gname='group'; end
fprintf('FOOOF %s: %d subjects, mean R^2 = %.3f. Bands: %s.\n', ...
    gname, nSubj, mean(r2,'omitnan'), strjoin(bnames',', '));
end
