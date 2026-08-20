function Gs = fooof_subset_group(G, keep)
% FOOOF_SUBSET_GROUP  Keep a subset of subjects from a fooof_group result.
%
% Returns a group struct identical in shape to the fooof_group output but
% containing only the subjects selected by `keep`, with the summary table
% rebuilt. Use it to drop outliers (e.g. poor fits or no alpha peak) before
% re-plotting / re-testing.
%
% INPUTS
%   G    - output of fooof_group
%   keep - logical (nSubj x 1) or index vector of subjects to KEEP
%
% See also: fooof_group, plot_fooof_group_comparison

if islogical(keep), keep = find(keep); end
keep = keep(:);

Gs = G;
Gs.fits       = G.fits(keep);
Gs.offset     = G.offset(keep);
Gs.exponent   = G.exponent(keep);
Gs.alpha_cf   = G.alpha_cf(keep);
Gs.alpha_pw   = G.alpha_pw(keep);
Gs.alpha_bw   = G.alpha_bw(keep);
Gs.r_squared  = G.r_squared(keep);
Gs.error      = G.error(keep);
Gs.has_alpha  = G.has_alpha(keep);
Gs.labels     = G.labels(keep);

Gs.table = table(Gs.labels, Gs.offset, Gs.exponent, Gs.alpha_cf, Gs.alpha_pw, ...
                 Gs.alpha_bw, Gs.r_squared, Gs.error, Gs.has_alpha, ...
    'VariableNames', {'ID','offset','exponent','alpha_CF','alpha_PW', ...
                      'alpha_BW','R2','MAE','has_alpha'});
end
