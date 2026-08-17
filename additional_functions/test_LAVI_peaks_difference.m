function [stats] = test_LAVI_peaks_difference(borders_all_subj, groups, freq_range, varargin)
% TEST_LAVI_PEAKS_DIFFERENCE  Compare detected LAVI peaks or troughs between groups
%
% Compares the frequency of the dominant LAVI extremum within a specified
% frequency range between two groups. Which extremum to look for is chosen by
% the caller: bands are peaks in some ranges and troughs in others (alpha is
% typically a peak, delta typically a trough), so the same test is run either
% way - only the direction of the band and the "dominant" rule change.
%
% INPUTS:
%   borders_all_subj : subject × channels cell array from findLAVIBorders
%                      Each borders_all_subj{id, ch} contains an N_bands × 11 matrix:
%                      Col 6: frequency at peak/trough
%                      Col 7: LAVI value at peak/trough
%                      Col 9: direction (1=peak, -1=trough)
%                      Col 11: significance (boolean)
%                      Note: Can be N×1 if pre-averaged (single channel)
%   groups     : struct array with fields .name (group name) and .data_lavi
%                Must have exactly 2 groups for comparison
%   freq_range : [lo hi] frequency range to analyze, e.g. [8 13] for alpha
%
% OPTIONAL INPUTS (any order, identified by type):
%   ch_idx     : numeric scalar, channel index (e.g., 34 for 'Cz').
%                Required for multi-channel input; ignored when the input is
%                pre-averaged (N×1).
%   LAVI_arr   : cell array of LAVI data. Used to map each subject's ID to its
%                row of borders_all_subj. Required for multi-channel input, and
%                STRONGLY recommended for pre-averaged input too - without it
%                the rows can only be matched by position, which is wrong
%                whenever a group is not the first block of LAVI_arr (see the
%                warning this function issues).
%   extremum   : 'peak' (default) or 'trough' - which kind of band to look for
%                in freq_range. Abbreviations 'p'/'t' are accepted.
%
% OUTPUTS:
%   stats      : struct with statistical comparison results
%     .group1, .group2 : group names
%     .extremum   : 'peak' or 'trough', which was analyzed
%     .freq_range : frequency range analyzed
%     .n_g1, .n_g2 : number of subjects contributing an extremum
%     .peaks_g1, .peaks_g2 : the selected extremum frequencies (peaks or
%                            troughs, according to .extremum)
%     .mean_g1, .mean_g2 : mean extremum frequency
%     .sd_g1, .sd_g2 : std dev of extremum frequencies
%     .excluded_g1, .excluded_g2 : subjects with no qualifying extremum
%     .excluded_nanfreq_g1, .excluded_nanfreq_g2 : subjects excluded because
%                            ABBA blanked the frequency columns (see note)
%     .t, .df, .p_ttest, .p_mw, .d : statistical test results
%
% NOTE ON NaN FREQUENCIES:
%   ABBA sets columns 4:6 and 10 to NaN for a channel when it cannot find a
%   peak inside its alpha_range (ABBA.m, the `borders(:,[4:6,10]) = nan` line).
%   Those subjects have perfectly valid bands but no usable frequency column,
%   so they cannot contribute here and are counted separately. This matters
%   most for trough analyses in delta: a subject can have a clean delta trough
%   and still be dropped because their alpha peak fell outside alpha_range.
%
% USAGE:
%   % Alpha peaks, multi-channel data (specify which channel)
%   ch_idx = find(strcmp('Cz', env.lay.label));
%   stats = test_LAVI_peaks_difference(borders_all_subj, groups, [8 13], ch_idx, LAVI_arr);
%
%   % Delta troughs, same data
%   stats = test_LAVI_peaks_difference(borders_all_subj, groups, [1 4], ch_idx, LAVI_arr, 'trough');
%
%   % Pre-averaged single channel data (no ch_idx needed, but pass LAVI_arr)
%   stats = test_LAVI_peaks_difference(borders_central_subj, groups, [8 13], LAVI_arr);
%   stats = test_LAVI_peaks_difference(borders_central_subj, groups, [1 4], LAVI_arr, 'trough');

if numel(groups) < 2
    error('Need at least 2 groups to compare');
end

% ---- Parse the optional arguments by type, so they can be given in any order
ch_idx   = [];
LAVI_arr = [];
extremum = 'peak';
for k = 1:numel(varargin)
    arg = varargin{k};
    if isempty(arg)
        continue;
    elseif ischar(arg) || isstring(arg)
        extremum = char(arg);
    elseif iscell(arg)
        LAVI_arr = arg;
    elseif isnumeric(arg) && isscalar(arg)
        ch_idx = arg;
    else
        error('Unrecognized optional argument of class %s in position %d', class(arg), k + 3);
    end
end

% ---- Which extremum are we after
switch lower(extremum)
    case {'peak', 'peaks', 'p'}
        want_dir  = 1;      % column 9 of the borders matrix
        extremum  = 'peak';
        label_one = 'Peak';
        label_pl  = 'peaks';
        best_str  = 'highest LAVI';
    case {'trough', 'troughs', 't'}
        want_dir  = -1;
        extremum  = 'trough';
        label_one = 'Trough';
        label_pl  = 'troughs';
        best_str  = 'lowest LAVI';
    otherwise
        error('extremum must be ''peak'' or ''trough'', got ''%s''', extremum);
end

% Detect if single-channel (N×1) or multi-channel data
n_cols = size(borders_all_subj, 2);
is_single_channel = (n_cols == 1);

if is_single_channel
    % Pre-averaged: there is only one column to read
    ch_to_use = 1;
else
    if isempty(ch_idx)
        error('For multi-channel data, a channel index is required');
    end
    ch_to_use = ch_idx;

    if isempty(LAVI_arr)
        error('For multi-channel data, LAVI_arr is required to map subject IDs to rows');
    end
end

% Build the ID -> row mapping. Rows of borders_all_subj follow LAVI_arr order,
% while groups(g).data_lavi holds only that group's subjects, so matching by
% position is only correct for a group that happens to sit at the top of
% LAVI_arr. Always map by ID when LAVI_arr is available.
if ~isempty(LAVI_arr)
    subj_to_lavi_idx = containers.Map();
    for lavi_idx = 1:numel(LAVI_arr)
        subj_id = LAVI_arr{lavi_idx}.ID;
        subj_to_lavi_idx(char(string(subj_id))) = lavi_idx;
    end
else
    subj_to_lavi_idx = [];
    warning('test_LAVI_peaks_difference:positionalRows', ...
        ['LAVI_arr was not supplied, so subjects are matched to rows of ' ...
         'borders_all_subj by position. That is only correct for a group ' ...
         'occupying the first rows of LAVI_arr - every later group reads ' ...
         'another group''s data. Pass LAVI_arr to fix this.']);
end

freq_lo = freq_range(1);
freq_hi = freq_range(2);

fprintf('\n%s\n', repmat('═', 1, 70));
if is_single_channel
    fprintf('       LAVI %s Comparison: Single Channel (Averaged) [%.1f-%.1f Hz]\n', ...
        label_one, freq_lo, freq_hi);
else
    fprintf('       LAVI %s Comparison: Channel %d [%.1f-%.1f Hz]\n', ...
        label_one, ch_to_use, freq_lo, freq_hi);
end
fprintf('%s\n', repmat('═', 1, 70));

% ---- Collect the dominant extremum per subject, for each group
% Built by assignment, not struct(): struct() with a cell value would expand
% borders_all_subj into a struct array instead of storing it
opts         = struct();
opts.borders = borders_all_subj;
opts.ch      = ch_to_use;
opts.map     = subj_to_lavi_idx;
opts.lo      = freq_lo;
opts.hi      = freq_hi;
opts.dir     = want_dir;

fprintf('\n%s:\n', groups(1).name);
[freqs_g1, excluded_g1, nanfreq_g1] = collectExtrema(groups(1), opts);

fprintf('%s:\n', groups(2).name);
[freqs_g2, excluded_g2, nanfreq_g2] = collectExtrema(groups(2), opts);

n_g1 = numel(freqs_g1);
n_g2 = numel(freqs_g2);

if nanfreq_g1 > 0 || nanfreq_g2 > 0
    fprintf(['\nNote: %d (%s) and %d (%s) subjects were dropped because ABBA ' ...
        'blanked\n      their frequency columns (no alpha peak in that ' ...
        'channel).\n'], nanfreq_g1, groups(1).name, nanfreq_g2, groups(2).name);
end

% Check if we have data in at least one group
if n_g1 == 0 && n_g2 == 0
    error('No %s found in frequency range [%.1f %.1f] Hz in any group', ...
        label_pl, freq_lo, freq_hi);
end

if n_g1 == 0
    warning('No %s found in %s group for frequency range [%.1f %.1f] Hz', ...
        label_pl, groups(1).name, freq_lo, freq_hi);
end

if n_g2 == 0
    warning('No %s found in %s group for frequency range [%.1f %.1f] Hz', ...
        label_pl, groups(2).name, freq_lo, freq_hi);
end

% Only calculate statistics if both groups have data
if n_g1 == 0 || n_g2 == 0
    fprintf('\n%s\n', repmat('─', 1, 70));
    fprintf('WARNING: Cannot perform statistical comparison - insufficient data in one or both groups\n');
    fprintf('  %s: %d subjects with %s\n', groups(1).name, n_g1, label_pl);
    fprintf('  %s: %d subjects with %s\n', groups(2).name, n_g2, label_pl);
    fprintf('%s\n', repmat('═', 1, 70));

    % Return empty stats
    stats = struct();
    return;
end

% Calculate statistics
mean_g1 = mean(freqs_g1);
sd_g1 = std(freqs_g1);
mean_g2 = mean(freqs_g2);
sd_g2 = std(freqs_g2);

% T-test
[t, df, p_ttest, d] = welch_ttest(freqs_g1, freqs_g2);

% Mann-Whitney U test
p_mw = ranksum(freqs_g1, freqs_g2);

% Get channel label (handle both single and multi-channel)
if is_single_channel
    ch_str = 'Averaged';
else
    ch_str = LAVI_arr{1}.label{ch_to_use};
end

% Print results
fprintf('\n%s\n', repmat('─', 1, 70));
fprintf('Results for %s, %s in range [%.1f-%.1f Hz] (dominant = %s):\n', ...
    ch_str, label_pl, freq_lo, freq_hi, best_str);
fprintf('%s\n', repmat('─', 1, 70));
fprintf('%s: Mean=%.2f ± %.2f Hz (N=%d subjects, %d %s)\n', ...
    groups(1).name, mean_g1, sd_g1, n_g1, numel(freqs_g1), label_pl);
fprintf('%s: Mean=%.2f ± %.2f Hz (N=%d subjects, %d %s)\n', ...
    groups(2).name, mean_g2, sd_g2, n_g2, numel(freqs_g2), label_pl);
fprintf('\nDifference: %.2f Hz\n', abs(mean_g1 - mean_g2));
fprintf('Welch''s t-test:  t(%.1f)=%.3f, p=%.4f %s\n', df, t, p_ttest, iif(p_ttest < 0.05, '*', 'n.s.'));
fprintf('Mann-Whitney U:  p=%.4f %s\n', p_mw, iif(p_mw < 0.05, '*', 'n.s.'));
fprintf('Cohen''s d:       %.3f\n', d);
fprintf('%s\n', repmat('═', 1, 70));

% Store results
stats.group1 = groups(1).name;
stats.group2 = groups(2).name;
stats.extremum = extremum;
stats.freq_range = freq_range;
if is_single_channel
    stats.ch_label = 'Averaged';
else
    stats.ch_idx = ch_to_use;
end
stats.n_g1 = n_g1;
stats.n_g2 = n_g2;
stats.excluded_g1 = excluded_g1;
stats.excluded_g2 = excluded_g2;
stats.excluded_nanfreq_g1 = nanfreq_g1;
stats.excluded_nanfreq_g2 = nanfreq_g2;
stats.peaks_g1 = freqs_g1;
stats.peaks_g2 = freqs_g2;
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
function [freqs, excluded, nanfreq] = collectExtrema(group, opts)
% Dominant extremum frequency per subject of one group.
%
% opts fields: .borders .ch .map .lo .hi .dir
%   .dir = 1 to look for peaks, -1 for troughs. It also picks the winner: the
%   dominant band is the one with the largest LAVI in the requested direction,
%   i.e. max(dir .* LAVI) - the highest peak, or the deepest trough.

freqs    = [];
excluded = 0;
nanfreq  = 0;

for i = 1:numel(group.data_lavi)
    % Which row of borders_all_subj belongs to this subject
    if isempty(opts.map)
        row_idx = i;   % positional fallback; caller has been warned
    else
        subj_id_str = char(string(group.data_lavi{i}.ID));
        if ~isKey(opts.map, subj_id_str)
            excluded = excluded + 1;
            continue;
        end
        row_idx = opts.map(subj_id_str);
    end

    if row_idx > size(opts.borders, 1) || opts.ch > size(opts.borders, 2)
        excluded = excluded + 1;
        continue;
    end

    borders_matrix = opts.borders{row_idx, opts.ch};

    % Skip if empty or invalid structure
    % (ABBA sometimes returns 1D for averaged data)
    if isempty(borders_matrix) || ~ismatrix(borders_matrix) || size(borders_matrix, 2) < 11
        excluded = excluded + 1;
        continue;
    end

    is_significant = borders_matrix(:, 11) ~= 0;   % Column 11: significance
    direction      = borders_matrix(:, 9);         % Column 9: 1=peak, -1=trough
    freq           = borders_matrix(:, 6);         % Column 6: frequency
    lavi_val       = borders_matrix(:, 7);         % Column 7: LAVI value

    % Significant bands of the requested direction, inside the range.
    % NaN frequencies fail both comparisons and so drop out here.
    keep = is_significant & direction == opts.dir & freq >= opts.lo & freq <= opts.hi;

    if ~any(keep)
        excluded = excluded + 1;
        % Separate the "ABBA blanked the frequencies" case from a genuine
        % absence, so the two are not conflated in the exclusion count
        if all(isnan(freq))
            nanfreq = nanfreq + 1;
        end
        continue;
    end

    % Dominant band: highest peak, or deepest trough
    cand_freqs = freq(keep);
    cand_vals  = lavi_val(keep);
    [~, sel]   = max(opts.dir * cand_vals);
    freqs      = [freqs; cand_freqs(sel)]; %#ok<AGROW>
end

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
