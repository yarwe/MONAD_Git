function plot_power_spectrum_comparison(raw_data, ica_data, subject_id, ...
    stage_str, channel_name, fontSize)
    % Plot power spectrum (Welch's method) for a channel before/after ICA
    % Input: raw_data, ica_data (FieldTrip structures), subject_id (string),
    %        channel_name (optional, default='Cz'), fontSize (optional, default=12)
    %
    % Usage: plot_power_spectrum_comparison(EEG_raw, EEG_clean, '011201', 'Cz', 14)

    % Set default fontSize if not provided
    if nargin < 6
        fontSize = 12;
    end

    if nargin < 5
        channel_name = 'Cz'; % default channel
    end

    chan_idx = find(strcmp(raw_data.label, channel_name));
    if isempty(chan_idx)
        chan_idx = 1;
        channel_name = raw_data.label{1};
    end

    fs = raw_data.fsample;

    % Extract data and remove NaN values for pwelch
    raw_signal = raw_data.trial{1}(chan_idx, :);
    raw_signal(~isfinite(raw_signal)) = 0; % Replace NaN/Inf with 0

    ica_signal = ica_data.trial{1}(chan_idx, :);
    ica_signal(~isfinite(ica_signal)) = 0; % Replace NaN/Inf with 0

    % Welch's power spectral density estimate
    [pxx_raw, f_raw] = pwelch(raw_signal, 2*fs, [], [], fs);
    [pxx_ica, f_ica] = pwelch(ica_signal, 2*fs, [], [], fs);

    figure('Position', [100 100 1000 500]);

    % Linear scale
    subplot(1, 2, 1);
    plot(f_raw, pxx_raw, 'k', 'LineWidth', 1.5); hold on;
    plot(f_ica, pxx_ica, 'r', 'LineWidth', 1.5);
    xlim([0.5, 300]);
    xlabel('Frequency (Hz)', 'FontSize', fontSize);
    ylabel('Power (µV²/Hz)', 'FontSize', fontSize);
    title(sprintf('Power Spectrum - %s - Subject %s', channel_name, subject_id), 'FontSize', fontSize);
    legend(sprintf('Before %s',stage_str), sprintf('After %s',stage_str),...
        'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

    % Log-log scale
    subplot(1, 2, 2);
    loglog(f_raw, pxx_raw, 'k', 'LineWidth', 1.5); hold on;
    loglog(f_ica, pxx_ica, 'r', 'LineWidth', 1.5);
    xlim([0.5, 300]);
    xlabel('Frequency (Hz)', 'FontSize', fontSize);
    ylabel('Power (µV²/Hz)', 'FontSize', fontSize);
    title(sprintf('Power Spectrum (log-log) - %s - Subject %s', channel_name, subject_id), 'FontSize', fontSize);
    legend(sprintf('Before %s',stage_str), sprintf('After %s',stage_str), 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

end
