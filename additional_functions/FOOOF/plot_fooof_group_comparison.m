function stats = plot_fooof_group_comparison(G1, G2)
% PLOT_FOOOF_GROUP_COMPARISON  Compare FOOOF parameters between two groups.
%
% Produces one figure with five panels, one per parameter:
%   alpha center frequency, alpha power, alpha bandwidth, aperiodic offset,
%   aperiodic exponent. Each panel shows individual subjects (jittered dots),
%   the group mean +/- SEM, and the between-group test result.
%
% For every parameter it runs a two-sample t-test and a Mann-Whitney U test
% (rank-sum), and reports Cohen's d. Results are printed and returned.
%
% INPUTS
%   G1, G2 - outputs of fooof_group for the two groups
%
% OUTPUT
%   stats  - struct array (one element per parameter) with fields:
%            name, m1, m2, sd1, sd2, n1, n2, t, df, p_t, p_mw, cohen_d
%
% See also: fooof_group, plot_fooof_group_fits

c1 = group_color(G1, [0.00 0.45 0.74]);   % group 1 color (falls back to blue)
c2 = group_color(G2, [0.85 0.33 0.10]);   % group 2 color (falls back to orange)
n1name = getname(G1,'Group 1'); n2name = getname(G2,'Group 2');

params = { ...
    'alpha_cf', 'Alpha center freq (Hz)'; ...
    'alpha_pw', 'Alpha power (a.u.)'; ...
    'alpha_bw', 'Alpha bandwidth (Hz)'; ...
    'offset',   'Aperiodic offset'; ...
    'exponent', 'Aperiodic exponent'};

figure('Name','FOOOF group comparison','NumberTitle','off','Position',[60 80 1500 430]);
stats = struct([]);

for i = 1:size(params,1)
    fld = params{i,1}; lab = params{i,2};
    x1 = G1.(fld); x1 = x1(isfinite(x1));
    x2 = G2.(fld); x2 = x2(isfinite(x2));

    % --- statistics ---
    s.name = lab; s.n1 = numel(x1); s.n2 = numel(x2);
    s.m1 = mean(x1); s.m2 = mean(x2);
    s.sd1 = std(x1); s.sd2 = std(x2);
    [s.t, s.df, s.p_t]  = ttest2_local(x1, x2);
    s.p_mw   = ranksum_safe(x1, x2);
    sp = sqrt(((s.n1-1)*s.sd1^2 + (s.n2-1)*s.sd2^2) / max(s.n1+s.n2-2,1));
    s.cohen_d = (s.m1 - s.m2) / sp;
    if i == 1, stats = s; else, stats(i) = s; end %#ok<AGROW>

    % --- plot ---
    subplot(1, size(params,1), i); hold on;
    jitter_scatter(1, x1, c1);
    jitter_scatter(2, x2, c2);
    errbar(1, x1, c1);
    errbar(2, x2, c2);

    set(gca,'XTick',[1 2],'XTickLabel',{n1name, n2name},'FontSize',10);
    xlim([0.4 2.6]); ylabel(lab); grid on; box on;

    % significance annotation (prefer t-test; * markers)
    star = sig_star(s.p_t);
    yl = ylim; ytop = yl(2) + 0.10*diff(yl);
    plot([1 2],[ytop ytop],'k-','LineWidth',1);
    text(1.5, ytop, sprintf('%s p=%.3f', star, s.p_t), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9);
    ylim([yl(1), ytop + 0.12*diff(yl)]);
    title(sprintf('d = %.2f', s.cohen_d), 'FontSize',10);
end

sgtitle(sprintf('FOOOF parameter comparison:  %s (N=%d)  vs  %s (N=%d)', ...
    n1name, numel(G1.offset), n2name, numel(G2.offset)), 'FontWeight','bold');

% --- console report ---
fprintf('\n================ FOOOF group comparison ================\n');
fprintf('%-22s %12s %12s %8s %8s %8s\n', 'Parameter', ...
    [n1name ' (m)'], [n2name ' (m)'], 't', 'p(t)', 'd');
for i = 1:numel(stats)
    fprintf('%-22s %12.3f %12.3f %8.2f %8.3f %8.2f\n', stats(i).name, ...
        stats(i).m1, stats(i).m2, stats(i).t, stats(i).p_t, stats(i).cohen_d);
    fprintf('%22s Mann-Whitney U p = %.3f\n', '', stats(i).p_mw);
end
fprintf('========================================================\n');
end

% ----------------------------- helpers -----------------------------------
function jitter_scatter(xc, y, col)
xj = xc + (rand(numel(y),1)-0.5)*0.18;
scatter(xj, y, 42, col, 'filled', 'MarkerFaceAlpha',0.55, 'HandleVisibility','off');
end

function errbar(xc, y, col)
m = mean(y); e = std(y)/sqrt(max(numel(y),1));
plot([xc-0.22 xc+0.22],[m m],'-','Color',col*0.7,'LineWidth',3);
plot([xc xc],[m-e m+e],'-','Color',col*0.7,'LineWidth',1.5);
end

function name = getname(G, dflt)
name = G.group_name; if isempty(name), name = dflt; end
end

function c = group_color(G, dflt)
if isfield(G,'color') && ~isempty(G.color), c = G.color; else, c = dflt; end
end

function s = sig_star(p)
if     p < 0.001, s = '***';
elseif p < 0.01,  s = '**';
elseif p < 0.05,  s = '*';
else,             s = 'n.s.';
end
end

function [t, df, p] = ttest2_local(x, y)
% Welch's two-sample t-test (no toolbox dependency).
x = x(:); y = y(:); nx = numel(x); ny = numel(y);
if nx < 2 || ny < 2, t = NaN; df = NaN; p = NaN; return; end
vx = var(x); vy = var(y);
t  = (mean(x) - mean(y)) / sqrt(vx/nx + vy/ny);
df = (vx/nx + vy/ny)^2 / ((vx/nx)^2/(nx-1) + (vy/ny)^2/(ny-1));
if exist('tcdf','file'), p = 2*(1 - tcdf(abs(t), df));
else,                    p = NaN; end   % needs Statistics Toolbox for exact p
end

function p = ranksum_safe(x, y)
if exist('ranksum','file') && numel(x) >= 1 && numel(y) >= 1
    try, p = ranksum(x, y); catch, p = NaN; end
else
    p = NaN;
end
end
