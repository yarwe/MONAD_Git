function [pxx, f] = psd_nan(x, fs, win_sec, overlap, print_window_info)
% PSD from a signal with NaN gaps: Welch over NaN-free windows only.
%   x        - 1 x N signal (may contain NaN)
%   fs       - sampling rate (Hz)
%   win_sec  - window length in seconds (e.g. 2)
%   overlap  - fraction 0-1 (e.g. 0.5)
% print_window_info - 1: yes, 0: no.
    L    = round(win_sec * fs);
    hop  = max(1, round(L * (1 - overlap)));
    w    = hann(L);
    U    = sum(w.^2);                 % window power, for correct scaling
    nfft = L;
    f    = (0:floor(nfft/2)) * fs / nfft;

    P = zeros(numel(f), 1);
    k = 0;
    for s = 1:hop:(numel(x) - L + 1)
        seg = x(s : s + L - 1);
        if any(isnan(seg)), continue; end        % skip contaminated windows
        seg = detrend(seg(:), 'linear') .* w;    % detrend + taper
        X   = fft(seg, nfft);
        Pxx = (abs(X(1:numel(f))).^2) / (fs * U); % PSD scaling (V^2/Hz)
        Pxx(2:end-1) = 2 * Pxx(2:end-1);          % one-sided
        P = P + Pxx; % Acuumlates
        k = k + 1;
    end
    pxx = P / max(k, 1); % here it computes the mean over all windows
    
    if print_window_info
        % ---- report what was actually used --------------------------------
        total_win = numel(1:hop:(numel(x) - L + 1));  % windows attempted
        fprintf(['psd_nan: %d of %d windows were NaN-free and used ' ...
                 '(%.1f%%).\n'], k, total_win, 100 * k / max(total_win, 1));
        fprintf(['         window length = %.3f s (%d samples), ' ...
                 'overlap = %.0f%%.\n'], win_sec, L, 100 * overlap);
        fprintf('         total clean time analysed = %.1f s.\n', k * win_sec);
        % -------------------------------------------------------------------
    end
    if k == 0, warning('No NaN-free windows found — try a shorter window.'); end
end