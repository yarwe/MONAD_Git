function [keep, info] = fooof_exclude(G, cfg)
% FOOOF_EXCLUDE  Decide which subjects to keep, based on fit quality.
%
% Configurable via cfg (all optional):
%   .exclusion       'sd' (DEFAULT) | 'r2' | 'none'
%   .exclusion_nsd   SD multiplier for 'sd' mode          (default 2.5)
%   .exclusion_logic 'or' (default) | 'and'  -- how to combine R^2 & error flags
%   .r2_thresh       absolute R^2 cutoff for 'r2' mode    (default 0.90)
%
% Modes:
%   'sd'   Paper's rule (Donoghue et al. 2020): drop a subject whose fit R^2 is
%          more than nsd SD BELOW the group-mean R^2, and/or whose fit error is
%          more than nsd SD ABOVE the group-mean error (the paper used 2.5 SD).
%          Mean/SD are computed WITHIN the group passed in.
%   'r2'   Absolute threshold: drop if R^2 < r2_thresh.
%   'none' Keep everyone.
%
% A subject whose fit fully failed (non-finite R^2) is always excluded.
%
% OUTPUTS
%   keep  logical (nSubj x 1)
%   info  struct with the thresholds used and the excluded labels/indices.
%
% See also: fooof_group, fooof_subset_group

if nargin < 2, cfg = struct(); end
mode  = getdef(cfg,'exclusion','sd');
nsd   = getdef(cfg,'exclusion_nsd',2.5);
logic = getdef(cfg,'exclusion_logic','or');
r2t   = getdef(cfg,'r2_thresh',0.90);

r2 = G.r_squared(:); er = G.error(:); n = numel(r2);
info = struct('mode',mode);

switch lower(mode)
    case 'none'
        keep = true(n,1);
    case 'r2'
        keep = r2 >= r2t;
        info.r2_thresh = r2t;
    case 'sd'
        mR = mean(r2,'omitnan'); sR = std(r2,'omitnan');
        mE = mean(er,'omitnan'); sE = std(er,'omitnan');
        lowR2   = r2 < (mR - nsd*sR);       % R^2 far below the mean (bad fit)
        highErr = er > (mE + nsd*sE);       % error far above the mean (bad fit)
        if strcmpi(logic,'and'), bad = lowR2 & highErr; else, bad = lowR2 | highErr; end
        keep = ~bad;
        info.nsd=nsd; info.logic=logic;
        info.mean_r2=mR; info.sd_r2=sR; info.r2_cut = mR - nsd*sR;
        info.mean_err=mE; info.sd_err=sE; info.err_cut = mE + nsd*sE;
        info.lowR2=lowR2; info.highErr=highErr;
    otherwise
        error('fooof_exclude:mode','Unknown exclusion mode "%s".', mode);
end

keep = keep & isfinite(r2);                 % a totally failed fit is always out
info.keep = keep;
info.excluded_idx    = find(~keep);
info.excluded_labels = G.labels(~keep);
end

function v = getdef(s,f,d)
if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
