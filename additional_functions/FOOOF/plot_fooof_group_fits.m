function plot_fooof_group_fits(G1, G2)
% PLOT_FOOOF_GROUP_FITS  Overlay individual + mean FOOOF fits for each group.
%
% For each group, plots every subject's full model fit (thin, faded), the
% group-mean model fit (thick), and the group-mean aperiodic fit (dashed).
% A third panel overlays the two group-mean models + aperiodic components so
% the groups can be compared spectrum-wide.
%
% INPUTS
%   G1 - output of fooof_group for group 1
%   G2 - output of fooof_group for group 2
%
% Assumes both groups were fit over the SAME frequency vector (same fs and
% window), which holds when the PSDs were computed identically.
%
% See also: fooof_group, plot_fooof_group_comparison

c1 = group_color(G1, [0.00 0.45 0.74]);   % group 1 color (falls back to blue)
c2 = group_color(G2, [0.85 0.33 0.10]);   % group 2 color (falls back to orange)

[f1, M1, A1] = collect_curves(G1);
[f2, M2, A2] = collect_curves(G2);

n1 = strtrim_name(G1.group_name, 'Group 1');
n2 = strtrim_name(G2.group_name, 'Group 2');

figure('Name','FOOOF group fits','NumberTitle','off','Position',[80 80 1350 460]);

% ---- Panel 1: group 1 ----
subplot(1,3,1); hold on;
plot(f1, M1, 'Color',[c1 0.20], 'LineWidth',0.5);                 % individuals
plot(f1, mean(M1,2,'omitnan'), 'Color',c1, 'LineWidth',2.4);      % mean model
plot(f1, mean(A1,2,'omitnan'), '--','Color',c1*0.6,'LineWidth',1.8); % mean aperiodic
finish_panel(sprintf('%s  (N=%d)', n1, size(M1,2)));

% ---- Panel 2: group 2 ----
subplot(1,3,2); hold on;
plot(f2, M2, 'Color',[c2 0.20], 'LineWidth',0.5);
plot(f2, mean(M2,2,'omitnan'), 'Color',c2, 'LineWidth',2.4);
plot(f2, mean(A2,2,'omitnan'), '--','Color',c2*0.6,'LineWidth',1.8);
finish_panel(sprintf('%s  (N=%d)', n2, size(M2,2)));

% ---- Panel 3: mean model + mean aperiodic, both groups ----
subplot(1,3,3); hold on;
h1 = plot(f1, mean(M1,2,'omitnan'), 'Color',c1, 'LineWidth',2.4);
h2 = plot(f2, mean(M2,2,'omitnan'), 'Color',c2, 'LineWidth',2.4);
plot(f1, mean(A1,2,'omitnan'), '--','Color',c1*0.6,'LineWidth',1.6);
plot(f2, mean(A2,2,'omitnan'), '--','Color',c2*0.6,'LineWidth',1.6);
finish_panel('Group mean fits (solid) + aperiodic (dashed)');
legend([h1 h2], {n1, n2}, 'Location','southwest');

sgtitle('FOOOF fits by group', 'FontWeight','bold');
end

% ----------------------------- helpers -----------------------------------
function [f, M, A] = collect_curves(G)
% Stack each subject's model and aperiodic curves into nFreq x nSubj matrices.
f = G.fits(1).r.freqs;
n = numel(G.fits);
M = nan(numel(f), n); A = nan(numel(f), n);
for s = 1:n
    r = G.fits(s).r;
    if numel(r.freqs) == numel(f)
        M(:,s) = r.fooofed_spectrum;
        A(:,s) = r.ap_fit;
    end
end
end

function finish_panel(ttl)
xlabel('Frequency (Hz)'); ylabel('log_{10} Power');
title(ttl, 'Interpreter','none'); grid on; box on; set(gca,'FontSize',10);
axis tight;
end

function s = strtrim_name(s, dflt)
if isempty(s), s = dflt; end
end

function c = group_color(G, dflt)
if isfield(G,'color') && ~isempty(G.color), c = G.color; else, c = dflt; end
end
