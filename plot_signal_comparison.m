function plot_signal_comparison(raw_data, filtered_data, subject_id,Chan_lab, time_segment, fontSize)
    % Plots a segment of raw vs. filtered signal for a single channel
    % Input: raw_data, filtered_data (FieldTrip structures), subject_id (string),
    %        time_segment (samples), fontSize (optional, default=12)
    %
    % Usage: plot_signal_comparison(EEG_raw, EEG_clean, '011201', [], 14)

    % Set default fontSize if not provided
    if nargin < 6
        fontSize = 12;
    end

    if nargin < 5
        time_segment = [1, min(5000, size(raw_data.trial{1}, 2))]; % First 5000 samples or less
    end

    if nargin <4
        Chan_lab='Cz';
    end

    chan_idx = find(strcmp(raw_data.label, Chan_lab));
    if isempty(chan_idx)
        chan_idx = 1;
    end

    figure('Position', [100 100 1200 500]);

    % Raw signal
    subplot(2, 1, 1);
    time_axis = raw_data.time{1}(time_segment(1):time_segment(2));
    plot(time_axis, raw_data.trial{1}(chan_idx, time_segment(1):time_segment(2)), 'k', 'LineWidth', 0.5);
    title(sprintf('Raw EEG - Channel %s - Subject %s', raw_data.label{chan_idx}, subject_id), 'FontSize', fontSize);
    ylabel('Amplitude (µV)', 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

    % Filtered signal
    subplot(2, 1, 2);
    plot(time_axis, filtered_data.trial{1}(chan_idx, time_segment(1):time_segment(2)), 'b', 'LineWidth', 0.5);
    title(sprintf('After Preprocessing: Detrend, Bandpass Filter, Notch, Artefact Removal & ICA '), 'FontSize', fontSize);
    xlabel('Time (s)', 'FontSize', fontSize);
    ylabel('Amplitude (µV)', 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

end