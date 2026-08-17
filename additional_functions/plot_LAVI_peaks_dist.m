function plot_LAVI_peaks_dist(cfg, borders_all_subj, groups, LAVI_arr)
% PLOT_LAVI_PEAKS_DIST  Plot distribution of detected LAVI peaks by group
%
% Visualizes detected peak frequencies within a specified frequency range
% for each group using histogram, density, or other methods.
%
% INPUT
%   cfg.freq_range         : [lo hi] frequency range, e.g. [8 13] for alpha
%   cfg.ch_idx             : channel index, e.g. 34 for 'Cz' from env.lay.label
%   borders_all_subj       : subject × channels cell array from LAVI_findBorders
%                            Each borders_all_subj{id, ch} contains an N_bands × 11 matrix
%   LAVI_arr               : cell array of LAVI data (rows of borders_all_subj correspond to LAVI_arr indices)
%   cfg.plot_groups        : (optional) cell array of group names. Default: all groups
%   cfg.method             : 'histogram' or 'density' (default: 'histogram')
%   cfg.density_method     : 'kde'|'violin'|'ecdf'|'rug'|'strip' (default: 'kde')
%   cfg.show_individual_subjects : true|false for histogram (default: false)
%   cfg.colors             : struct with .groupname RGB values (default: auto)
%   cfg.nbins              : number of bins for histogram (default: auto)
%   cfg.marker_size        : marker size for density plots (default: 30)
%   cfg.newfig             : open new figure (default: true)
%   cfg.exclude_subjects   : (optional) subject IDs to exclude
%
% USAGE
%   % Multi-channel data (specify which channel)
%   cfg = [];
%   cfg.freq_range = [8 13];
%   cfg.ch_idx = 34;                   % Channel index for Cz
%   cfg.method = 'density';
%   cfg.density_method = 'ecdf';
%   plot_LAVI_peaks_dist(cfg, borders_all_subj, groups, LAVI_arr);
%
%   % Pre-averaged single channel data (no ch_idx needed, no LAVI_arr needed)
%   cfg = [];
%   cfg.freq_range = [8 13];
%   cfg.method = 'density';
%   cfg.density_method = 'ecdf';
%   plot_LAVI_peaks_dist(cfg, borders_all_subj_central, groups);



% Defaults
if ~isfield(cfg, 'freq_range') || isempty(cfg.freq_range)
    error('cfg.freq_range is required, e.g. [8 13] for alpha');
end
if ~isfield(cfg, 'ch_idx') || isempty(cfg.ch_idx)
    error('cfg.ch_idx is required, e.g. 34 for Cz from env.lay.label');
end
ch_str = LAVI_arr{1}.label{cfg.ch_idx};
if ~isfield(cfg, 'plot_groups') || isempty(cfg.plot_groups)
    cfg.plot_groups = {groups.name};
end
if ~isfield(cfg, 'method') || isempty(cfg.method)
    cfg.method = 'histogram';
end
if ~isfield(cfg, 'density_method') || isempty(cfg.density_method)
    cfg.density_method = 'kde';
end
if ~isfield(cfg, 'show_individual_subjects') || isempty(cfg.show_individual_subjects)
    cfg.show_individual_subjects = false;
end
if ~isfield(cfg, 'nbins') || isempty(cfg.nbins)
    cfg.nbins = [];
end
if ~isfield(cfg, 'marker_size') || isempty(cfg.marker_size)
    cfg.marker_size = 30;
end
if ~isfield(cfg, 'newfig') || isempty(cfg.newfig)
    cfg.newfig = true;
end
if ~isfield(cfg, 'exclude_subjects') || isempty(cfg.exclude_subjects)
    cfg.exclude_subjects = [];
end

% Detect if single-channel (N×1) or multi-channel data
n_cols = size(borders_all_subj, 2);
is_single_channel = (n_cols == 1);

% Handle parameter requirements based on data type
if is_single_channel
    % Single-channel: ch_idx and LAVI_arr not needed
    LAVI_arr = [];
else
    % Multi-channel: both cfg.ch_idx and LAVI_arr required
    if ~isfield(cfg, 'ch_idx') || isempty(cfg.ch_idx)
        error('For multi-channel data, cfg.ch_idx is required');
    end

    if nargin < 4
        error('For multi-channel data, LAVI_arr is required as 4th parameter');
    end

    % Build mapping from subject ID to LAVI_arr index
    subj_to_lavi_idx = containers.Map();
    for lavi_idx = 1:numel(LAVI_arr)
        subj_id = LAVI_arr{lavi_idx}.ID;
        subj_to_lavi_idx(char(subj_id)) = lavi_idx;
    end
end

freq_lo = cfg.freq_range(1);
freq_hi = cfg.freq_range(2);

% New figure
if cfg.newfig
    figure('Position', [100, 100, 1000, 600]);
end
hold on;

% Collect peaks for each group
group_peaks = {};
group_names = {};
group_colors = [];
group_ns = [];

for g = 1:numel(cfg.plot_groups)
    g_idx = find(strcmp({groups.name}, cfg.plot_groups{g}));
    if isempty(g_idx)
        continue;
    end

    peaks_in_range = [];
    n_subjects = 0;
    n_excluded = 0;

    % Collect peaks from all subjects in this group
    for i = 1:numel(groups(g_idx).data_lavi)
        subj_id = groups(g_idx).data_lavi{i}.ID;

        % Check if excluded
        if ~isempty(cfg.exclude_subjects)
            exclude_list = cfg.exclude_subjects;
            if isnumeric(exclude_list)
                exclude_list = cellfun(@num2str, num2cell(exclude_list), 'UniformOutput', false);
            elseif ischar(exclude_list)
                exclude_list = {exclude_list};
            elseif iscell(exclude_list)
                exclude_list = cellfun(@(x) iif(isnumeric(x), num2str(x), x), exclude_list, 'UniformOutput', false);
            end
            subj_id_str = char(string(subj_id));
            if any(strcmp(subj_id_str, exclude_list))
                n_excluded = n_excluded + 1;
                continue;
            end
        end

        % Determine which row of borders_all_subj to use
        if is_single_channel
            row_idx = i;  % For pre-averaged, use group index directly
        else
            % For multi-channel, find LAVI_arr index
            subj_id_str = char(string(subj_id));
            if ~isKey(subj_to_lavi_idx, subj_id_str)
                continue;
            end
            row_idx = subj_to_lavi_idx(subj_id_str);
        end

        % Extract peaks from borders_all_subj
        if ~is_single_channel && cfg.ch_idx > size(borders_all_subj, 2)
            continue;
        end

        ch_to_use = iif(is_single_channel, 1, cfg.ch_idx);
        borders_matrix = borders_all_subj{row_idx, ch_to_use};

        % Skip if empty or invalid structure
        if isempty(borders_matrix)
            continue;
        end

        % Ensure it's 2D (sometimes ABBA returns 1D for averaged data)
        if ~ismatrix(borders_matrix) || size(borders_matrix, 2) < 11
            continue;
        end

        % Extract significant peaks only (direction=1, significance=true) in freq_range
        subj_freqs = [];
        subj_vals = [];
        for b = 1:size(borders_matrix, 1)
            is_significant = borders_matrix(b, 11);  % Column 11: significance
            direction = borders_matrix(b, 9);         % Column 9: 1=peak, -1=trough
            freq = borders_matrix(b, 6);              % Column 6: frequency
            lavi_val = borders_matrix(b, 7);          % Column 7: LAVI value

            if is_significant && direction == 1 && freq >= freq_lo && freq <= freq_hi
                subj_freqs = [subj_freqs; freq];
                subj_vals = [subj_vals; lavi_val];
            end
        end

        if ~isempty(subj_freqs)
            % Get the peak with maximal LAVI value
            [~, max_idx] = max(subj_vals);
            dominant_peak = subj_freqs(max_idx);
            peaks_in_range = [peaks_in_range; dominant_peak];
            n_subjects = n_subjects + 1;
        end
    end

    group_peaks{g} = peaks_in_range;
    group_names{g} = groups(g_idx).name;
    group_colors = [group_colors; groups(g_idx).color];
    group_ns(g) = n_subjects;
end

% Plot based on method
switch cfg.method
    case 'histogram'
        plot_histogram(group_peaks, group_names, group_colors, group_ns, cfg);
    case 'density'
        switch cfg.density_method
            case 'kde'
                plot_kde(group_peaks, group_names, group_colors, group_ns, cfg);
            case 'violin'
                plot_violin(group_peaks, group_names, group_colors, group_ns, cfg);
            case 'ecdf'
                plot_ecdf(group_peaks, group_names, group_colors, group_ns, cfg);
            case 'rug'
                plot_rug(group_peaks, group_names, group_colors, group_ns, cfg);
            case 'strip'
                plot_strip(group_peaks, group_names, group_colors, group_ns, cfg);
            otherwise
                error('Unknown density method: %s', cfg.density_method);
        end
end

% Labels and formatting
xlabel('Frequency (Hz)');
ylabel(iif(strcmp(cfg.method, 'histogram'), 'Count', 'Density'));
title({sprintf('Channel %s LAVI Peak Distribution', ch_str), ...
    sprintf('Range: %.1f-%.1f Hz', cfg.freq_range(1), cfg.freq_range(2))}, 'FontSize', 12);

% Legend
leg_entries = {};
for g = 1:numel(group_names)
    leg_entries{g} = sprintf('%s (N=%d)', group_names{g}, group_ns(g));
end
legend(leg_entries, 'Location', 'best');

hold off;
end

% ======================================================================= %
function plot_histogram(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot overlayed histograms
hold on;

% Determine bins
if isempty(cfg.nbins)
    all_peaks = [];
    for g = 1:numel(group_peaks)
        all_peaks = [all_peaks; group_peaks{g}];
    end
    cfg.nbins = max(3, round(numel(all_peaks) / 5));
end

% Auto-normalize if group sizes differ significantly
max_n = max(group_ns);
normalize_to_prob = max_n / min(group_ns(group_ns>0)) > 1.5;

for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    if normalize_to_prob
        [N, edges] = histcounts(group_peaks{g}, cfg.nbins, 'Normalization', 'probability');
    else
        [N, edges] = histcounts(group_peaks{g}, cfg.nbins);
    end

    centers = (edges(1:end-1) + edges(2:end)) / 2;
    bar(centers, N, 'FaceColor', group_colors(g, :), 'FaceAlpha', 0.6, ...
        'EdgeColor', group_colors(g, :) * 0.7, 'LineWidth', 1.5, 'DisplayName', group_names{g});

    % Individual subjects as dots
    if cfg.show_individual_subjects
        scatter(group_peaks{g}, ones(size(group_peaks{g})) * max(N) * 0.05, ...
            50, group_colors(g, :), 'filled', 'HandleVisibility', 'off');
    end
end

end

% ======================================================================= %
function plot_kde(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot overlayed KDE density curves
hold on;

% Get x range
all_peaks = [];
for g = 1:numel(group_peaks)
    all_peaks = [all_peaks; group_peaks{g}];
end
x_range = linspace(min(all_peaks) - 1, max(all_peaks) + 1, 200);

for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    % Compute KDE
    [f, xi] = ksdensity(group_peaks{g}, x_range);

    plot(xi, f, 'LineWidth', 2.5, 'Color', group_colors(g, :), 'DisplayName', group_names{g});
    fill(xi, f, group_colors(g, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

end

% ======================================================================= %
function plot_violin(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot overlayed violin plots
hold on;

% Prepare data for violin plot
all_data = [];
all_groups_idx = [];
for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end
    all_data = [all_data; group_peaks{g}];
    all_groups_idx = [all_groups_idx; repmat(g, numel(group_peaks{g}), 1)];
end

% Create violin plot
positions = 1:numel(group_peaks);
for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    % Compute KDE for violin
    [f, xi] = ksdensity(group_peaks{g});
    f = f / max(f) * 0.4;  % Normalize width

    % Draw violin
    x_pos = g;
    fill([x_pos - f, x_pos + fliplr(f)], [xi, fliplr(xi)], ...
        group_colors(g, :), 'FaceAlpha', 0.6, 'EdgeColor', group_colors(g, :) * 0.7, ...
        'LineWidth', 2, 'HandleVisibility', 'off');

    % Add median line
    med = median(group_peaks{g});
    plot([x_pos - 0.2, x_pos + 0.2], [med, med], 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
end

set(gca, 'XTick', 1:numel(group_peaks));
set(gca, 'XTickLabel', group_names);
ylabel('Frequency (Hz)');
xlabel('Group');
end

% ======================================================================= %
function plot_ecdf(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot overlayed ECDF curves (no smoothing)
hold on;

for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    % Sort data
    sorted_peaks = sort(group_peaks{g});
    y_vals = (1:numel(sorted_peaks)) / numel(sorted_peaks);

    plot(sorted_peaks, y_vals, 'LineWidth', 2.5, 'Color', group_colors(g, :), ...
        'Marker', 'o', 'MarkerSize', 6, 'MarkerFaceColor', group_colors(g, :), ...
        'DisplayName', group_names{g});
end

ylabel('Cumulative Probability');
ylim([0 1]);
end

% ======================================================================= %
function plot_rug(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot rug plot (subjects as dots on horizontal line)
hold on;

for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    y_pos = g * ones(size(group_peaks{g}));
    scatter(group_peaks{g}, y_pos, cfg.marker_size, group_colors(g, :), 'filled', ...
        'DisplayName', group_names{g});
end

set(gca, 'YTick', 1:numel(group_peaks));
set(gca, 'YTickLabel', group_names);
ylabel('Group');
end

% ======================================================================= %
function plot_strip(group_peaks, group_names, group_colors, group_ns, cfg)
% Plot strip plot (scatter with jitter)
hold on;

for g = 1:numel(group_peaks)
    if isempty(group_peaks{g})
        continue;
    end

    % Add random jitter to y-position
    jitter = randn(size(group_peaks{g})) * 0.04;
    y_pos = g + jitter;
    scatter(group_peaks{g}, y_pos, cfg.marker_size, group_colors(g, :), 'filled', ...
        'DisplayName', group_names{g});
end

set(gca, 'YTick', 1:numel(group_peaks));
set(gca, 'YTickLabel', group_names);
ylabel('Group');
end

% ======================================================================= %
function result = iif(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
