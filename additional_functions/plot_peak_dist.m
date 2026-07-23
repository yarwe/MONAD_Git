function plot_peak_dist(cfg, bandPow)
% PLOT_PEAK_DIST  Plot distributions of peak frequencies, absolute, or relative power
%
% Visualizes distributions of EEG band power metrics across groups (or single group) using various methods.
%
% INPUTS
%   cfg.type                   : (required) 'peak_freq', 'absolute_power', or 'relative_power'
%   cfg.band                   : (required) Band name or index (e.g., 'alpha' or 3)
%   cfg.method                 : (optional, default 'histogram') 'histogram' or 'density'
%   cfg.density_method         : (optional, default 'kde') When method='density': 'kde', 'violin', 'ecdf', 'rug', 'strip'
%   cfg.show_individual_subjects: (optional, default false) When method='histogram': add individual subjects as dots
%   cfg.nbins                  : (optional, default 15) Number of bins for histogram
%   cfg.alpha                  : (optional, default 0.5) Transparency for overlayed plots
%   cfg.linewidth              : (optional, default 2) Line width for curves
%   cfg.marker_size            : (optional, default 30) Marker size for strip/rug plots
%   cfg.group_idx              : (optional) Plot only specific group(s): scalar or vector of indices
%   cfg.exclude_subjects       : (optional) Subject IDs to exclude (numbers, strings, or cell array)
%   cfg.subject_ids            : (optional) Subject ID field to match (default: .IDs from bandPow)
%   cfg.colors                 : (optional) nGroups x 3 RGB color matrix.
%                                Default: ASD=[0.4 0.67 0.8], NT=[0.61 0.81 0.58], others=lines(nGroups)
%
%   bandPow             : Output from computeBandPower, can contain 1 or more groups
%
% OUTPUTS
%   fig : Figure handle
%
% EXAMPLES
%   % Histogram with peak frequencies
%   cfg = []; cfg.type = 'peak_freq'; cfg.band = 'alpha';
%   plot_peak_dist(cfg, bandPow);
%
%   % Histogram with individual subjects as dots
%   cfg = []; cfg.type = 'peak_freq'; cfg.band = 'alpha';
%   cfg.show_individual_subjects = true;
%   plot_peak_dist(cfg, bandPow);
%
%   % Density: KDE (default)
%   cfg = []; cfg.type = 'peak_freq'; cfg.band = 'alpha'; cfg.method = 'density';
%   plot_peak_dist(cfg, bandPow);
%
%   % Density: ECDF (no smoothing artifacts)
%   cfg = []; cfg.type = 'peak_freq'; cfg.band = 'alpha'; cfg.method = 'density';
%   cfg.density_method = 'ecdf';
%   plot_peak_dist(cfg, bandPow);
%
%   % Density: Rug plot (shows individual subjects)
%   cfg = []; cfg.type = 'peak_freq'; cfg.band = 'alpha'; cfg.method = 'density';
%   cfg.density_method = 'rug';
%   plot_peak_dist(cfg, bandPow);

% ---- Validate inputs ----
if ~isfield(cfg, 'type') || isempty(cfg.type)
    error('plot_peak_dist:noType', 'cfg.type is required (''peak_freq'', ''absolute_power'', or ''relative_power'')');
end

if ~isfield(cfg, 'band') || isempty(cfg.band)
    error('plot_peak_dist:noBand', 'cfg.band is required (band name or index)');
end

% ---- Set defaults ----
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
    cfg.nbins = 15;
end

if ~isfield(cfg, 'alpha') || isempty(cfg.alpha)
    cfg.alpha = 0.5;
end

if ~isfield(cfg, 'linewidth') || isempty(cfg.linewidth)
    cfg.linewidth = 2;
end

if ~isfield(cfg, 'marker_size') || isempty(cfg.marker_size)
    cfg.marker_size = 30;
end

if ~isfield(cfg, 'group_idx') || isempty(cfg.group_idx)
    cfg.group_idx = 1:numel(bandPow);
else
    cfg.group_idx = cfg.group_idx(:)';
end

if ~isfield(cfg, 'exclude_subjects') || isempty(cfg.exclude_subjects)
    cfg.exclude_subjects = [];
end

if ~isfield(cfg, 'subject_ids') || isempty(cfg.subject_ids)
    cfg.subject_ids = [];
end

if ~isfield(cfg, 'colors') || isempty(cfg.colors)
    cfg.colors = [];
end

% Validate group_idx
if max(cfg.group_idx) > numel(bandPow) || min(cfg.group_idx) < 1
    error('plot_peak_dist:groupIndexOutOfRange', 'cfg.group_idx out of range (1-%d)', numel(bandPow));
end

if isempty(cfg.group_idx)
    error('plot_peak_dist:noGroupsSelected', 'No groups selected in cfg.group_idx');
end

% ---- Validate type ----
valid_types = {'peak_freq', 'absolute_power', 'relative_power'};
if ~ismember(cfg.type, valid_types)
    error('plot_peak_dist:invalidType', 'cfg.type must be one of: %s', strjoin(valid_types, ', '));
end

% ---- Validate method ----
valid_methods = {'histogram', 'density'};
if ~ismember(cfg.method, valid_methods)
    error('plot_peak_dist:invalidMethod', 'cfg.method must be one of: %s', strjoin(valid_methods, ', '));
end

% ---- Validate density_method ----
valid_density_methods = {'kde', 'violin', 'ecdf', 'rug', 'strip'};
if ~ismember(cfg.density_method, valid_density_methods)
    error('plot_peak_dist:invalidDensityMethod', 'cfg.density_method must be one of: %s', strjoin(valid_density_methods, ', '));
end

if strcmp(cfg.method, 'histogram') && ~strcmp(cfg.density_method, 'kde')
    warning('plot_peak_dist:densityMethodIgnored', 'cfg.density_method is ignored when cfg.method=''histogram''');
end

% ---- Resolve band index ----
bandNames = bandPow(1).bandNames;
if ischar(cfg.band) || isstring(cfg.band)
    band_idx = find(strcmpi(bandNames, cfg.band));
    if isempty(band_idx)
        error('plot_peak_dist:bandNotFound', 'Band ''%s'' not found. Available: %s', ...
            cfg.band, strjoin(bandNames, ', '));
    end
else
    band_idx = cfg.band;
    if band_idx < 1 || band_idx > numel(bandNames)
        error('plot_peak_dist:bandIndexOutOfRange', 'Band index %d out of range (1-%d)', band_idx, numel(bandNames));
    end
end
band_name = bandNames{band_idx};

% Get band edges for subtitle
bandEdges = bandPow(1).bandEdges(band_idx, :);
if isinf(bandEdges(2))
    band_range_str = sprintf('Range: %.1f - Inf Hz', bandEdges(1));
else
    band_range_str = sprintf('Range: %.1f - %.1f Hz', bandEdges(1), bandEdges(2));
end

% Add channels to subtitle if available
if isfield(bandPow(1), 'chan') && ~isempty(bandPow(1).chan)
    chan_str = sprintf(', Channels: %s', strjoin(bandPow(1).chan, ', '));
    band_range_str = [band_range_str, chan_str];
end

% ---- Set up colors with defaults ----
nGroupsToPlot = numel(cfg.group_idx);
if isempty(cfg.colors)
    colors_default = lines(nGroupsToPlot);
    for g_idx = 1:nGroupsToPlot
        g = cfg.group_idx(g_idx);
        group_name = bandPow(g).name;
        if strcmpi(group_name, 'ASD')
            colors_default(g_idx, :) = [0.4000 0.6667 0.8000];
        elseif strcmpi(group_name, 'NT')
            colors_default(g_idx, :) = [0.6118 0.8118 0.5843];
        end
    end
    cfg.colors = colors_default;
else
    if size(cfg.colors, 1) ~= nGroupsToPlot || size(cfg.colors, 2) ~= 3
        error('plot_peak_dist:colorSize', 'cfg.colors must be %d x 3 (RGB)', nGroupsToPlot);
    end
end

% ---- Extract data for selected groups ----
group_data = cell(nGroupsToPlot, 1);
group_names = cell(nGroupsToPlot, 1);
group_ns = zeros(nGroupsToPlot, 1);
bandPow_data = cell(nGroupsToPlot, 1);  % Store bandPow objects for each group

for g_idx = 1:nGroupsToPlot
    g = cfg.group_idx(g_idx);

    switch cfg.type
        case 'peak_freq'
            if ~isfield(bandPow(g), 'peakFreq')
                error('plot_peak_dist:noPeakFreq', ...
                    'Peak frequencies not found. Ensure computeBandPower was run with cfg.compute_peak_freq=true');
            end
            data = bandPow(g).peakFreq(:, band_idx);
            xlabel_str = 'Frequency (Hz)';

        case 'absolute_power'
            data = bandPow(g).abs(:, band_idx);
            xlabel_str = 'Absolute Power (μV²)';

        case 'relative_power'
            data = bandPow(g).rel(:, band_idx);
            xlabel_str = 'Relative Power (fraction)';
    end

    % Apply subject exclusion if specified
    if ~isempty(cfg.exclude_subjects)
        data = filterExcludeSubjects(data, bandPow(g).IDs, cfg.exclude_subjects);
    end

    % Remove NaN values
    data = data(~isnan(data));
    if isempty(data)
        warning('plot_peak_dist:noData', 'No valid data for group %d (%s)', g, bandPow(g).name);
    end

    group_data{g_idx} = data;
    group_names{g_idx} = bandPow(g).name;
    group_ns(g_idx) = numel(data);
    bandPow_data{g_idx} = bandPow(g);
end

% ---- Create figure ----
fig = figure('Name', sprintf('Distribution: %s %s', band_name, cfg.type), ...
             'NumberTitle', 'off', 'Position', [100 100 900 600]);

% ---- Plot based on method ----
switch cfg.method
    case 'histogram'
        plot_histogram(group_data, group_names, group_ns, cfg.nbins, cfg.alpha, cfg.colors, ...
                       cfg.show_individual_subjects, cfg.marker_size, ...
                       xlabel_str, band_name, band_range_str);

    case 'density'
        switch cfg.density_method
            case 'kde'
                plot_density_kde(group_data, group_names, group_ns, cfg.alpha, cfg.linewidth, cfg.colors, ...
                                 xlabel_str, band_name, band_range_str);
            case 'violin'
                plot_density_violin(group_data, group_names, group_ns, cfg.colors, ...
                                    xlabel_str, band_name, band_range_str);
            case 'ecdf'
                plot_density_ecdf(group_data, group_names, group_ns, cfg.linewidth, cfg.colors, ...
                                  xlabel_str, band_name, band_range_str);
            case 'rug'
                plot_density_rug(group_data, group_names, group_ns, cfg.marker_size, cfg.colors, ...
                                 xlabel_str, band_name, band_range_str);
            case 'strip'
                plot_density_strip(group_data, group_names, group_ns, cfg.marker_size, cfg.colors, ...
                                   xlabel_str, band_name, band_range_str);
        end
end

end

% ======================================================================= %
function plot_histogram(group_data, group_names, group_ns, nbins, alpha, colors, ...
                        show_individual, marker_size, xlabel_str, band_name, band_range_str)
% Plot overlayed histograms for each group
% Optionally overlay individual subject data points

nGroups = numel(group_data);

% Check if groups have different sample sizes
sample_sizes = group_ns(group_ns > 0);
normalize_hist = (numel(unique(sample_sizes)) > 1);

if normalize_hist
    norm_method = 'probability';
    ylabel_str = 'Probability';
else
    norm_method = 'count';
    ylabel_str = 'Count';
end

% Find data range
data_min = Inf;
data_max = -Inf;
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        data_min = min(data_min, min(data));
        data_max = max(data_max, max(data));
    end
end

data_range = data_max - data_min;
extended_min = data_min - 0.05 * data_range;
extended_max = data_max + 0.05 * data_range;

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        legend_label = sprintf('%s (N=%d)', group_names{g}, group_ns(g));
        histogram(data, nbins, 'DisplayName', legend_label, ...
                  'FaceColor', colors(g, :), 'EdgeColor', 'black', ...
                  'FaceAlpha', alpha, 'EdgeAlpha', 0.7, 'LineWidth', 1.5, ...
                  'Normalization', norm_method);
    end
end

% Overlay individual subjects if requested
if show_individual
    for g = 1:nGroups
        data = group_data{g};
        if ~isempty(data)
            jitter = (rand(size(data)) - 0.5) * 0.05 * data_range;
            y_pos = zeros(size(data));
            scatter(data + jitter, y_pos, marker_size, colors(g, :), ...
                   'filled', 'MarkerEdgeColor', 'black', 'MarkerEdgeAlpha', 0.3, ...
                   'MarkerFaceAlpha', 0.6, 'LineWidth', 0.5, 'HandleVisibility', 'off');
        end
    end
end

hold off

xlim([extended_min, extended_max]);

xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ylabel_str, 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s band - Distribution by Group (Histogram)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
end

% ======================================================================= %
function plot_density_kde(group_data, group_names, group_ns, alpha, linewidth, colors, ...
                          xlabel_str, band_name, band_range_str)
% Plot overlayed KDE density curves

nGroups = numel(group_data);

x_min = Inf;
x_max = -Inf;
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        x_min = min(x_min, min(data));
        x_max = max(x_max, max(data));
    end
end

x_range = x_max - x_min;
x_min = x_min - 0.2 * x_range;
x_max = x_max + 0.2 * x_range;
x_query = linspace(x_min, x_max, 200);

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        pdf_vals = ksdensity(data, x_query);
        legend_label = sprintf('%s (N=%d)', group_names{g}, group_ns(g));
        fill(x_query, pdf_vals, colors(g, :), 'FaceAlpha', alpha, ...
             'EdgeColor', colors(g, :), 'EdgeAlpha', 0.9, 'LineWidth', linewidth, ...
             'DisplayName', legend_label);
    end
end
hold off

xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Density', 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s Band - Distribution by Group (KDE)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
end

% ======================================================================= %
function plot_density_violin(group_data, group_names, group_ns, colors, ...
                             xlabel_str, band_name, band_range_str)
% Plot violin plots (KDE with symmetry)

nGroups = numel(group_data);
x_pos = 1:nGroups;

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        % Estimate KDE
        x_min = min(data);
        x_max = max(data);
        x_range = x_max - x_min;
        y_query = linspace(x_min - 0.2*x_range, x_max + 0.2*x_range, 200);
        density = ksdensity(data, y_query);

        % Normalize for width
        density = density / max(density) * 0.3;

        % Plot violin (symmetrical KDE)
        fill(x_pos(g) + density, y_query, colors(g, :), 'FaceAlpha', 0.6, ...
             'EdgeColor', colors(g, :), 'EdgeAlpha', 0.9, 'LineWidth', 1.5, ...
             'HandleVisibility', 'off');
        fill(x_pos(g) - density, y_query, colors(g, :), 'FaceAlpha', 0.6, ...
             'EdgeColor', colors(g, :), 'EdgeAlpha', 0.9, 'LineWidth', 1.5, ...
             'DisplayName', sprintf('%s (N=%d)', group_names{g}, group_ns(g)));
    end
end
hold off

set(gca, 'XTick', x_pos, 'XTickLabel', group_names);
ylabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s Band - Distribution by Group (Violin)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
end

% ======================================================================= %
function plot_density_ecdf(group_data, group_names, group_ns, linewidth, colors, ...
                           xlabel_str, band_name, band_range_str)
% Plot empirical cumulative distribution functions (no smoothing)

nGroups = numel(group_data);

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        [f, x] = ecdf(data);
        plot(x, f, 'Color', colors(g, :), 'LineWidth', linewidth, ...
             'DisplayName', sprintf('%s (N=%d)', group_names{g}, group_ns(g)));
    end
end
hold off

xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Cumulative Probability', 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s Band - Distribution by Group (ECDF)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
end

% ======================================================================= %
function plot_density_rug(group_data, group_names, group_ns, marker_size, colors, ...
                          xlabel_str, band_name, band_range_str)
% Plot rug plot: shows each individual subject as a tick mark

nGroups = numel(group_data);

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        y_pos = ones(size(data)) * g;
        scatter(data, y_pos, marker_size, colors(g, :), ...
               'filled', 'MarkerEdgeColor', 'black', 'MarkerEdgeAlpha', 0.5, ...
               'MarkerFaceAlpha', 0.7, 'LineWidth', 1, ...
               'DisplayName', sprintf('%s (N=%d)', group_names{g}, group_ns(g)));
    end
end
hold off

set(gca, 'YTick', 1:nGroups, 'YTickLabel', group_names);
xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Group', 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s Band - Distribution by Group (Rug Plot)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
end

% ======================================================================= %
function plot_density_strip(group_data, group_names, group_ns, marker_size, colors, ...
                            xlabel_str, band_name, band_range_str)
% Plot strip plot: scatter plot with jitter showing each individual subject

nGroups = numel(group_data);

hold on
for g = 1:nGroups
    data = group_data{g};
    if ~isempty(data)
        jitter = (rand(size(data)) - 0.5) * 0.3;
        y_pos = ones(size(data)) * g + jitter;
        scatter(data, y_pos, marker_size, colors(g, :), ...
               'filled', 'MarkerEdgeColor', 'black', 'MarkerEdgeAlpha', 0.5, ...
               'MarkerFaceAlpha', 0.7, 'LineWidth', 1, ...
               'DisplayName', sprintf('%s (N=%d)', group_names{g}, group_ns(g)));
    end
end
hold off

set(gca, 'YTick', 1:nGroups, 'YTickLabel', group_names);
xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Group', 'FontSize', 12, 'FontWeight', 'bold');
title_str = sprintf('%s Band - Distribution by Group (Strip Plot)', band_name);
title({title_str; band_range_str}, 'FontSize', 12, 'FontWeight', 'normal');
legend('Location', 'best', 'FontSize', 11);
grid on
set(gca, 'GridAlpha', 0.3);
ylim([0.5 nGroups+0.5]);
end

% ======================================================================= %
function filtered_data = filterExcludeSubjects(data, subject_ids, exclude_list)
% Filter data by excluding specified subject IDs

if isempty(exclude_list)
    filtered_data = data;
    return;
end

if ~iscell(exclude_list)
    exclude_list = {exclude_list};
end

exclude_str = cell(size(exclude_list));
for i = 1:numel(exclude_list)
    exclude_str{i} = char(string(exclude_list{i}));
end

filtered_data = data;
for s = 1:numel(subject_ids)
    subj_id = char(string(subject_ids{s}));
    if any(strcmpi(subj_id, exclude_str))
        filtered_data(s) = NaN;
    end
end
end
