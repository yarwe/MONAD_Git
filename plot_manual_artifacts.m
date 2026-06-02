function plot_manual_artifacts(data_before_removal, artifact_samples, subject_id, max_segments)
    % Highlights manually detected artifacts

    if nargin < 4
        max_segments = 5;
    end

    if isempty(artifact_samples)
        disp('No manual artifacts detected.');
        return;
    end

    n_segments = min(max_segments, size(artifact_samples, 1));

    figure('Position', [100 100 1200 800]);

    for seg = 1:n_segments
        artifact_start = artifact_samples(seg, 1);
        artifact_end = artifact_samples(seg, 2);

        % Show ±1 second around artifact
        buffer = 1.0 * data_before_removal.fsample;
        window_start = max(1, artifact_start - buffer);
        window_end = min(size(data_before_removal.trial{1}, 2), artifact_end + buffer);

        subplot(n_segments, 1, seg);

        time_axis = data_before_removal.time{1}(window_start:window_end);

        % Plot all channels
        for ch = 1:min(15, length(data_before_removal.label))
            plot(time_axis, data_before_removal.trial{1}(ch, window_start:window_end), ...
                'LineWidth', 0.5); hold on;
        end

        % Highlight artifact region
        artifact_time = data_before_removal.time{1}(artifact_start:artifact_end);
        yLim = ylim;
        patch([artifact_time(1), artifact_time(end), artifact_time(end), artifact_time(1)], ...
            [yLim(1), yLim(1), yLim(2), yLim(2)], 'orange', 'FaceAlpha', 0.25, 'EdgeColor', 'none');

        ylabel(sprintf('Segment %d', seg));
        grid on;
    end

    xlabel('Time (s)');
    sgtitle(sprintf('Manual Artifact Detection - Subject %s', subject_id));

end