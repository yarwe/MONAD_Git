function bands = fooof_resolve_bands(cfg)
% FOOOF_RESOLVE_BANDS  Return the bands struct (name -> [lo hi]) from a cfg,
% with backward compatibility for the old single cfg.alpha_band field.
if isfield(cfg,'bands') && ~isempty(cfg.bands) && isstruct(cfg.bands)
    bands = cfg.bands;
elseif isfield(cfg,'alpha_band') && ~isempty(cfg.alpha_band)
    bands = struct('alpha', cfg.alpha_band);
else
    bands = struct('alpha', [8 13]);
end
end
