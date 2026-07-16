function plot_psd_channels(f, Pxx, varargin)
% PLOT_PSD_CHANNELS  Overlay per-channel power spectra with their mean.
%
% Plots every channel's PSD as a thin grey line and the across-channel
% average as a thick black line on top.
%
% Usage:
%   plot_psd_channels(f, Pxx)
%   plot_psd_channels(f, Pxx, 'log_power', true, 'f_max', 100)
%
% Inputs:
%   f    - frequency vector (nFreq x 1), from psd_nan
%   Pxx  - power matrix (nFreq x nChans), one column per channel
%
% Optional name-value pairs:
%   'log_power' - true (default) -> 10*log10 dB y-axis; false -> linear
%   'loglog'    - true (default) -> log frequency axis; false -> linear
%   'f_max'     - highest frequency to display in Hz (default: max(f))
%   'bands'     - true (default) -> draw canonical EEG band boundaries
%   'window_sec' - the window that was used to calculate, optional and
%   default is empty like there is no window at all

p = inputParser;
addParameter(p, 'log_power', true);
addParameter(p, 'loglog',    true);
addParameter(p, 'f_max',     []);
addParameter(p, 'bands',     true);
addParameter(p, 'window_sec',     []);
parse(p, varargin{:});
opt = p.Results;

f = f(:);
if isempty(opt.f_max), opt.f_max = max(f); end

% Keep frequencies up to f_max (drop DC for log axis)
keep = f <= opt.f_max & f > 0;
f    = f(keep);
Pxx  = Pxx(keep, :);

Pavg = mean(Pxx, 2, 'omitnan');

if opt.log_power
    Y      = 10 * log10(Pxx + eps);
    Yavg   = 10 * log10(Pavg + eps);
    ylab   = 'Power (dB)';
else
    Y      = Pxx;
    Yavg   = Pavg;
    ylab   = 'Power (\muV^2/Hz)';
end

figure('Name', 'Channel power spectra', 'NumberTitle', 'off', ...
    'Position', [100 100 900 550]);

% Grey per-channel lines (batch as one plot call)
hCh = plot(f, Y, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
hold on;
% Black average on top
hAvg = plot(f, Yavg, 'k', 'LineWidth', 2);

if opt.loglog
    set(gca, 'XScale', 'log');
end

xlabel('Frequency (Hz)');
ylabel(ylab);
title(sprintf('Power spectrum across %d channels', size(Pxx, 2)), 'FontSize', 11);
xlim([min(f) opt.f_max]);
grid on;
set(gca, 'FontSize', 11);

% Canonical EEG band boundaries
if opt.bands
    band_freqs = [4, 8, 13, 30];
    band_names = {'\theta','\alpha','\beta','\gamma'};
    yl = ylim;
    for b = 1:numel(band_freqs)
        if band_freqs(b) <= opt.f_max
            xline(band_freqs(b), '--', band_names{b}, ...
                'Color', [0.3 0.5 0.9], 'LineWidth', 0.8, 'FontSize', 9, ...
                'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
        end
    end
    ylim(yl);
end

legend([hCh(1) hAvg], {'Individual channels', 'Average'}, ...
    'Location', 'best');
if ~isempty(opt.window_sec)
    subtitle(sprintf('Window=%.2f seconds',opt.window_sec))
end
hold off;
end
