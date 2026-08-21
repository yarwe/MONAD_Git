function Gs = fooof_subset_group(G, keep)
% FOOOF_SUBSET_GROUP  Keep a subset of subjects from a fooof_group result.
% Returns a group struct identical in shape but containing only the subjects
% in `keep` (logical nSubj x 1 or index vector), with per-band peaks and the
% summary table rebuilt. Use it to drop outliers before re-plotting.
%
% See also: fooof_group, fooof_exclude

if islogical(keep), keep = find(keep); end
keep = keep(:);

Gs = G;
Gs.fits      = G.fits(keep);
Gs.offset    = G.offset(keep);
Gs.exponent  = G.exponent(keep);
Gs.r_squared = G.r_squared(keep);
Gs.error     = G.error(keep);
Gs.labels    = G.labels(keep);

% Per-band peaks
for b = 1:numel(G.band_names)
    bn = G.band_names{b};
    Gs.peaks.(bn).cf      = G.peaks.(bn).cf(keep);
    Gs.peaks.(bn).pw      = G.peaks.(bn).pw(keep);
    Gs.peaks.(bn).bw      = G.peaks.(bn).bw(keep);
    Gs.peaks.(bn).present = G.peaks.(bn).present(keep);
end

Gs.table = table(Gs.labels, Gs.offset, Gs.exponent, Gs.r_squared, Gs.error, ...
    'VariableNames', {'ID','offset','exponent','R2','MAE'});
end
