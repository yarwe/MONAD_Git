function plot_tfr_segment(EEG, varargin)
% PLOT_TFR_SEGMENT  Time-frequency heatmap of a short EEG segment.
%
% Computes a short-time Fourier transform spectrogram for each channel,
% averages power across channels, and plots a heatmap. A shaded band marks
% a suspected artifact zone so you can see whether elevated power is
% broadband (all frequencies) or confined to the high-frequency muscle band.
%
% Usage:
%   plot_tfr_segment(EEG)
%   plot_tfr_segment(EEG, 't_start', 847, 't_end', 852, ...
%                        'mark_start', 847.4, 'mark_end', 848)
%
% Optional name-value pairs:
%   't_start'    - segment start in seconds (default 847)
%   't_end'      - segment end   in seconds (default 852)
%   'mark_start' - left edge of suspected artifact zone (default 847.4)
%   'mark_end'   - right edge of suspected artifact zone (default 848)
%   'win_sec'    - STFT window length in seconds (default 0.25)
%                  Shorter → better time resolution; longer → better freq resolution
%   'overlap'    - STFT window overlap fraction 0–1 (default 0.95)
%   'f_max'      - highest frequency to display in Hz (default 100)
%   'chan_idx'   - channel indices to include (default: all)
%   'log_power'  - true (default) → dB scale; false → linear µV²/Hz
%   'fs'         - sampling frequency (default: EEG.fsample)

p = inputParser;
addParameter(p, 't_start',    847);
addParameter(p, 't_end',      852);
addParameter(p, 'mark_start', 847.4);
addParameter(p, 'mark_end',   848);
addParameter(p, 'win_sec',    0.25);
addParameter(p, 'overlap',    0.95);
addParameter(p, 'f_max',      100);
addParameter(p, 'chan_idx',   []);
addParameter(p, 'log_power',  true);
addParameter(p, 'fs',         []);
parse(p, varargin{:});
opt = p.Results;

fs = opt.fs;
if isempty(fs), fs = EEG.fsample; end

data   = EEG.trial{1};
nChans = size(data, 1);
nSamps = size(data, 2);

chan_idx = opt.chan_idx;
if isempty(chan_idx), chan_idx = 1:nChans; end

% Sample range
s1 = max(1,       round(opt.t_start * fs) + 1);
s2 = min(nSamps,  round(opt.t_end   * fs));
seg = data(chan_idx, s1:s2);

% Demean + detrend each channel
seg = detrend(seg', 'linear')';

%% Compute spectrogram (averaged across channels)
win_samps  = round(opt.win_sec * fs);
hop_samps  = max(1, round(win_samps * (1 - opt.overlap)));
win_vec    = hann(win_samps);

% Use first channel to get output sizes
[~, F, T, ~] = spectrogram(seg(1,:), win_vec, win_samps - hop_samps, [], fs);

% Keep only frequencies up to f_max
f_keep = F <= opt.f_max;
F      = F(f_keep);

% Accumulate power across channels
P_sum = zeros(sum(f_keep), numel(T));
for ch = 1:numel(chan_idx)
    [~, ~, ~, Pxx] = spectrogram(seg(ch,:), win_vec, win_samps - hop_samps, [], fs, 'power');
    P_sum = P_sum + Pxx(f_keep, :);
end
P_mean = P_sum / numel(chan_idx);   % mean power across channels

% Absolute time axis
T_abs = T + opt.t_start;

if opt.log_power
    P_plot = 10 * log10(P_mean + eps);
    cbar_label = 'Power (dB)';
else
    P_plot = P_mean;
    cbar_label = 'Power (\muV^2/Hz)';
end

%% Plot
figure('Name', 'Time-frequency heatmap', 'NumberTitle', 'off', ...
    'Position', [100 100 1000 500]);

imagesc(T_abs, F, P_plot);
axis xy;   % frequency increases upward
colormap(hot);
cb = colorbar;
ylabel(cb, cbar_label, 'FontSize', 11);
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title(sprintf('Mean spectral power across %d channels  |  window %.2f s, overlap %.0f%%', ...
    numel(chan_idx), opt.win_sec, opt.overlap * 100), 'FontSize', 11);

% Mark suspected artifact zone
hold on;
yl = ylim;
patch([opt.mark_start opt.mark_end opt.mark_end opt.mark_start], ...
    [yl(1) yl(1) yl(2) yl(2)], ...
    'w', 'FaceAlpha', 0, 'EdgeColor', 'none');   % dummy for legend

xline(opt.mark_start, 'c', 'LineWidth', 2, 'HandleVisibility', 'off');
xline(opt.mark_end,   'c', 'LineWidth', 2, 'HandleVisibility', 'off');

% Cyan fill between the two lines
yl = ylim;
patch([opt.mark_start opt.mark_end opt.mark_end opt.mark_start], ...
    [yl(1) yl(1) yl(2) yl(2)], ...
    'c', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Horizontal guide lines at canonical band boundaries
band_freqs = [0.5, 4, 8, 13, 30];
band_names = {'δ','θ','α','β','γ'};
for b = 1:numel(band_freqs)
    if band_freqs(b) <= opt.f_max
        yline(band_freqs(b), '--w', band_names{b}, ...
            'LineWidth', 0.8, 'FontSize', 9, ...
            'LabelHorizontalAlignment', 'left', ...
            'HandleVisibility', 'off');
    end
end

xlim([opt.t_start opt.t_end]);
set(gca, 'FontSize', 11, 'YDir', 'normal');
end
