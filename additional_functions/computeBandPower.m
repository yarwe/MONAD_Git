function [bandPow] = computeBandPower(cfg, groups)
% COMPUTEBANDPOWER  Absolute and relative EEG band power per participant, per group.
%
% Implements the power definitions used in the 2023 review "Resting-state EEG
% power differences in autism spectrum disorder: a systematic review and
% meta-analysis":
%   absolute power = integral of the power spectrum within a frequency band.
%   relative power = band absolute power / total absolute power summed across
%                    all bands (so a participant's relative powers sum to 1).
%
% Bands (Hz), following the same paper:
%   delta (<4), theta (4-8), alpha (8-13), beta (13-30), gamma (>30)
%
% INPUTS
%   cfg.chosen_ch         : cellstr of channel labels to average over (region of interest).
%   cfg.bands             : (optional) struct array with fields:
%                             .name  - band name (char)
%                             .lo    - lower edge (Hz, inclusive except delta)
%                             .hi    - upper edge (Hz)
%                           Default is the 5 bands above.
%   cfg.fmax              : (optional) upper frequency bound for the open gamma band and
%                           for restricting the spectrum. Default = max(data.freq).
%   cfg.compute_peak_freq : (optional) logical, default false. If true, compute peak
%                           frequency (frequency with max power) for each band/subject.
%   cfg.overrideBandName  : (optional) override a single band by name (e.g., 'alpha').
%                           Requires cfg.overrideBandLo and cfg.overrideBandHi.
%   cfg.overrideBandIndex : (optional) override a single band by index (e.g., 3 for alpha).
%                           Requires cfg.overrideBandLo and cfg.overrideBandHi.
%   cfg.overrideBandLo    : (optional) new lower boundary (Hz) for overridden band.
%   cfg.overrideBandHi    : (optional) new upper boundary (Hz) for overridden band.
%
%   groups                : struct array with fields:
%                             .name     - group name (char)
%                             .data_fft - cell array of FieldTrip freq structs, each with
%                                         .powspctrm (chan x freq), .freq, .label, .ID
%                           Pass a single element to compute for one group only.
%
% OUTPUT
%   bandPow : struct array parallel to `groups`, each element with fields:
%     .name        group name
%     .bandNames   {1 x nBands} band names
%     .bandEdges   nBands x 2  [lo hi] used
%     .abs         nSubj x nBands  absolute power per participant/band
%     .rel         nSubj x nBands  relative power (fraction) per participant/band
%     .peakFreq    nSubj x nBands  peak frequency per participant/band (if cfg.compute_peak_freq=true)
%     .IDs         {1 x nSubj} participant IDs
%     .chan        channels actually found and averaged
%
% Examples:
%   % Compute with default bands
%   cfg = []; cfg.chosen_ch = chosen_ch;
%   bandPow = computeBandPower(cfg, groups);
%
%   % Override alpha band by name
%   cfg.overrideBandName = 'alpha';
%   cfg.overrideBandLo = 7;    % Change from 8 to 7 Hz
%   cfg.overrideBandHi = 14;   % Change from 13 to 14 Hz
%   bandPow = computeBandPower(cfg, groups);
%
%   % Override alpha band by index (3 = alpha)
%   cfg = []; cfg.chosen_ch = chosen_ch;
%   cfg.overrideBandIndex = 3;
%   cfg.overrideBandLo = 8.5;
%   cfg.overrideBandHi = 12.5;
%   bandPow = computeBandPower(cfg, groups);

% ---- Defaults ----
if ~isfield(cfg, 'chosen_ch') || isempty(cfg.chosen_ch)
    error('computeBandPower:noChannels', 'cfg.chosen_ch (ROI channels) is required.');
end
chosen_ch = cfg.chosen_ch;

% [ADDED] New config option for peak frequency computation
if ~isfield(cfg, 'compute_peak_freq') || isempty(cfg.compute_peak_freq)
    cfg.compute_peak_freq = false;
end
compute_peak_freq = cfg.compute_peak_freq;

if ~isfield(cfg, 'bands') || isempty(cfg.bands)
    % .lo inclusive, .hi exclusive (see band assignment below); the last band
    % is open-ended and clamped to fmax.
    bands = struct( ...
        'name', {'delta', 'theta', 'alpha', 'beta', 'gamma'}, ...
        'lo',   {1,        4,       8,       13,     30}, ...
        'hi',   {4,        8,       13,      30,     Inf});
else
    bands = cfg.bands;
end
nBands = numel(bands);

% [ADDED] Allow overriding a single band's boundaries without providing all bands
if isfield(cfg, 'overrideBandName') && ~isempty(cfg.overrideBandName)
    % Override by band name (e.g., 'alpha')
    bandIdx = find(strcmp({bands.name}, cfg.overrideBandName));
    if isempty(bandIdx)
        error('Band "%s" not found. Available bands: %s', cfg.overrideBandName, strjoin({bands.name}, ', '));
    end
    if ~isfield(cfg, 'overrideBandLo') || ~isfield(cfg, 'overrideBandHi')
        error('Must provide cfg.overrideBandLo and cfg.overrideBandHi to override band "%s"', cfg.overrideBandName);
    end
    bands(bandIdx).lo = cfg.overrideBandLo;
    bands(bandIdx).hi = cfg.overrideBandHi;
    fprintf('Overriding band "%s": [%.1f %.1f] Hz\n', cfg.overrideBandName, cfg.overrideBandLo, cfg.overrideBandHi);

elseif isfield(cfg, 'overrideBandIndex') && ~isempty(cfg.overrideBandIndex)
    % Override by band index (e.g., 3 for alpha)
    bandIdx = cfg.overrideBandIndex;
    if bandIdx < 1 || bandIdx > nBands
        error('Band index %d out of range [1 %d]', bandIdx, nBands);
    end
    if ~isfield(cfg, 'overrideBandLo') || ~isfield(cfg, 'overrideBandHi')
        error('Must provide cfg.overrideBandLo and cfg.overrideBandHi to override band %d', bandIdx);
    end
    bands(bandIdx).lo = cfg.overrideBandLo;
    bands(bandIdx).hi = cfg.overrideBandHi;
    fprintf('Overriding band %d ("%s"): [%.1f %.1f] Hz\n', bandIdx, bands(bandIdx).name, cfg.overrideBandLo, cfg.overrideBandHi);
end

% ---- Loop over groups ----
% [MODIFIED] Added 'peakFreq' field to struct
if compute_peak_freq
    bandPow = struct('name', {}, 'bandNames', {}, 'bandEdges', {}, ...
                     'abs', {}, 'rel', {}, 'peakFreq', {}, 'IDs', {}, 'chan', {});
else
    bandPow = struct('name', {}, 'bandNames', {}, 'bandEdges', {}, ...
                     'abs', {}, 'rel', {}, 'IDs', {}, 'chan', {});
end

for g = 1:numel(groups)
    data_fft = groups(g).data_fft;
    nSubj    = numel(data_fft);

    absPow = nan(nSubj, nBands);
    relPow = nan(nSubj, nBands);
    % [ADDED] Initialize peakFreq array if computing peak frequencies
    if compute_peak_freq
        peakFreq = nan(nSubj, nBands);
    end
    % [MODIFIED] Initialize totalPow to compute relative power correctly
    totalPow = nan(nSubj, 1);
    IDs    = cell(1, nSubj);
    chanUsed = {};

    for s = 1:nSubj
        d = data_fft{s};
        f = d.freq(:)';                      % frequency vector (row)

        % upper bound for this participant
        if isfield(cfg, 'fmax') && ~isempty(cfg.fmax)
            fmax = cfg.fmax;
        else
            fmax = max(f);
        end

        % --- select ROI channels and average across them ---
        [tf, chIdx] = ismember(chosen_ch, d.label);
        chIdx = chIdx(tf);
        if isempty(chIdx)
            warning('computeBandPower:noROI', ...
                'None of the requested channels found for subject %d; skipping.', s);
            continue
        end
        if s == 1
            chanUsed = d.label(chIdx);
        end
        P = nanmean(d.powspctrm(chIdx, :), 1);   % 1 x nFreq averaged power

        % --- integrate power within each band ---
        for b = 1:nBands
            lo = bands(b).lo;
            hi = min(bands(b).hi, fmax);
            if b < nBands
                mask = f >= lo & f < hi;         % lower inclusive, upper exclusive
            else
                mask = f > lo & f <= hi;         % gamma: strictly > lo, up to fmax
            end

            % if nnz(mask) >= 2
            %     absPow(s, b) = trapz(f(mask), P(mask));
            % elseif nnz(mask) == 1
            %     absPow(s, b) = 0;                % single bin: no width to integrate

            if nnz(mask)>=1
                absPow(s,b)=nansum(P(mask));
                % [ADDED] Compute peak frequency if requested
                if compute_peak_freq
                    [~, idx_max] = max(P(mask));
                    % Get frequency of maximum power in this band
                    f_band = f(mask);
                    peakFreq(s, b) = f_band(idx_max);
                end
            else
                    absPow(s, b) = NaN;
                    % [ADDED] Peak frequency is NaN if no valid band data
                    if compute_peak_freq
                        peakFreq(s, b) = NaN;
                    end
            end
        end

        % [MODIFIED] Compute relative power: band / total across ALL frequencies (not just defined bands)
        % This is the correct definition: relative power = band absolute power / integral of entire spectrum
        totalPow(s) = nansum(P);  % Sum power across ALL frequencies in the spectrum
        if totalPow(s) > 0
            relPow(s, :) = absPow(s, :) / totalPow(s);
        end

        % --- ID ---
        if isfield(d, 'ID')
            id = d.ID;
            if iscell(id); id = id{1}; end
            IDs{s} = char(string(id));
        else
            IDs{s} = sprintf('subj%d', s);
        end
    end

    bandPow(g).name      = groups(g).name;
    bandPow(g).bandNames = {bands.name};
    bandPow(g).bandEdges = [ [bands.lo]' , [bands.hi]' ];
    bandPow(g).abs       = absPow;
    bandPow(g).rel       = relPow;
    % [ADDED] Add peakFreq to output if computed
    if compute_peak_freq
        bandPow(g).peakFreq = peakFreq;
    end
    bandPow(g).IDs       = IDs;
    bandPow(g).chan      = chanUsed;
end
end
