function plot_ica_components(comp, cfg_layout, n_comps, subject_id)
    % Plot ICA component topographies and time series

    if nargin < 4
        n_comps = 10; % Plot first 10 components
    end

    n_comps = min(n_comps, length(comp.label));

    % Topography
    figure('Position', [100 100 1400 900]);
    for ic = 1:n_comps
        subplot(3, 4, ic);
        cfg = [];
        cfg.component = ic;
        cfg.layout = cfg_layout;
        cfg.comment = 'no';
        ft_topoplotIC(cfg, comp);
        title(sprintf('IC %d', ic));
    end
    sgtitle(sprintf('ICA Component Topographies - Subject %s', subject_id));

    % Time series of components
    figure('Position', [100 100 1200 600]);
    time_segment = [1, min(10000, size(comp.trial{1}, 2))]; % First 10 sec or available data
    for ic = 1:min(4, n_comps) % Show first 4 components
        subplot(4, 1, ic);
        plot(comp.time{1}(time_segment(1):time_segment(2)), ...
            comp.trial{1}(ic, time_segment(1):time_segment(2)), 'b', 'LineWidth', 0.8);
        ylabel(sprintf('IC %d', ic));
        grid on;
    end
    xlabel('Time (s)');
    sgtitle(sprintf('ICA Component Time Series - Subject %s', subject_id));

end