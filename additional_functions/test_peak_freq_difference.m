function [stats] = test_peak_freq_difference(bandPow)
% TEST_PEAK_FREQ_DIFFERENCE  Statistical test for peak frequency differences
%
% Tests if peak frequencies differ significantly between groups using both
% parametric (t-test) and non-parametric (Mann-Whitney U) tests.
%
% INPUT
%   bandPow : output from computeBandPower with compute_peak_freq=true
%             Must be length >= 2 to compare groups
%
% OUTPUT
%   stats : struct with fields:
%     .band, .mean_g1, .mean_g2, .t, .df, .p_ttest, .p_mw, .significant
%
% USAGE
%   [stats] = test_peak_freq_difference(bandPow);
%
% Example output:
%   Alpha peak freq: ASD=10.1 Hz, NT=8.9 Hz, p_ttest=0.087, p_mw=0.056 (n.s.)

if ~isfield(bandPow(1), 'peakFreq')
    error('Peak frequencies not found. Ensure computeBandPower was run with cfg.compute_peak_freq=true');
end

if numel(bandPow) < 2
    error('Need at least 2 groups to compare');
end

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('             Peak Frequency Between-Group Comparison\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

bandNames = bandPow(1).bandNames;
nBands = numel(bandNames);

stats = struct('band', {}, 'group1', {}, 'group2', {}, ...
              'mean_g1', {}, 'sd_g1', {}, 'n_g1', {}, ...
              'mean_g2', {}, 'sd_g2', {}, 'n_g2', {}, ...
              't', {}, 'df', {}, 'p_ttest', {}, 'p_mw', {}, ...
              'significant', {});

k = 0;
for b = 1:nBands
    % Extract peak frequencies for this band from both groups
    peakFreq_g1 = bandPow(1).peakFreq(:, b);
    peakFreq_g2 = bandPow(2).peakFreq(:, b);

    % Remove NaN values
    peakFreq_g1 = peakFreq_g1(~isnan(peakFreq_g1));
    peakFreq_g2 = peakFreq_g2(~isnan(peakFreq_g2));

    if isempty(peakFreq_g1) || isempty(peakFreq_g2)
        continue;
    end

    % Calculate statistics
    k = k + 1;
    mean_g1 = mean(peakFreq_g1);
    sd_g1 = std(peakFreq_g1);
    n_g1 = numel(peakFreq_g1);

    mean_g2 = mean(peakFreq_g2);
    sd_g2 = std(peakFreq_g2);
    n_g2 = numel(peakFreq_g2);

    % T-test (Welch's for unequal variances)
    [t, df, p_ttest, d] = welch_ttest(peakFreq_g1, peakFreq_g2);

    % Mann-Whitney U test (non-parametric alternative)
    p_mw = ranksum(peakFreq_g1, peakFreq_g2);

    % Significance at alpha=0.05
    is_sig = (p_ttest < 0.05);

    % Store results
    stats(k).band = bandNames{b};
    stats(k).group1 = bandPow(1).name;
    stats(k).group2 = bandPow(2).name;
    stats(k).mean_g1 = mean_g1;
    stats(k).sd_g1 = sd_g1;
    stats(k).n_g1 = n_g1;
    stats(k).mean_g2 = mean_g2;
    stats(k).sd_g2 = sd_g2;
    stats(k).n_g2 = n_g2;
    stats(k).t = t;
    stats(k).df = df;
    stats(k).p_ttest = p_ttest;
    stats(k).p_mw = p_mw;
    stats(k).significant = is_sig;

    % Print results
    fprintf('%s band:\n', bandNames{b});
    fprintf('  %s: %.2f ± %.2f Hz (N=%d)\n', bandPow(1).name, mean_g1, sd_g1, n_g1);
    fprintf('  %s: %.2f ± %.2f Hz (N=%d)\n', bandPow(2).name, mean_g2, sd_g2, n_g2);
    fprintf('  Difference: %.2f Hz\n', abs(mean_g1 - mean_g2));
    fprintf('  T-test:     t(%.1f)=%.3f, p=%.3f %s\n', df, t, p_ttest, iif(is_sig, '*', 'n.s.'));
    fprintf('  Mann-Whitney: p=%.3f %s\n', p_mw, iif(p_mw < 0.05, '*', 'n.s.'));
    fprintf('  Cohen''s d: %.3f\n\n', d);
end

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('* p < 0.05 (significant)  |  n.s. = not significant (p >= 0.05)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

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

% Welch t and Satterthwaite df
se = sqrt(vx/nx + vy/ny);
t  = (mx - my) / se;
df = (vx/nx + vy/ny)^2 / ((vx/nx)^2/(nx-1) + (vy/ny)^2/(ny-1));

% Two-tailed p from Student t distribution using tcdf (more robust)
p = 2 * (1 - tcdf(abs(t), df));

% Cohen's d with pooled SD
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
