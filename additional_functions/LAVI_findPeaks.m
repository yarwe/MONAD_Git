function [strct] = LAVI_findPeaks(cfg,data)
% find the peaks outside the noise range.
% outputs the peaks
env = cfg.env;
labels = env.lay.label;
% find the closest noise electrode for each channel
% Example list of selected electrodes
selected_electrodes = data.noise.labels; % replace with your 11 electrodes
selected_idx = find(ismember(labels, selected_electrodes));

% Initialize an array to store the closest selected electrode for each electrode
closest_electrodes = cell(64, 1);

% Loop through each electrode in the layout
for i = 1:64
    % Get the position of the current electrode
    current_pos = env.lay.pos(i, :);
    
    % Compute the Euclidean distances from the current electrode to all the selected electrodes
    distances = sqrt(sum((env.lay.pos(selected_idx, :) - current_pos).^2, 2));
    
    % Find the closest selected electrode by getting the minimum distance
    [~, closest_idx] = min(distances);
    
    % Store the label of the closest selected electrode
    closest_electrodes{i} = env.lay.label{selected_idx(closest_idx)};
end

% for each channel, find the peaks which are outside the noise range.
for e=1:length(data.label)
    noiseIdx = find(strcmp(data.noise.labels, closest_electrodes{e}));
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