%% fooof_walkthrough.m
% Step-by-step, numeric walkthrough of how FOOOF computes its estimates,
% on ONE real subject, printing the numbers at each stage and drawing the
% intermediate spectra. Mirrors the steps in fooof_fit.m / Fig. 2 of the paper.

clear; clc; close all;
load('fooof_psd_cache.mat','S1','f','lab1');
sidx = 1;                                    % subject to walk through
psd  = S1(:,sidx); ID = lab1{sidx};

% ---- settings (same as the analysis) ----
frange = [2 40];
peak_threshold = 1.5;                        % noise floor in units of SD
min_peak_height = 0.05;                      % absolute floor (log10 power)
std_lims = [1 6]/2;                          % SD limits from BW limits [1 6]
max_n_peaks = 6;

% ---- prep: select range, go to log10 power (semilog space) ----
sel = f>=frange(1) & f<=frange(2) & f>0 & isfinite(psd) & psd>0;
F  = f(sel); LP = log10(psd(sel)); res = median(diff(F));
fprintf('Subject %s : %d freqs, %.1f-%.1f Hz, resolution %.3f Hz\n', ...
    ID, numel(F), F(1), F(end), res);

%% STEP 1: initial aperiodic fit (seed from endpoints)
off0 = LP(1);
slope0 = (LP(end)-LP(1))/(log10(F(end))-log10(F(1)));
exp0 = max(-slope0,0.1);
fprintf('\nSTEP 1  seeds : offset0=%.3f  exponent0=%.3f\n', off0, exp0);
ap_init_p = ap_fit(F, LP, [off0 exp0]);
fprintf('        initial fit : offset=%.3f  exponent=%.3f\n', ap_init_p);
ap_init = ap_curve(F, ap_init_p);

%% STEP 2: robust aperiodic fit (use only non-peak baseline points)
flat0 = LP - ap_init; flat0(flat0<0) = 0;
thr = prctile_local(flat0, 2.5);
mask = flat0 <= thr;
ap_rob_p = ap_fit(F(mask), LP(mask), ap_init_p);
fprintf('STEP 2  robust fit : offset=%.3f  exponent=%.3f  (used %d/%d baseline pts)\n', ...
    ap_rob_p(1), ap_rob_p(2), nnz(mask), numel(F));
ap_rob = ap_curve(F, ap_rob_p);

%% STEP 3: flatten, then iterative peak search vs the NOISE floor
flat = LP - ap_rob;                          % aperiodic-adjusted spectrum
flat_iter = flat;
fprintf('\nSTEP 3  iterative peak search (threshold = %.2f x SD of flattened):\n', peak_threshold);
fprintf('  %-4s %-9s %-9s %-9s %-9s %-6s\n','it','peakF','height','SD','thresh','kept?');
guess = zeros(0,3); pk_marks = zeros(0,2);
for it = 1:max_n_peaks
    sd = std(flat_iter); th = peak_threshold*sd;
    [mx, ix] = max(flat_iter);
    kept = (mx>th) && (mx>min_peak_height);
    fprintf('  %-4d %-9.2f %-9.3f %-9.3f %-9.3f %-6s\n', it, F(ix), mx, sd, th, string(kept));
    if ~kept, break; end
    gc=F(ix); ga=mx;
    half=0.5*mx;
    li=find(flat_iter(1:ix)<=half,1,'last'); ri=find(flat_iter(ix:end)<=half,1,'first');
    if ~isempty(ri), ri=ri+ix-1; end
    if isempty(li), left=ix-1; else, left=ix-li; end
    if isempty(ri), right=numel(F)-ix; else, right=ri-ix; end
    gw=min(max((max(min(left,right),1)*2*res)/(2*sqrt(2*log(2))),std_lims(1)),std_lims(2));
    guess=[guess; gc ga gw]; pk_marks=[pk_marks; gc mx];      %#ok<AGROW>
    flat_iter = flat_iter - ga*exp(-(F-gc).^2./(2*gw^2));     % subtract & iterate
end
fprintf('  -> %d peak(s) seeded at: %s Hz\n', size(guess,1), num2str(guess(:,1)',' %.2f'));

%% STEP 4-8: authoritative full fit (fooof_fit does the joint refit + reporting)
cfg = struct('freq_range',frange,'aperiodic_mode','fixed','peak_width_limits',[1 6], ...
    'max_n_peaks',max_n_peaks,'min_peak_height',min_peak_height,'peak_threshold',peak_threshold);
R = fooof_fit(f, psd, cfg);
fprintf('\nFINAL estimates (fooof_fit):\n');
fprintf('  aperiodic : offset=%.3f   exponent=%.3f\n', R.offset, R.exponent);
fprintf('  %-3s %-8s %-8s %-8s\n','pk','CF(Hz)','PW','BW(Hz)');
for i=1:size(R.peak_params,1)
    fprintf('  %-3d %-8.3f %-8.3f %-8.3f\n', i, R.peak_params(i,1), R.peak_params(i,2), R.peak_params(i,3));
end
fprintf('  R^2=%.4f   MAE=%.4f\n', R.r_squared, R.error);

%% ---- figure: the pipeline ----
figure('Name','FOOOF walkthrough','Position',[80 80 1200 760]);

subplot(2,2,1); hold on;                     % step 1-2
plot(F,LP,'k','LineWidth',1.4);
plot(F,ap_init,'b--','LineWidth',1.3);
plot(F,ap_rob,'g-','LineWidth',1.8);
title('1-2: aperiodic fit (initial vs robust)'); xlabel('Hz'); ylabel('log_{10} power');
legend('spectrum','initial 1/f','robust 1/f','Location','southwest'); grid on; box on;

subplot(2,2,2); hold on;                     % step 3
plot(F,flat,'Color',[0.4 0.4 0.4],'LineWidth',1.4);
yline(peak_threshold*std(flat),'r--','1.5 x SD (noise floor)','LineWidth',1.3);
plot(pk_marks(:,1),pk_marks(:,2),'v','MarkerFaceColor',[1 .5 0],'MarkerEdgeColor','k','MarkerSize',9);
title('3: flattened spectrum + noise floor -> peaks'); xlabel('Hz'); ylabel('power above 1/f'); grid on; box on;

subplot(2,2,3); hold on;                      % final model
plot(R.freqs,R.log_spectrum,'k','LineWidth',1.4);
plot(R.freqs,R.fooofed_spectrum,'r','LineWidth',1.8);
plot(R.freqs,R.ap_fit,'b--','LineWidth',1.3);
for i=1:size(R.peak_params,1)
    cf=R.peak_params(i,1); yv=interp1(R.freqs,R.fooofed_spectrum,cf);
    plot(cf,yv,'v','MarkerFaceColor',[1 .5 0],'MarkerEdgeColor','k','MarkerSize',9);
end
title('Final model = 1/f + Gaussians'); xlabel('Hz'); ylabel('log_{10} power');
legend('spectrum','full model','aperiodic','Location','southwest'); grid on; box on;

subplot(2,2,4); axis off;                     % numbers
txt = sprintf(['Subject %s\n\nAPERIODIC\n  offset = %.3f\n  exponent = %.3f\n\nPEAKS (CF, PW, BW)\n'], ...
    ID, R.offset, R.exponent);
for i=1:size(R.peak_params,1)
    band = band_of(R.peak_params(i,1));
    txt = [txt sprintf('  %.2f Hz, %.3f, %.2f Hz  (%s)\n', R.peak_params(i,1), R.peak_params(i,2), R.peak_params(i,3), band)]; %#ok<AGROW>
end
txt = [txt sprintf('\nR^2 = %.4f   MAE = %.4f', R.r_squared, R.error)];
text(0.02,0.98,txt,'VerticalAlignment','top','FontSize',11,'FontName','FixedWidth');
sgtitle(sprintf('How FOOOF estimates are computed — subject %s', ID),'FontWeight','bold');
print(gcf,'_walkthrough.png','-dpng','-r95');

%% ---- local helpers (same math as fooof_fit) ----
function y = ap_curve(f,p), y = p(1) - p(2)*log10(f); end
function p = ap_fit(f,lp,seed)
opts=optimset('MaxFunEvals',5000,'MaxIter',5000,'Display','off');
p=fminsearch(@(q) sum((lp-(q(1)-q(2)*log10(f))).^2), seed, opts);
end
function v=prctile_local(x,p)
x=sort(x(:)); n=numel(x); if n==1, v=x; return; end
idx=(p/100)*(n-1)+1; lo=floor(idx); hi=ceil(idx);
if lo==hi, v=x(lo); else, v=x(lo)+(idx-lo)*(x(hi)-x(lo)); end
end
function b=band_of(cf)
if cf<4, b='delta'; elseif cf<8, b='theta'; elseif cf<=14, b='alpha';
elseif cf<=30, b='beta'; else, b='gamma'; end
end
