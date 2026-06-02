function plot_frontal_channels_ica(raw_data, ica_data, subject_id, time_window)
    % Plot FP1 and FP2 channels before and after ICA

    if nargin < 4
        time_window = [1, min(30000, size(raw_data.trial{1}, 2))]; % First 30 sec
    end

    fp1_idx = find(strcmp(raw_data.label, 'FP1'));
    fp2_idx = find(strcmp(raw_data.label, 'FP2'));

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
    ylabel('FP1 (µV)');
    title(sprintf('FP1 & FP2 Before and After ICA - Subject %s', subject_id));
    grid on;

    % FP2 before ICA
    subplot(4, 1, 2);
    plot(time_axis, raw_data.trial{1}(fp2_idx, time_window(1):time_window(2)), 'k', 'LineWidth', 0.5);
    ylabel('FP2 (µV)');
    grid on;

    % FP1 after ICA
    subplot(4, 1, 3);
    plot(time_axis, ica_data.trial{1}(fp1_idx, time_window(1):time_window(2)), 'g', 'LineWidth', 0.5);
    ylabel('FP1 (µV)');
    grid on;

    % FP2 after ICA
    subplot(4, 1, 4);
    plot(time_axis, ica_data.trial{1}(fp2_idx, time_window(1):time_window(2)), 'g', 'LineWidth', 0.5);
    ylabel('FP2 (µV)');
    xlabel('Time (s)');
    grid on;

end
