function plot_fooof_fit(res, ttl)
% PLOT_FOOOF_FIT  Show a single FOOOF model fit (data, aperiodic, full model, peaks).
%
% Reproduces the style of Fig. 2h in Donoghue et al. (2020): the original
% log-power spectrum with the aperiodic fit and the full periodic+aperiodic
% model overlaid, and the alpha (and other) peaks marked.
%
% INPUTS
%   res - output struct from fooof_fit
%   ttl - (optional) title string
%
% See also: fooof_fit, plot_fooof_group_fits

if nargin < 2 || isempty(ttl), ttl = 'FOOOF model fit'; end

f  = res.freqs;
lp = res.log_spectrum;

figure('Name','FOOOF fit','NumberTitle','off','Position',[100 100 780 520]);
hold on;

hData  = plot(f, lp,               'k-',  'LineWidth', 1.6);
hModel = plot(f, res.fooofed_spectrum, 'r-', 'LineWidth', 1.8);
hAp    = plot(f, res.ap_fit,       'b--', 'LineWidth', 1.5);

% Mark each fitted peak at its center frequency, on the full model curve
pk = res.peak_params;                        % [CF PW BW]
for i = 1:size(pk,1)
    cf = pk(i,1);
    yv = interp1(f, res.fooofed_spectrum, cf);
    plot(cf, yv, 'v', 'MarkerFaceColor', [1 0.5 0], 'MarkerEdgeColor','k', 'MarkerSize',8);
    text(cf, yv, sprintf('  %.1f Hz', cf), 'FontSize', 9, 'VerticalAlignment','bottom');
end

xlabel('Frequency (Hz)');
ylabel('log_{10} Power');
title(ttl, 'Interpreter','none');
grid on; box on; set(gca,'FontSize',11);
xlim([f(1) f(end)]);

% Parameter annotation box
if isempty(pk)
    peakStr = 'peaks: none';
else
    peakStr = sprintf('alpha/peaks (CF,PW,BW):\n');
    for i = 1:size(pk,1)
        peakStr = [peakStr sprintf('  %.1f Hz, %.2f, %.1f Hz\n', pk(i,1), pk(i,2), pk(i,3))]; %#ok<AGROW>
    end
end
if isnan(res.knee), kneeStr = ''; else, kneeStr = sprintf(', knee=%.2f', res.knee); end
annStr = sprintf('offset = %.2f\nexponent = %.2f%s\nR^2 = %.3f, MAE = %.3f\n%s', ...
    res.offset, res.exponent, kneeStr, res.r_squared, res.error, peakStr);
xl = xlim; yl = ylim;
text(xl(1)+0.55*diff(xl), yl(1)+0.95*diff(yl), annStr, ...
    'VerticalAlignment','top', 'FontSize', 9, 'BackgroundColor',[1 1 1 0.6], ...
    'EdgeColor',[0.7 0.7 0.7]);

legend([hData hModel hAp], {'Original spectrum','Full model fit','Aperiodic fit'}, ...
    'Location','southwest');
hold off;
end
