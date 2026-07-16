function [stats] = plotBandPower(cfg, bandPow)
% PLOTBANDPOWER  Plot per-band absolute/relative power distributions by group
%                and report between-group statistics.
%
% Produces ONE figure per requested band. Within a figure, absolute and/or
% relative power are shown as per-participant distributions for each group
% (jittered points + mean +/- SD), and the between-group comparison is reported
% following the coding preference in the 2023 ASD resting-state EEG
% meta-analysis: group mean/SD, Cohen's d, t-value and p-value.
%
% Statistics use Welch's two-sample t-test (unequal variances), appropriate for
% unequal group sizes (e.g. ASD vs NT). p-values are two-tailed and computed
% from the t distribution via BETAINC, so no Statistics Toolbox is required.
% Cohen's d uses the pooled standard deviation.
%
% INPUTS
%   cfg.bands            : which band(s) to plot. 'all' (default) or a band name / cellstr
%                          e.g. 'alpha' or {'alpha','gamma'}. Must match bandPow.bandNames.
%   cfg.measure          : 'both' (default), 'abs', or 'rel'.
%   cfg.colors           : (optional) nGroups x 3 RGB, one row per group in bandPow.
%   cfg.units            : (optional) char, y-label unit for absolute power (default 'power').
%   cfg.exclude_subjects : (optional) subject IDs to exclude from plot. Accepts:
%                          - numbers: [101, 102, 103]
%                          - cell of strings: {'A1', 'A2'} or {'101', '102'}
%                          - empty: no exclusions (default)
%                          Requires bandPow.subjects field with subject IDs.
%   cfg.subject_ids      : (optional) if bandPow doesn't have .subjects field,
%                          pass subject IDs as cell array here.
%   cfg.show_peak_freq   : (optional) logical, default false. If true and peakFreq is
%                          available in bandPow, display peak frequencies as text.
%
%   bandPow              : output of COMPUTEBANDPOWER. Length 1 (single group: distribution
%                          only, no between-group test) or >=2 (pairwise test between the
%                          first two groups). Preferably includes .subjects field with IDs.
%
% OUTPUT
%   stats : struct array (one per plotted band, per measure) with fields:
%     .band, .measure, .groups, .n, .mean, .sd, .cohend, .t, .df, .p
%
% Example:
%   cfg = []; cfg.bands = 'all'; cfg.measure = 'both';
%   stats = plotBandPower(cfg, bandPow);
%   cfg.bands = 'alpha'; plotBandPower(cfg, bandPow);   % one band
%   plotBandPower(cfg, bandPow(1));                     % one group

% ---- Defaults ----
if ~isfield(cfg, 'bands')   || isempty(cfg.bands);   cfg.bands   = 'all';  end
if ~isfield(cfg, 'measure') || isempty(cfg.measure); cfg.measure = 'both'; end
if ~isfield(cfg, 'units')   || isempty(cfg.units);   cfg.units   = 'power'; end
if ~isfield(cfg, 'exclude_subjects') || isempty(cfg.exclude_subjects)
    cfg.exclude_subjects = [];
end
% [ADDED] New option to display peak frequencies
if ~isfield(cfg, 'show_peak_freq') || isempty(cfg.show_peak_freq)
    cfg.show_peak_freq = false;
end

nGroups   = numel(bandPow);
bandNames = bandPow(1).bandNames;

% ---- Handle subject exclusion ----
exclude_idx_by_group = prepareExclusions(cfg, bandPow);
bandPow_orig_n = cellfun(@(g) sum(~isnan(bandPow(g).abs(:,1))), num2cell(1:nGroups));

% Which bands to plot
if ischar(cfg.bands) && strcmpi(cfg.bands, 'all')
    plotBands = bandNames;
elseif ischar(cfg.bands)
    plotBands = {cfg.bands};
else
    plotBands = cfg.bands;
end

% Which measures
switch lower(cfg.measure)
    case 'abs';  measures = {'abs'};
    case 'rel';  measures = {'rel'};
    otherwise;   measures = {'abs', 'rel'};
end

% Colors
if isfield(cfg, 'colors') && ~isempty(cfg.colors)
    colors = cfg.colors;
else
    colors = lines(nGroups);
end

groupNames = {bandPow.name};
stats = struct('band', {}, 'measure', {}, 'groups', {}, 'n', {}, ...
               'mean', {}, 'sd', {}, 'cohend', {}, 't', {}, 'df', {}, 'p', {});

% ---- One figure per band ----
for bi = 1:numel(plotBands)
    bIdx = find(strcmp(bandNames, plotBands{bi}), 1);
    if isempty(bIdx)
        warning('plotBandPower:unknownBand', 'Band "%s" not found; skipping.', plotBands{bi});
        continue
    end

    figure('Name', sprintf('%s band power', plotBands{bi}), 'Color', 'w');
    nSub = numel(measures);

    for mi = 1:nSub
        meas = measures{mi};
        ax = subplot(1, nSub, mi); hold(ax, 'on');

        % Gather each group's per-participant values for this band/measure
        vals = cell(1, nGroups);
        for g = 1:nGroups
            if strcmp(meas, 'abs')
                vals{g} = bandPow(g).abs(:, bIdx);
            else
                vals{g} = bandPow(g).rel(:, bIdx);
            end
            % Remove NaN values
            vals{g} = vals{g}(~isnan(vals{g}));
            % Remove excluded subjects
            if ~isempty(exclude_idx_by_group{g})
                vals{g}(exclude_idx_by_group{g}) = [];
            end
        end

        % Draw distributions
        for g = 1:nGroups
            drawDist(ax, g, vals{g}, colors(min(g, size(colors,1)), :));
        end

        % Axis cosmetics
        xlim(ax, [0.5, nGroups + 0.5]);
        xticks(ax, 1:nGroups);
        m  = cellfun(@mean, vals);
        sd = cellfun(@std,  vals);
        n  = cellfun(@numel, vals);
        % Single-line tick label per group (multi-line tick labels render
        % unreliably in MATLAB, so keep it to one line).
        % Include original N if subjects were excluded
        xtl = cell(nGroups, 1);
        for g = 1:nGroups
            if ~isempty(exclude_idx_by_group{g})
                n_excluded = numel(exclude_idx_by_group{g});
                xtl{g} = sprintf('%s (N=%d, %d excluded)', groupNames{g}, n(g), n_excluded);
            else
                xtl{g} = sprintf('%s (N=%d)', groupNames{g}, n(g));
            end
        end
        xticklabels(ax, xtl);
        % Print each group's mean +/- SD next to its mean line.
        for g = 1:nGroups
            text(ax, g + 0.22, m(g), sprintf('%.3g\\pm%.2g', m(g), sd(g)), ...
                 'Color', colors(min(g, size(colors,1)), :), 'FontSize', 8, ...
                 'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
                 'VerticalAlignment', 'middle');
        end
        if strcmp(meas, 'abs')
            ylabel(ax, sprintf('Absolute power (%s)', cfg.units));
            measLabel = 'Absolute';
        else
            ylabel(ax, 'Relative power (fraction)');
            measLabel = 'Relative';
        end

        % ---- Between-group statistics (first two groups) ----
        k = numel(stats) + 1;
        stats(k).band    = plotBands{bi};
        stats(k).measure = meas;
        stats(k).groups  = groupNames;
        stats(k).n       = n;
        stats(k).mean    = m;
        stats(k).sd      = sd;
        stats(k).cohend  = NaN;
        stats(k).t       = NaN;
        stats(k).df      = NaN;
        stats(k).p       = NaN;
        if nGroups >= 2
            [t, df, p, d] = welch_ttest(vals{1}, vals{2});
            stats(k).cohend = d; stats(k).t = t; stats(k).df = df; stats(k).p = p;
            title(ax, sprintf('%s %s\nt(%.1f)=%.2f, p=%.3g, d=%.2f %s', ...
                measLabel, plotBands{bi}, df, t, p, d, sigStars(p)), 'FontSize', 10);
            % significance bracket
            yl = ylim(ax);
            yr = yl(2) - yl(1);
            yb = yl(2) + 0.04*yr;
            plot(ax, [1 2], [yb yb], 'k-', 'LineWidth', 1);
            text(ax, 1.5, yb + 0.02*yr, sigStars(p), ...
                 'HorizontalAlignment', 'center', 'FontSize', 12);
            ylim(ax, [yl(1), yb + 0.10*yr]);
        else
            title(ax, sprintf('%s %s (N=%d)', measLabel, plotBands{bi}, n(1)), 'FontSize', 10);
        end

        % [ADDED] Display peak frequencies if available and requested
        if cfg.show_peak_freq && isfield(bandPow(1), 'peakFreq')
            yl = ylim(ax);
            yr = yl(2) - yl(1);
            ypos = yl(2) - 0.08*yr;
            peakFreq_str = 'Peak freq (Hz):  ';
            for g = 1:nGroups
                peak_val = nanmean(bandPow(g).peakFreq(:, bIdx));
                if ~isnan(peak_val)
                    peakFreq_str = sprintf('%s%s: %.1f', peakFreq_str, groupNames{g}, peak_val);
                    if g < nGroups; peakFreq_str = [peakFreq_str, '  |  ']; end
                end
            end
            text(ax, 0.5, ypos, peakFreq_str, 'FontSize', 8, 'Color', [0.4 0.4 0.4], ...
                 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                 'BackgroundColor', [0.95 0.95 0.95], 'EdgeColor', 'none', 'Margin', 3);
        end
    end

    sgtitle(sprintf('%s band', plotBands{bi}), 'FontWeight', 'bold');
end
end

% ======================================================================= %
function exclude_idx_by_group = prepareExclusions(cfg, bandPow)
% Prepare exclusion indices for each group based on cfg.exclude_subjects
% Returns cell array with exclusion indices per group
nGroups = numel(bandPow);
exclude_idx_by_group = cell(nGroups, 1);

if isempty(cfg.exclude_subjects)
    return;  % No exclusions
end

% Convert exclude_subjects to cell array of strings for flexible matching
exclude_list = cfg.exclude_subjects;
if isnumeric(exclude_list)
    exclude_list = cellfun(@num2str, num2cell(exclude_list), 'UniformOutput', false);
elseif ischar(exclude_list)
    exclude_list = {exclude_list};
elseif iscell(exclude_list)
    % Convert to strings if needed
    exclude_list = cellfun(@(x) iif(isnumeric(x), num2str(x), x), exclude_list, 'UniformOutput', false);
end

% Try to get subject IDs from bandPow or cfg
for g = 1:nGroups
    subject_ids = [];

    % Method 1: bandPow(g).subjects
    if isfield(bandPow(g), 'subjects')
        subject_ids = bandPow(g).subjects;
    % Method 2: cfg.subject_ids
    elseif isfield(cfg, 'subject_ids') && ~isempty(cfg.subject_ids)
        if iscell(cfg.subject_ids) && g <= numel(cfg.subject_ids)
            subject_ids = cfg.subject_ids{g};
        end
    end

    if isempty(subject_ids)
        warning('plotBandPower:noSubjectIDs', ...
            'Group %d: No subject IDs found. Skipping exclusions for this group.', g);
        continue;
    end

    % Convert subject_ids to strings for comparison
    if isnumeric(subject_ids)
        subject_ids = cellfun(@num2str, num2cell(subject_ids), 'UniformOutput', false);
    elseif ischar(subject_ids)
        subject_ids = {subject_ids};
    end
    if ~iscell(subject_ids)
        subject_ids = arrayfun(@num2str, subject_ids, 'UniformOutput', false);
    end

    % Find indices of subjects to exclude
    exclude_idx = false(numel(subject_ids), 1);
    for i = 1:numel(exclude_list)
        match_idx = find(strcmp(subject_ids, exclude_list{i}));
        if ~isempty(match_idx)
            exclude_idx(match_idx) = true;
        end
    end

    % Store as linear indices for removal
    exclude_idx_by_group{g} = find(exclude_idx);

    % Report exclusions
    n_excluded = numel(exclude_idx_by_group{g});
    if n_excluded > 0
        fprintf('Group "%s": Excluded %d subject(s): %s\n', ...
            bandPow(g).name, n_excluded, strjoin(exclude_list(ismember(exclude_list, subject_ids(exclude_idx))), ', '));
    end
end
end

% ======================================================================= %
function result = iif(condition, true_val, false_val)
% Inline if function
if condition
    result = true_val;
else
    result = false_val;
end
end

% ======================================================================= %
function drawDist(ax, xc, v, clr)
% Jittered points + mean line + SD whisker + light mean/SD box at position xc.
if isempty(v); return; end
n = numel(v);
jit = (rand(n,1) - 0.5) * 0.28;
scatter(ax, xc + jit, v, 28, clr, 'filled', ...
        'MarkerFaceAlpha', 0.5, 'MarkerEdgeColor', 'none');
mu = mean(v); sd = std(v);
% SD box
w = 0.18;
patch(ax, 'XData', xc + [-w -w w w], 'YData', mu + [-sd sd sd -sd], ...
      'FaceColor', clr, 'FaceAlpha', 0.12, 'EdgeColor', clr, 'LineWidth', 0.75);
% mean line
plot(ax, xc + [-w w], [mu mu], '-', 'Color', clr, 'LineWidth', 2.5);
end

% ======================================================================= %
function [t, df, p, d] = welch_ttest(x, y)
% Welch's two-sample t-test (unequal variances) + Cohen's d (pooled SD).
% Two-tailed p via the incomplete beta function (no Stats Toolbox needed).
x = x(~isnan(x)); y = y(~isnan(y));
nx = numel(x); ny = numel(y);
mx = mean(x);  my = mean(y);
vx = var(x);   vy = var(y);

% Welch t and Satterthwaite df
se = sqrt(vx/nx + vy/ny);
t  = (mx - my) / se;
df = (vx/nx + vy/ny)^2 / ((vx/nx)^2/(nx-1) + (vy/ny)^2/(ny-1));

% two-tailed p from Student t distribution
p = betainc(df/(df + t^2), df/2, 0.5);

% Cohen's d with pooled SD
sp = sqrt(((nx-1)*vx + (ny-1)*vy) / (nx + ny - 2));
d  = (mx - my) / sp;
end

% ======================================================================= %
function s = sigStars(p)
if     p < 0.001; s = '***';
elseif p < 0.01;  s = '**';
elseif p < 0.05;  s = '*';
else              s = 'n.s.';
end
end
