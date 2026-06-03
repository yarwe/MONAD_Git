function plot_automatic_artifacts(data_with_artifacts, artifact_samples, subject_id, segments_to_plot, fontSize)
    % Highlights automatic (Z-score) detected artifacts
    % Input: data_with_artifacts (FieldTrip structure), artifact_samples (Nx2 array),
    %        subject_id (string)
    %        segments_to_plot (optional): Can be a scalar max number (e.g., 5) 
    %                                     or an explicit array (e.g., [2, 4, 6]).
    %                                     Defaults to 1:5.
    %        fontSize (optional, default=12)
    %
    % Usage: plot_automatic_artifacts(EEG_data, artifact_samples, '011201', [2 4 6], 14)
    
    % Set default fontSize if not provided
    if nargin < 5
        fontSize = 12;
    end
    
    % Set default segments to plot if not provided
    if nargin < 4 || isempty(segments_to_plot)
        segments_to_plot = 5; 
    end
    
    if isempty(artifact_samples)
        disp('No automatic artifacts detected.');
        return;
    end
    
    % If a single number is passed (e.g., 5), convert it to a range (1:5)
    if isscalar(segments_to_plot)
        segments_to_plot = 1:min(segments_to_plot, size(artifact_samples, 1));
    else
        % Safeguard: Ensure requested segment indices exist in the matrix
        segments_to_plot = segments_to_plot(segments_to_plot <= size(artifact_samples, 1));
    end
    
    n_subplots = length(segments_to_plot);
    figure('Position', [100 100 1200 800]);
    
    for idx = 1:n_subplots
        seg = segments_to_plot(idx); % Get the specific segment index
        
        artifact_start = artifact_samples(seg, 1);
        artifact_end = artifact_samples(seg, 2);
        
        % Show ±500ms around artifact
        buffer = 0.5 * data_with_artifacts.fsample;
        window_start = max(1, artifact_start - buffer);
        window_end = min(size(data_with_artifacts.trial{1}, 2), artifact_end + buffer);
        
        % Create the subplot based on the total number of requested plots
        subplot(n_subplots, 1, idx);
        time_axis = data_with_artifacts.time{1}(window_start:window_end);
        
        % Plot all channels (capped at 10)
        for ch = 1:min(10, length(data_with_artifacts.label))
            plot(time_axis, data_with_artifacts.trial{1}(ch, window_start:window_end), ...
                'LineWidth', 0.5); hold on;
        end
        
        % Lock current y-limits explicitly so the patch doesn't stretch them vertically
        yLim = ylim;
        ylim(yLim);
        
        % Highlight artifact region using transparent red ('r' works fine in MATLAB)
        artifact_time = data_with_artifacts.time{1}(artifact_start:artifact_end);
        
        patch([artifact_time(1), artifact_time(end), artifact_time(end), artifact_time(1)], ...
            [yLim(1), yLim(1), yLim(2), yLim(2)], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        
        ylabel(sprintf('Segment %d', seg), 'FontSize', fontSize);
        set(gca, 'FontSize', fontSize);
        grid on;
    end
    
    xlabel('Time (s)', 'FontSize', fontSize);
    sgtitle(sprintf('Automatic Artifact Detection (Z-score) - Subject %s', subject_id), 'FontSize', fontSize);
end