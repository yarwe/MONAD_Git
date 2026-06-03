function plot_frontal_channels_ica(raw_data, ica_data, subject_id, time_window, fontSize)
    % Plot FP1 and FP2 channels before and after ICA
    % Input: raw_data, ica_data (FieldTrip structures), subject_id (string),
    %        time_window (optional, default=first 30 sec), fontSize (optional, default=12)
    %
    % Usage: plot_frontal_channels_ica(EEG_raw, EEG_clean, '011201', [], 14)

    % Set default fontSize if not provided
    if nargin < 5
        fontSize = 12;
    end

    if nargin < 4
        time_window = [1, min(30000, size(raw_data.trial{1}, 2))]; % First 30 sec
    end

    fp1_idx = find(strcmp(raw_data.label, 'Fp1'));
    fp2_idx = find(strcmp(raw_data.label, 'Fp2'));

    if isempty(fp1_idx) || isempty(fp2_idx)
        disp('Warning: FP1 or FP2 not found. Using first two channels instead.');
        fp1_idx = 1;
        fp2_idx = 2;
    end

    time_axis = raw_data.time{1}(time_window(1):time_window(2));

    figure('Position', [100 100 1200 700]);

    % FP1 before ICA
    subplot(4, 1, 1);
    plot(time_axis, raw_data.trial{1}(fp1_idx, time_window(1):time_window(2)), 'k', 'LineWidth', 0.5);
    ylabel('FP1 (µV)', 'FontSize', fontSize);
    title(sprintf('FP1 & FP2 Before and After ICA - Subject %s', subject_id), 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

    % FP2 before ICA
    subplot(4, 1, 2);
    plot(time_axis, raw_data.trial{1}(fp2_idx, time_window(1):time_window(2)), 'k', 'LineWidth', 0.5);
    ylabel('FP2 (µV)', 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

    % FP1 after ICA
    subplot(4, 1, 3);
    plot(time_axis, ica_data.trial{1}(fp1_idx, time_window(1):time_window(2)), 'g', 'LineWidth', 0.5);
    ylabel('FP1 (µV)', 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

    % FP2 after ICA
    subplot(4, 1, 4);
    plot(time_axis, ica_data.trial{1}(fp2_idx, time_window(1):time_window(2)), 'g', 'LineWidth', 0.5);
    ylabel('FP2 (µV)', 'FontSize', fontSize);
    xlabel('Time (s)', 'FontSize', fontSize);
    set(gca, 'FontSize', fontSize);
    grid on;

end
