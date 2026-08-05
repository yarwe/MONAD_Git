function [borders_all_subj, sigVect_all_subj] = findLAVIBorders(cfg, LAVI_arr, foi)
% FINDLAVIBORDERS  Detect spectral borders (peaks/troughs) in LAVI for multiple subjects
%
% Wrapper around ABBA that processes multiple subjects and channels,
% with options for channel averaging and noise-based signal limits.
%
% INPUTS
%   cfg : configuration struct with fields:
%     .channels           : (optional) channel labels to analyze, e.g. {'Cz', 'Pz'}
%                          Default: all channels
%     .average_channels   : (optional) boolean, average specified channels before detection
%                          Default: false (analyze each channel separately)
%     .use_noise_limits   : (optional) boolean, use simulated noise min/max as signal limits
%                          Default: true
%     .noise_channel      : (optional) which channel's noise to use for limits
%                          Default: 'Cz'
%     .freq_range         : (optional) [lo hi] frequency range for analysis
%                          Default: [1 90]
%     .verbose            : (optional) boolean, print progress. Default: false
%   LAVI_arr : cell array of LAVI structures, each with:
%              .powspctrm (nChans x nFreq)
%              .label (channel labels)
%              .noise.noise (cell array of simulated noise, one per channel)
%              .noise.labels (noise channel labels)
%   foi      : frequency vector (e.g., 1:0.5:90)
%
% OUTPUTS
%   borders_all_subj : N x nChans cell array
%                      Each element borders_all_subj{s, ch} contains:
%                      Npeaks x 11 matrix (output from ABBA)
%   sigVect_all_subj : N x nChans cell array of significance vectors (from ABBA)
%
% USAGE
%   % Analyze Cz channel only, with noise limits
%   cfg = [];
%   cfg.channels = {'Cz'};
%   cfg.use_noise_limits = true;
%   cfg.verbose = true;
%   [borders, sigVect] = findLAVIBorders(cfg, LAVI_arr, foi);
%
%   % Average multiple channels, then detect
%   cfg = [];
%   cfg.channels = {'Pz', 'POz', 'Oz'};
%   cfg.average_channels = true;
%   [borders, sigVect] = findLAVIBorders(cfg, LAVI_arr, foi);

% ---- Defaults ----
if ~isfield(cfg, 'average_channels') || isempty(cfg.average_channels)
    cfg.average_channels = false;
end
if ~isfield(cfg, 'use_noise_limits') || isempty(cfg.use_noise_limits)
    cfg.use_noise_limits = true;
end
if ~isfield(cfg, 'noise_channel') || isempty(cfg.noise_channel)
    cfg.noise_channel = 'Cz';
end
if ~isfield(cfg, 'freq_range') || isempty(cfg.freq_range)
    cfg.freq_range = [1 90];
end
if ~isfield(cfg, 'verbose') || isempty(cfg.verbose)
    cfg.verbose = false;
end

N_subj = numel(LAVI_arr);

% Get all unique channels if not specified
if ~isfield(cfg, 'channels') || isempty(cfg.channels)
    all_labels = LAVI_arr{1}.label;
    if iscell(all_labels)
        cfg.channels = all_labels;
    else
        cfg.channels = cellstr(all_labels);
    end
end

% Convert to cell array if single string
if ischar(cfg.channels)
    cfg.channels = {cfg.channels};
end

% If averaging, create pseudo-channel for averaged data
if cfg.average_channels
    n_output_ch = 1;
    output_ch_name = sprintf('%s_avg', strjoin(cfg.channels, '-'));
else
    n_output_ch = numel(cfg.channels);
    output_ch_name = cfg.channels;
end

% Initialize output arrays
borders_all_subj = cell(N_subj, n_output_ch);
sigVect_all_subj = cell(N_subj, n_output_ch);

% ---- Main loop over subjects ----
for s = 1:N_subj
    if cfg.verbose
        fprintf('Subject %d/%d: ', s, N_subj);
    end

    % Get subject data
    subj_data = LAVI_arr{s};

    if cfg.average_channels
        % ---- Average specified channels ----
        [~, ch_idx] = ismember(cfg.channels, subj_data.label);
        ch_idx = ch_idx(ch_idx > 0);  % Remove invalid indices

        if isempty(ch_idx)
            warning('Subject %d: None of requested channels found', s);
            continue;
        end

        % Average power across channels
        powspctrm_avg = nanmean(subj_data.powspctrm(ch_idx, :), 1);

        % Get signal limits from noise if requested
        if cfg.use_noise_limits
            noise_ch_idx = find(strcmpi(cfg.noise_channel, subj_data.noise.labels));
            if isempty(noise_ch_idx)
                warning('Subject %d: Noise channel "%s" not found', s, cfg.noise_channel);
                SIGLIM = [];
            else
                % Min/max across all 20 noise simulations
                noise_data = subj_data.noise.noise{noise_ch_idx};  % 20 x nFreq
                SIGLIM = squeeze(cat(3, min(noise_data, [], 1), max(noise_data, [], 1)));
            end
        else
            SIGLIM = [];
        end

        % Call ABBA
        [borders, ~, sigVect] = ABBA(powspctrm_avg, foi, cfg.freq_range, SIGLIM, 0);

        % ABBA returns a cell array; extract the first (and only) element for averaged data
        borders_all_subj{s, 1} = borders{1};
        sigVect_all_subj{s, 1} = sigVect{1};

        if cfg.verbose
            fprintf('Channels %s (avg): %d peaks detected\n', ...
                strjoin(cfg.channels, ', '), size(borders, 1));
        end

    else
        % ---- Analyze each channel separately ----
        % NOTE: ABBA processes all channels at once and returns results for each
        % So we pass full powspctrm and then extract the channels we want

        % Get signal limits from noise if requested
        if cfg.use_noise_limits
            noise_ch_idx = find(strcmpi(cfg.noise_channel, subj_data.noise.labels));
            if isempty(noise_ch_idx)
                SIGLIM = [];
            else
                noise_data = subj_data.noise.noise{noise_ch_idx};  % 20 x nFreq
                SIGLIM = squeeze(cat(3, min(noise_data, [], 1), max(noise_data, [], 1)));
            end
        else
            SIGLIM = [];
        end

        % Call ABBA with ALL channels (it processes each independently)
        [borders_all, ~, sigVect_all] = ABBA(subj_data.powspctrm, foi, cfg.freq_range, SIGLIM, 0);

        % Extract results for requested channels only
        for ch = 1:numel(cfg.channels)
            ch_label = cfg.channels{ch};
            ch_idx = find(strcmpi(ch_label, subj_data.label));

            if isempty(ch_idx)
                borders_all_subj{s, ch} = [];
                sigVect_all_subj{s, ch} = [];
            else
                % Extract this channel's results from ABBA output
                borders_all_subj{s, ch} = borders_all{ch_idx};
                sigVect_all_subj{s, ch} = sigVect_all{ch_idx};
            end
        end

        if cfg.verbose
            n_peaks_str = arrayfun(@(ch) sprintf('%d', size(borders_all_subj{s,ch},1)), ...
                1:numel(cfg.channels), 'UniformOutput', false);
            fprintf('Peaks: %s\n', strjoin(n_peaks_str, ', '));
        end
    end
end

if cfg.verbose
    fprintf('\nCompleted: %d subjects x %d channel(s)\n', N_subj, n_output_ch);
end

end
