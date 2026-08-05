function outliers_struct = plotFFTOutliers(durTbl, groups, varargin)
% PLOTFFTOUTLIERS  Visualize FFT recording time distribution and mark outliers
%
% Plots histograms of FFT recording times per group and identifies outliers
% using various methods (z-score, IQR, MAD).
%
% INPUTS:
%   durTbl  : table output from fftRecordingTime(FFT_arr, window_length)
%             Must contain columns: 'ID', 'duration_min', 'group_name' (or similar)
%   groups  : struct array with fields:
%             .name - group name
%             .color - RGB color for plotting
%
% Optional name-value pairs:
%   'outlier_methods' - 'none' | one method | cell array of methods
%                       Methods: 'zscore', 'iqr', 'mad'
%                       Default: 'zscore'
%   'zscore_threshold' - z-score threshold for outlier detection (default: 2.5)
%   'iqr_multiplier'   - IQR multiplier (default: 1.5)
%   'verbose'          - print outlier info (default: true)
%
% OUTPUT:
%   outliers_struct : struct with outlier information per group and method
%
% USAGE:
%   [durTbl, summary] = fftRecordingTime(FFT_arr, 5);
%   outliers = plotFFTOutliers(durTbl, groups);
%   outliers = plotFFTOutliers(durTbl, groups, 'outlier_methods', {'zscore', 'iqr'});

% Parse inputs
p = inputParser;
addParameter(p, 'outlier_methods', 'zscore');
addParameter(p, 'zscore_threshold', 2.5);
addParameter(p, 'iqr_multiplier', 1.5);
addParameter(p, 'verbose', true);
parse(p, varargin{:});

outlier_methods = p.Results.outlier_methods;
zscore_thresh = p.Results.zscore_threshold;
iqr_mult = p.Results.iqr_multiplier;
verbose = p.Results.verbose;

% Normalize outlier_methods to cell array
if strcmpi(outlier_methods, 'none')
    outlier_methods = {};
elseif ischar(outlier_methods) || isstring(outlier_methods)
    outlier_methods = {char(outlier_methods)};
end

% Ensure durTbl is a table and get column names
if istable(durTbl)
    % Identify ID column (could be 'ID', 'id', 'SubjID', etc.)
    id_col = getColumnName(durTbl, {'ID', 'id', 'subj_id', 'subject_id'});
    % Identify duration column (minutes, duration_min, etc.)
    dur_col = getColumnName(durTbl, {'minutes', 'duration_min', 'duration', 'Duration_min', 'Duration'});

    group_ids = string(durTbl.(id_col));
    group_data = durTbl.(dur_col);

    % Map IDs to group names from groups struct
    group_labels = strings(size(group_ids));
    for g = 1:numel(groups)
        for s = 1:numel(groups(g).data_fft)
            subj_id = string(groups(g).data_fft{s}.ID);
            match_idx = find(strcmp(group_ids, subj_id));
            if ~isempty(match_idx)
                group_labels(match_idx) = groups(g).name;
            end
        end
    end
else
    error('durTbl must be a table');
end

% Create figure
figure('Position', [100, 100, 1200, 500]);

% Plot histograms per group
for g = 1:numel(groups)
    subplot(1, numel(groups), g);
    hold on;

    % Get data for this group
    group_mask = strcmp(group_labels, groups(g).name);
    group_times = group_data(group_mask);
    group_ids_g = group_ids(group_mask);

    % Plot histogram
    [counts, edges] = histcounts(group_times, 'BinMethod', 'auto');
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    bar(centers, counts, 'FaceColor', groups(g).color, 'FaceAlpha', 0.7, 'EdgeColor', 'black');

    % Identify outliers using specified methods
    outliers_by_method = {};
    outlier_idx_by_method = {};

    for m = 1:numel(outlier_methods)
        method = outlier_methods{m};
        outlier_idx = identifyOutliers(group_times, method, zscore_thresh, iqr_mult);
        outlier_idx_by_method{m} = outlier_idx;
        outliers_by_method{m} = group_ids_g(outlier_idx);
    end

    % Mark outliers on histogram
    if ~isempty(outlier_methods)
        for idx = 1:numel(group_times)
            is_outlier = false(1, numel(outlier_methods));
            for m = 1:numel(outlier_methods)
                is_outlier(m) = any(outlier_idx_by_method{m} == idx);
            end

            if any(is_outlier)
                plot(group_times(idx), 0, 'r*', 'MarkerSize', 12, 'LineWidth', 2);
            end
        end
    end

    xlabel('Recording Time (minutes)');
    ylabel('Count');
    title(sprintf('%s (N=%d)', groups(g).name, sum(group_mask)));
    grid on;

    % Store outlier info
    outliers_struct(g).group_name = groups(g).name;
    outliers_struct(g).n_subjects = sum(group_mask);
    outliers_struct(g).times = group_times;
    outliers_struct(g).ids = group_ids_g;

    for m = 1:numel(outlier_methods)
        outliers_struct(g).(outlier_methods{m}).outlier_idx = outlier_idx_by_method{m};
        outliers_struct(g).(outlier_methods{m}).outlier_ids = group_ids_g(outlier_idx_by_method{m});
        outliers_struct(g).(outlier_methods{m}).n_outliers = numel(outlier_idx_by_method{m});
    end

    % Print info if verbose
    if verbose
        fprintf('\n%s:\n', groups(g).name);
        fprintf('  Total subjects: %d\n', sum(group_mask));
        fprintf('  Duration range: %.2f - %.2f min\n', min(group_times), max(group_times));
        fprintf('  Mean ± SD: %.2f ± %.2f min\n', mean(group_times), std(group_times));

        for m = 1:numel(outlier_methods)
            n_out = sum(outlier_idx_by_method{m});
            if n_out > 0
                fprintf('  %s outliers (%d): %s\n', ...
                    upper(outlier_methods{m}), n_out, ...
                    strjoin(group_ids_g(outlier_idx_by_method{m}), ', '));
            else
                fprintf('  %s outliers: none\n', upper(outlier_methods{m}));
            end
        end
    end
end

sgtitle('FFT Recording Time Distribution by Group (red * = outliers)');

end

% =========================================================================

function col_name = getColumnName(tbl, possible_names)
% Find the first column name from possible_names that exists in table tbl

col_names = tbl.Properties.VariableNames;
for i = 1:numel(possible_names)
    if any(strcmp(col_names, possible_names{i}))
        col_name = possible_names{i};
        return;
    end
end
error('Could not find any of these columns in table: %s', strjoin(possible_names, ', '));
end

% =========================================================================

function outlier_idx = identifyOutliers(data, method, zscore_thresh, iqr_mult)
% Identify outliers using specified method

data = data(~isnan(data));  % Remove NaN values

switch lower(method)
    case 'zscore'
        z_scores = abs((data - mean(data)) / std(data));
        outlier_idx = find(z_scores > zscore_thresh);

    case 'iqr'
        q1 = quantile(data, 0.25);
        q3 = quantile(data, 0.75);
        iqr = q3 - q1;
        lower_bound = q1 - iqr_mult * iqr;
        upper_bound = q3 + iqr_mult * iqr;
        outlier_idx = find((data < lower_bound) | (data > upper_bound));

    case 'mad'
        % Median Absolute Deviation
        median_val = median(data);
        mad_val = median(abs(data - median_val));
        mad_scores = 0.6745 * (data - median_val) / (mad_val + eps);
        outlier_idx = find(abs(mad_scores) > 3.5);

    otherwise
        error('Unknown outlier method: %s', method);
end

end
