function [strct] = LAVI_findPeaks(cfg,data)
% find the peaks outside the noise range.
% outputs the peaks
env = cfg.env;
labels = env.lay.label;
% find the closest noise electrode for each channel
% Example list of selected electrodes
selected_electrodes = data.noise.labels; % replace with your 11 electrodes
selected_idx = find(ismember(labels, selected_electrodes));

% Initialize an array to store the closest selected electrode for each data channel
nChan = numel(data.label);
closest_electrodes = cell(nChan, 1);

% Normalized layout labels (lowercase, trimmed) so trivial spelling/case
% differences like 'CZ'/'Cz', 'FP1'/'Fp1', or trailing spaces still match.
lay_norm = lower(strtrim(env.lay.label));

% Loop through each channel in the data (adaptive to montage size: 64, 70, ...)
for i = 1:nChan
    % Get the position of the current channel by matching its label in the layout
    layIdx = find(strcmp(lay_norm, lower(strtrim(data.label{i}))), 1);
    if isempty(layIdx)
        % Channel not present in the layout; leave unassigned
        closest_electrodes{i} = '';
        continue
    end
    current_pos = env.lay.pos(layIdx, :);

    % Compute the Euclidean distances from the current electrode to all the selected electrodes
    distances = sqrt(sum((env.lay.pos(selected_idx, :) - current_pos).^2, 2));

    % Find the closest selected electrode by getting the minimum distance
    [~, closest_idx] = min(distances);

    % Store the label of the closest selected electrode
    closest_electrodes{i} = env.lay.label{selected_idx(closest_idx)};
end

% Report channels that had no scalp position in the layout (these get
% skipped below). Helps catch a naming mismatch vs. genuine non-scalp channels.
% Warn only once per unique set of unmatched labels to avoid spamming when
% called in a loop over participants.
persistent warned_sets
if isempty(warned_sets); warned_sets = {}; end
unmatched = data.label(cellfun(@isempty, closest_electrodes));
if ~isempty(unmatched)
    key = strjoin(sort(unmatched(:)'), ',');
    if ~any(strcmp(warned_sets, key))
        warned_sets{end+1} = key;
        warning('LAVI_findPeaks:noLayoutPos', ...
            'No layout position for %d channel(s), skipping: %s', ...
            numel(unmatched), strjoin(unmatched, ', '));
    end
end

% for each channel, find the peaks which are outside the noise range.
for e=1:length(data.label)
    noiseIdx = find(strcmp(data.noise.labels, closest_electrodes{e}));

    % Skip channels with no matching noise reference (e.g. non-scalp
    % channels like EOG/mastoids that are absent from the layout, or an
    % all-NaN LAVI row). Leave their peak/trough entries empty.
    if isempty(noiseIdx) || all(isnan(data.powspctrm(e,:)))
        pksV{e}     = [];
        pksFreq{e}  = [];
        trghV{e}    = [];
        trghFreq{e} = [];
        noiseCh{e}  = closest_electrodes{e};
        continue
    end

    maxNoise = max(data.noise.noise{noiseIdx}, [], 1);  % Max across simulations per frequency
    minNoise = min(data.noise.noise{noiseIdx}, [], 1);  % Min across simulations per frequency
    signal = data.powspctrm(e,:);
    
    [peakVals, peakLocs] = findpeaks(signal);
    idx = find(peakVals > maxNoise(peakLocs));
    peakVals = peakVals(idx);
    peakLocs = peakLocs(idx);
    % Find troughs by finding peaks of the negative signal
    [troughVals, troughLocs] = findpeaks(-signal);
    troughVals = -troughVals;  % Convert negative values back to original
    idx = find(troughVals < minNoise(troughLocs));
    troughVals = troughVals(idx);
    troughLocs = troughLocs(idx);
    
    pksV{e} = peakVals;
    pksFreq{e} = cfg.foi(peakLocs);
    trghV{e} = troughVals;
    trghFreq{e} = cfg.foi(troughLocs);
    noiseCh{e} = closest_electrodes{e};


end
strct = [];
strct.minVals  = trghV;
strct.minFreqs = trghFreq;
strct.maxVals  = pksV;
strct.maxFreqs = pksFreq;
strct.noiseCh  = noiseCh;
strct.ID       = data.ID;
  
end