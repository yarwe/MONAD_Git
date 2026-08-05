function [stats] = test_LAVI_peaks_difference(borders_all_subj, groups, freq_range, ch_idx, LAVI_arr)
% TEST_LAVI_PEAKS_DIFFERENCE  Compare detected LAVI peaks between groups
%
% Compares peak frequencies detected within a specified frequency range
% between two groups using statistical tests. Handles both single-channel
% and multi-channel data.
%
% INPUTS:
%   borders_all_subj : subject × channels cell array from LAVI_findBorders
%                      Each borders_all_subj{id, ch} contains an N_bands × 11 matrix:
%                      Col 6: frequency at peak/trough
%                      Col 7: LAVI value at peak/trough
%                      Col 9: direction (1=peak, -1=trough)
%                      Col 11: significance (boolean)
%                      Note: Can be N×1 if pre-averaged (single channel)
%   groups     : struct array with fields .name (group name) and .data_LAVI
%                Must have exactly 2 groups for comparison
%   freq_range : [lo hi] frequency range to analyze, e.g. [8 13] for alpha
%   ch_idx     : (optional) channel index (e.g., 34 for 'Cz')
%                If omitted or borders_all_subj is N×1, uses column 1 (pre-averaged)
%   LAVI_arr   : cell array of LAVI data (rows of borders_all_subj correspond to LAVI_arr indices)
%
% OUTPUTS:
%   stats      : struct with statistical comparison results
%     .group1, .group2 : group names
%     .freq_range : frequency range analyzed
%     .n_g1, .n_g2 : number of subjects in each group
%     .peaks_g1, .peaks_g2 : detected peak frequencies
%     .mean_g1, .mean_g2 : mean peak frequency
%     .sd_g1, .sd_g2 : std dev of peak frequencies
%     .t, .df, .p_ttest, .p_mw, .d : statistical test results
%
% USAGE:
%   % Multi-channel data (specify which channel)
%   ch_idx = find(strcmp('Cz', env.lay.label));  % e.g., 34
%   stats = test_LAVI_peaks_difference(borders_all_subj, groups, [8 13], ch_idx, LAVI_arr);
%
%   % Pre-averaged single channel data (no ch_idx needed)
%   stats = test_LAVI_peaks_difference(borders_all_subj_central, groups, [8 13]);

if numel(groups) < 2
    error('Need at least 2 groups to compare');
end

% Detect if single-channel (N×1) or multi-channel data
n_cols = size(borders_all_subj, 2);
is_single_channel = (n_cols == 1);

% Handle parameter requirements based on data type
if is_single_channel
    % Single-channel: ch_idx and LAVI_arr not needed
    ch_to_use = 1;
    LAVI_arr = [];
else
    % Multi-channel: ch_idx required
    if nargin < 4
        error('For multi-channel data, ch_idx is required as 4th parameter');
    end
    ch_to_use = ch_idx;

    % LAVI_arr needed for multi-channel to map subject IDs
    if nargin < 5
        error('For multi-channel data, LAVI_arr is required as 5th parameter');
    end

    % Build mapping from subject ID to LAVI_arr index
    subj_to_lavi_idx = containers.Map();
    for lavi_idx = 1:numel(LAVI_arr)
        subj_id = LAVI_arr{lavi_idx}.ID;
        subj_to_lavi_idx(char(subj_id)) = lavi_idx;
    end
end

freq_lo = freq_range(1);
freq_hi = freq_range(2);

fprintf('\n%s\n', repmat('═', 1, 70));
if is_single_channel
    fprintf('       LAVI Peak Comparison: Single Channel (Averaged) [%.1f-%.1f Hz]\n', freq_lo, freq_hi);
else
    fprintf('       LAVI Peak Comparison: Channel %d [%.1f-%.1f Hz]\n', ch_to_use, freq_lo, freq_hi);
end
fprintf('%s\n', repmat('═', 1, 70));

% Collect peaks from each group
peaks_g1 = [];
peaks_g2 = [];
n_peaks_g1 = 0;
n_peaks_g2 = 0;
excluded_g1 = 0;
excluded_g2 = 0;

% --- Group 1 ---
fprintf('\n%s:\n', groups(1).name);
for i = 1:numel(groups(1).data_LAVI)
    subj_id = groups(1).data_LAVI{i}.ID;

    % Determine which row of borders_all_subj to use
    if is_single_channel
        row_idx = i;  % For pre-averaged, use group index directly
    else
        % For multi-channel, find LAVI_arr index
        subj_id_str = char(string(subj_id));
        if ~isKey(subj_to_lavi_idx, subj_id_str)
            excluded_g1 = excluded_g1 + 1;
            continue;
        end
        row_idx = subj_to_lavi_idx(subj_id_str);
    end

    % Extract peaks from borders_all_subj
    if ch_to_use > size(borders_all_subj, 2)
        excluded_g1 = excluded_g1 + 1;
        continue;
    end

    borders_matrix = borders_all_subj{row_idx, ch_to_use};

    % Skip if empty or invalid structure
    if isempty(borders_matrix)
        excluded_g1 = excluded_g1 + 1;
        continue;
    end

    % Ensure it's 2D (sometimes ABBA returns 1D for averaged data)
    if ~ismatrix(borders_matrix) || size(borders_matrix, 2) < 11
        excluded_g1 = excluded_g1 + 1;
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
        peaks_g1 = [peaks_g1; dominant_peak];
        n_peaks_g1 = n_peaks_g1 + 1;
    else
        excluded_g1 = excluded_g1 + 1;
    end
end

% --- Group 2 ---
fprintf('%s:\n', groups(2).name);
for i = 1:numel(groups(2).data_LAVI)
    subj_id = groups(2).data_LAVI{i}.ID;

    % Determine which row of borders_all_subj to use
    if is_single_channel
        row_idx = i;  % For pre-averaged, use group index directly
    else
        % For multi-channel, find LAVI_arr index
        subj_id_str = char(string(subj_id));
        if ~isKey(subj_to_lavi_idx, subj_id_str)
            excluded_g2 = excluded_g2 + 1;
            continue;
        end
        row_idx = subj_to_lavi_idx(subj_id_str);
    end

    % Extract peaks from borders_all_subj
    if ch_to_use > size(borders_all_subj, 2)
        excluded_g2 = excluded_g2 + 1;
        continue;
    end

    borders_matrix = borders_all_subj{row_idx, ch_to_use};

    % Skip if empty or invalid structure
    if isempty(borders_matrix)
        excluded_g2 = excluded_g2 + 1;
        continue;
    end

    % Ensure it's 2D (sometimes ABBA returns 1D for averaged data)
    if ~ismatrix(borders_matrix) || size(borders_matrix, 2) < 11
        excluded_g2 = excluded_g2 + 1;
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
        peaks_g2 = [peaks_g2; dominant_peak];
        n_peaks_g2 = n_peaks_g2 + 1;
    else
        excluded_g2 = excluded_g2 + 1;
    end
end

% Check if we have data in at least one group
if (isempty(peaks_g1) && n_peaks_g1 == 0) && (isempty(peaks_g2) && n_peaks_g2 == 0)
    error('No peaks found in frequency range [%.1f %.1f] Hz in any group', freq_lo, freq_hi);
end

if isempty(peaks_g1) || n_peaks_g1 == 0
    warning('No peaks found in %s group for frequency range [%.1f %.1f] Hz', groups(1).name, freq_lo, freq_hi);
end

if isempty(peaks_g2) || n_peaks_g2 == 0
    warning('No peaks found in %s group for frequency range [%.1f %.1f] Hz', groups(2).name, freq_lo, freq_hi);
end

% Only calculate statistics if both groups have data
if isempty(peaks_g1) || isempty(peaks_g2) || n_peaks_g1 == 0 || n_peaks_g2 == 0
    fprintf('\n%s\n', repmat('─', 1, 70));
    fprintf('WARNING: Cannot perform statistical comparison - insufficient data in one or both groups\n');
    fprintf('  %s: %d subjects with peaks\n', groups(1).name, n_peaks_g1);
    fprintf('  %s: %d subjects with peaks\n', groups(2).name, n_peaks_g2);
    fprintf('%s\n', repmat('═', 1, 70));

    % Return empty stats
    stats = struct();
    return;
end

% Calculate statistics
mean_g1 = mean(peaks_g1);
sd_g1 = std(peaks_g1);
mean_g2 = mean(peaks_g2);
sd_g2 = std(peaks_g2);

% T-test
[t, df, p_ttest, d] = welch_ttest(peaks_g1, peaks_g2);

% Mann-Whitney U test
p_mw = ranksum(peaks_g1, peaks_g2);

% Get channel label (handle both single and multi-channel)
if is_single_channel
    ch_str = 'Averaged';
else
    ch_str = LAVI_arr{1}.label{ch_to_use};
end

% Print results
fprintf('\n%s\n', repmat('─', 1, 70));
fprintf('Results for %s, Range [%.1f-%.1f Hz]:\n', ch_str, freq_lo, freq_hi);
fprintf('%s\n', repmat('─', 1, 70));
fprintf('%s: Mean=%.2f ± %.2f Hz (N=%d subjects, %d peaks)\n', ...
    groups(1).name, mean_g1, sd_g1, n_peaks_g1, numel(peaks_g1));
fprintf('%s: Mean=%.2f ± %.2f Hz (N=%d subjects, %d peaks)\n', ...
    groups(2).name, mean_g2, sd_g2, n_peaks_g2, numel(peaks_g2));
fprintf('\nDifference: %.2f Hz\n', abs(mean_g1 - mean_g2));
fprintf('Welch''s t-test:  t(%.1f)=%.3f, p=%.4f %s\n', df, t, p_ttest, iif(p_ttest < 0.05, '*', 'n.s.'));
fprintf('Mann-Whitney U:  p=%.4f %s\n', p_mw, iif(p_mw < 0.05, '*', 'n.s.'));
fprintf('Cohen''s d:       %.3f\n', d);
fprintf('%s\n', repmat('═', 1, 70));

% Store results
stats.group1 = groups(1).name;
stats.group2 = groups(2).name;
stats.freq_range = freq_range;
if is_single_channel
    stats.ch_label = 'Averaged';
else
    stats.ch_idx = ch_to_use;
end
stats.n_g1 = n_peaks_g1;
stats.n_g2 = n_peaks_g2;
stats.excluded_g1 = excluded_g1;
stats.excluded_g2 = excluded_g2;
stats.peaks_g1 = peaks_g1;
stats.peaks_g2 = peaks_g2;
stats.mean_g1 = mean_g1;
stats.mean_g2 = mean_g2;
stats.sd_g1 = sd_g1;
stats.sd_g2 = sd_g2;
stats.t = t;
stats.df = df;
stats.p_ttest = p_ttest;
stats.p_mw = p_mw;
stats.d = d;
stats.significant = (p_ttest < 0.05);

end

% ======================================================================= %
function [t, df, p, d] = welch_ttest(x, y)
% Welch's two-sample t-test (unequal variances)
x = x(~isnan(x));
y = y(~isnan(y));
nx = numel(x);
ny = numel(y);
mx = mean(x);
my = mean(y);
vx = var(x);
vy = var(y);

se = sqrt(vx/nx + vy/ny);
t  = (mx - my) / se;
df = (vx/nx + vy/ny)^2 / ((vx/nx)^2/(nx-1) + (vy/ny)^2/(ny-1));

p = 2 * (1 - tcdf(abs(t), df));

sp = sqrt(((nx-1)*vx + (ny-1)*vy) / (nx + ny - 2));
d  = (mx - my) / sp;
end

% ======================================================================= %
function result = iif(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
