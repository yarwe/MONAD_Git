function plot_manual_artifacts(data_before_removal, artifact_samples, subject_id, segments_to_plot, fontSize)
    % Highlights manually detected artifacts
    % Input: data_before_removal (FieldTrip structure), artifact_samples (Nx2 array),
    %        subject_id (string)
    %        segments_to_plot (optional): Can be a scalar max number (e.g., 5) 
    %                                     or an explicit array (e.g., [1, 5, 7]).
    %                                     Defaults to 1:5.
    %        fontSize (optional, default=12)
    %
    % Usage: plot_manual_artifacts(EEG_data, artifact_samples, '011201', [1 5 7], 14)
    
    % Set default fontSize if not provided
    if nargin < 5
        fontSize = 12;
    end
    
    % Set default segments to plot if not provided
    if nargin < 4 || isempty(segments_to_plot)
        segments_to_plot = 5; 
    end
    
    if isempty(artifact_samples)
        disp('No manual artifacts detected.');
        return;
    end
    
    % If a single number is passed (e.g., 5), convert it to a range (1:5)
    if isscalar(segments_to_plot)
        segments_to_plot = 1:min(segments_to_plot, size(artifact_samples, 1));
    else
        % Ensure we don't request indices out of bounds of the actual matrix
        segments_to_plot = segments_to_plot(segments_to_plot <= size(artifact_samples, 1));
    end
    
    n_subplots = length(segments_to_plot);
    figure('Position', [100 100 1200 800]);
    
    for idx = 1:n_subplots
        seg = segments_to_plot(idx); % Get the specific segment index
        
        artifact_start = artifact_samples(seg, 1);
        artifact_end = artifact_samples(seg, 2);
        
        % Show ±1 second around artifact
        buffer = 1.0 * data_before_removal.fsample;
        window_start = max(1, artifact_start - buffer);
        window_end = min(size(data_before_removal.trial{1}, 2), artifact_end + buffer);
        
        % Create the subplot matching the total number of subplots requested
        subplot(n_subplots, 1, idx);
        time_axis = data_before_removal.time{1}(window_start:window_end);
        
        % Plot all channels
        for ch = 1:min(15, length(data_before_removal.label))
            plot(time_axis, data_before_removal.trial{1}(ch, window_start:window_end), ...
                'LineWidth', 0.5); hold on;
        end
        
        % Hold limits explicitly to prevent the patch from expanding the y-axis
        yLim = ylim;
        ylim(yLim);
        
        % Highlight artifact region using RGB for orange
        artifact_time = data_before_removal.time{1}(artifact_start:artifact_end);
        orange_rgb = [1, 0.5, 0];
        
        patch([artifact_time(1), artifact_time(end), artifact_time(end), artifact_time(1)], ...
            [yLim(1), yLim(1), yLim(2), yLim(2)], orange_rgb, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
        
        ylabel(sprintf('Segment %d', seg), 'FontSize', fontSize);
        set(gca, 'FontSize', fontSize);
        grid on;
    end
    
    xlabel('Time (s)', 'FontSize', fontSize);
    sgtitle(sprintf('Manual Artifact Detection - Subject %s', subject_id), 'FontSize', fontSize);
end