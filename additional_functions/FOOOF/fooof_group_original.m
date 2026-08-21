function G = fooof_group_original(freqs, specs, cfg)
% FOOOF_GROUP_ORIGINAL  Same as fooof_group, but fits with the ORIGINAL Python
% FOOOF (via the fooof_mat wrapper). Extracts aperiodic params and, per band,
% the dominant peak. Output struct matches fooof_group, so the same plot
% functions work unchanged.
%
% Requires: Python `fooof` installed, MATLAB configured to use it, and
% ./fooof_mat on the path (see run_fooof.m).
%
% See also: fooof_group, fooof_pick_peak, fooof.m (wrapper)

if nargin < 3 || isempty(cfg), cfg = struct(); end
if ~isfield(cfg,'group_name'), cfg.group_name = ''; end
if ~isfield(cfg,'labels'),     cfg.labels = {};     end
if ~isfield(cfg,'aperiodic_mode') || isempty(cfg.aperiodic_mode), cfg.aperiodic_mode='fixed'; end
if ~isfield(cfg,'freq_range')     || isempty(cfg.freq_range),     cfg.freq_range=[2 40];      end
bands  = fooof_resolve_bands(cfg);
bnames = fieldnames(bands);

% Settings passed to the wrapper (empty fields -> library defaults).
settings = struct();
if isfield(cfg,'peak_width_limits'), settings.peak_width_limits = cfg.peak_width_limits; end
if isfield(cfg,'max_n_peaks'),       settings.max_n_peaks       = cfg.max_n_peaks;       end
if isfield(cfg,'min_peak_height'),   settings.min_peak_height   = cfg.min_peak_height;   end
if isfield(cfg,'peak_threshold'),    settings.peak_threshold    = cfg.peak_threshold;    end
settings.aperiodic_mode = cfg.aperiodic_mode; settings.verbose = false;

freqs = freqs(:); nSubj = size(specs,2);
offset=nan(nSubj,1); exponent=nan(nSubj,1); r2=nan(nSubj,1); err=nan(nSubj,1);
for b = 1:numel(bnames)
    peaks.(bnames{b}) = struct('cf',nan(nSubj,1),'pw',nan(nSubj,1), ...
                               'bw',nan(nSubj,1),'present',false(nSubj,1));
end
fits = struct([]);

for s = 1:nSubj
    fr = fooof(freqs', specs(:,s)', cfg.freq_range, settings, true);   % Python fit
    r = struct();
    r.freqs=fr.freqs(:); r.log_spectrum=fr.power_spectrum(:);
    r.fooofed_spectrum=fr.fooofed_spectrum(:); r.ap_fit=fr.ap_fit(:);
    r.peak_params=fr.peak_params;
    r.offset=fr.aperiodic_params(1); r.exponent=fr.aperiodic_params(end);
    if strcmpi(cfg.aperiodic_mode,'knee'), r.knee=fr.aperiodic_params(2); else, r.knee=NaN; end
    ss_res=sum((r.log_spectrum-r.fooofed_spectrum).^2);
    ss_tot=sum((r.log_spectrum-mean(r.log_spectrum)).^2);
    r.r_squared=1-ss_res/ss_tot;                 % true R^2 (wrapper reports Pearson r)
    r.error=fr.error;
    fits(s).r=r; %#ok<AGROW>
    offset(s)=r.offset; exponent(s)=r.exponent; r2(s)=r.r_squared; err(s)=r.error;
    for b = 1:numel(bnames)
        [cf,pw,bw,pr] = fooof_pick_peak(r.peak_params, bands.(bnames{b}));
        peaks.(bnames{b}).cf(s)=cf; peaks.(bnames{b}).pw(s)=pw;
        peaks.(bnames{b}).bw(s)=bw; peaks.(bnames{b}).present(s)=pr;
    end
end

G.offset=offset; G.exponent=exponent; G.r_squared=r2; G.error=err;
G.peaks=peaks; G.band_names=bnames; G.band_ranges=bands;
G.fits=fits; G.group_name=cfg.group_name;
if isfield(cfg,'color') && ~isempty(cfg.color), G.color=cfg.color(:)'; else, G.color=[]; end
G.cfg=cfg;
if isempty(cfg.labels)
    G.labels = arrayfun(@(k) sprintf('S%02d',k),(1:nSubj)','UniformOutput',false);
else
    G.labels = cfg.labels(:);
end
G.table = table(G.labels, offset, exponent, r2, err, ...
    'VariableNames', {'ID','offset','exponent','R2','MAE'});

gname = cfg.group_name; if isempty(gname), gname='group'; end
fprintf('FOOOF(original) %s: %d subj, mean R^2=%.3f. Bands: %s.\n', ...
    gname, nSubj, mean(r2,'omitnan'), strjoin(bnames',', '));
end
