%% compare_fooof_implementations.m
% Verify my native-MATLAB FOOOF (fooof_fit.m) against the OFFICIAL FOOOF
% implementation, by running both on identical power spectra and comparing
% the recovered parameters.
%
% The official code is the `fooof_mat` MATLAB wrapper (in ./fooof_mat/), which
% does NOT reimplement anything -- it calls the real Python `fooof` package
% through MATLAB's Python bridge. So this script requires:
%   * Python (3.8-3.10 for MATLAB R2023a) with `fooof` + `numpy` installed
%   * MATLAB configured to use that Python (handled below via pyenv)
%
% What it does:
%   1. Points MATLAB at your Python and checks fooof is importable.
%   2. Simulates spectra with KNOWN ground-truth parameters.
%   3. Fits each spectrum with BOTH implementations using identical settings.
%   4. Reports ground truth vs mine vs official, and the mine-vs-official
%      differences (this is the actual verification).
%   5. Overlays both model fits on one example spectrum.
%
% If the two implementations agree to ~1e-2 on the aperiodic exponent/offset
% and the alpha peak parameters, my implementation is validated.

clear; clc; close all;

%% -------------------- 0. Point MATLAB at Python --------------------
% Edit this to your Python executable if different. Out-of-process execution
% avoids numpy/MKL library clashes with MATLAB.
PYEXE = 'C:\Users\yarde\AppData\Local\Programs\Python\Python38\python.exe';

try
    pe = pyenv;
    if pe.Status ~= "Loaded" || ~strcmp(char(pe.Executable), PYEXE)
        pe = pyenv('Version', PYEXE, 'ExecutionMode', 'OutOfProcess');
    end
catch ME
    warning(ME.identifier, '%s', ME.message);
    pe = pyenv;
end
fprintf('Using Python: %s (%s)\n', char(pe.Executable), char(pe.Version));

% Check that fooof imports
try
    fmod = py.importlib.import_module('fooof');
    fv = char(py.getattr(fmod, '__version__'));   % dunder attr: needs getattr, not dot
    fprintf('Python fooof version: %s\n', fv);
catch
    error(['Could not import Python ''fooof''. Install it into the Python above:\n' ...
           '   "%s" -m pip install fooof\n' ...
           'then rerun this script.'], PYEXE);
end

addpath(fullfile(pwd, 'fooof_mat'));   % official wrapper

%% -------------------- 1. Identical settings for both --------------------
f_range = [2 40];
settings = struct('peak_width_limits',[1 6], 'max_n_peaks',6, ...
                  'min_peak_height',0.05, 'peak_threshold',1.5, ...
                  'aperiodic_mode','fixed', 'verbose',false);

% Same settings as a cfg for my implementation
mycfg = settings; mycfg.freq_range = f_range; mycfg.alpha_band = [7 14];

%% -------------------- 2. Simulated spectra (known truth) --------------------
f = (0:0.5:60)'; f(1) = [];
rng(42);
% ground truth per spectrum: [offset exponent | alphaCF alphaPW alphaBW]
truth = [ -21.5 1.40  10.0 0.55 1.2 ;
          -21.5 1.00   9.0 0.40 1.4 ;
          -20.0 1.70  11.0 0.60 2.0 ;
          -22.0 0.80   8.5 0.35 1.6 ;
          -21.0 1.20  10.5 0.50 1.0 ];
nS = size(truth,1);
specs = zeros(numel(f), nS);
for s = 1:nS
    off = truth(s,1); ex = truth(s,2);
    cf = truth(s,3); pw = truth(s,4); bw = truth(s,5);
    logp = off - ex*log10(f) + pw*exp(-(f-cf).^2 ./ (2*(bw/2)^2));
    specs(:,s) = 10.^(logp + 0.015*randn(numel(f),1));
end

%% -------------------- 3. Fit with both, collect params --------------------
rows = strings(0,1);
T = table();
first_mine = []; first_off = [];
for s = 1:nS
    % --- mine ---
    rm = fooof_fit(f, specs(:,s), mycfg);
    a_mine = pick_alpha(rm.peak_params, mycfg.alpha_band);

    % --- official (Python fooof via wrapper) ---
    ro = fooof(f', specs(:,s)', f_range, settings, true);   % row vectors
    a_off = pick_alpha(ro.peak_params, mycfg.alpha_band);
    % official aperiodic_params = [offset exponent] (fixed mode)
    off_off = ro.aperiodic_params(1); exp_off = ro.aperiodic_params(end);

    if s == 1, first_mine = rm; first_off = ro; end

    T = [T; { s, ...
        truth(s,2), rm.exponent, exp_off, rm.exponent-exp_off, ...
        truth(s,1), rm.offset,   off_off, rm.offset-off_off, ...
        truth(s,3), a_mine(1),   a_off(1), a_mine(1)-a_off(1), ...
        a_mine(2),  a_off(2),    a_mine(2)-a_off(2), ...
        a_mine(3),  a_off(3),    a_mine(3)-a_off(3) } ]; %#ok<AGROW>
end
T.Properties.VariableNames = { 'spec', ...
    'exp_true','exp_mine','exp_off','exp_dMineOff', ...
    'off_true','off_mine','off_off','off_dMineOff', ...
    'aCF_true','aCF_mine','aCF_off','aCF_dMineOff', ...
    'aPW_mine','aPW_off','aPW_dMineOff', ...
    'aBW_mine','aBW_off','aBW_dMineOff'};

disp('===== Ground truth vs mine vs official (and mine-official diffs) =====');
disp(T);

fprintf('\nMax |mine - official| across spectra:\n');
fprintf('   exponent : %.4f\n', max(abs(T.exp_dMineOff)));
fprintf('   offset   : %.4f\n', max(abs(T.off_dMineOff)));
fprintf('   alpha CF : %.4f Hz\n', max(abs(T.aCF_dMineOff)));
fprintf('   alpha PW : %.4f\n', max(abs(T.aPW_dMineOff)));
fprintf('   alpha BW : %.4f Hz\n', max(abs(T.aBW_dMineOff)));

%% -------------------- 4. Overlay both model fits (example) --------------------
figure('Name','Mine vs official FOOOF','NumberTitle','off','Position',[100 100 800 540]);
hold on;
% NOTE: the official wrapper returns fooofed_spectrum / ap_fit already in
% log10-power units (FOOOF works in log space), so they are plotted directly.
plot(first_mine.freqs, first_mine.log_spectrum, 'k-', 'LineWidth',1.6);
plot(first_mine.freqs, first_mine.fooofed_spectrum, 'r-', 'LineWidth',2.0);
plot(first_off.freqs,  first_off.fooofed_spectrum, 'c--', 'LineWidth',1.8);
plot(first_mine.freqs, first_mine.ap_fit, 'b:', 'LineWidth',1.5);
plot(first_off.freqs,  first_off.ap_fit, 'm:', 'LineWidth',1.5);
xlabel('Frequency (Hz)'); ylabel('log_{10} Power'); grid on; box on;
legend({'Data','Mine: full model','Official: full model', ...
        'Mine: aperiodic','Official: aperiodic'}, 'Location','southwest');
title(sprintf('Spectrum 1: mine vs official (max model diff = %.2e log10-power)', ...
    max(abs(first_mine.fooofed_spectrum(:) - first_off.fooofed_spectrum(:)))));

fprintf('\nVerification done. Small diffs (<~1e-2) confirm the implementation.\n');

%% -------------------- helper --------------------
function a = pick_alpha(pk, band)
% Return [CF PW BW] of the highest-power peak in band, or NaNs if none.
a = [NaN NaN NaN];
if isempty(pk), return; end
in = pk(:,1) >= band(1) & pk(:,1) <= band(2);
if ~any(in), return; end
cand = pk(in,:); [~,k] = max(cand(:,2)); a = cand(k,:);
end
