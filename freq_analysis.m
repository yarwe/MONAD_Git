clc; clear all; close all;
[env] = setupEnviroment('OSF_simple');
addpath(env.paths.LAVI);

%%
x = linspace(log(1), log(45), 60); % Logarithmic spacing
foi = exp(x);
%foi = 10.^(-0.1:0.03:1.67);   % I use this type of foi in my experiment

% set LAVI parameters
Lcfg = [];
Lcfg.foi = foi;
Lcfg.lag = 1.5;
Lcfg.width = 5;
Lcfg.fs    = env.data.fsample;
env.Lcfg = Lcfg;
% set fft parameters
Fcfg = [];
Fcfg.foi = foi;
Fcfg.output = 'pow';
Fcfg.channel = 'all';
Fcfg.method  = 'mtmfft';
Fcfg.taper   = 'hanning';
env.Fcfg = Fcfg;

%% add participants to LAVI/fft arrays
[LAVI_arr, FFT_arr] = freqanalysis_array(env,{21, 27});

%% load LAVI/fft participant arrays
LAVI_arr = load([env.paths.preproc 'LAVI_arr']).LAVI_arr;
FFT_arr  = load([env.paths.preproc 'FFT_arr']).FFT_arr;
N = length(env.data.clean_files);
%%
chosen_ch = {'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'};
% average FFT over participants
cfg = [];
cfg.keepindividual = 'yes';
fft_GA = ft_freqgrandaverage(cfg, FFT_arr{:});
fft_GA.sd = log10(squeeze(std(fft_GA.powspctrm,1))); 
fft_GA.powspctrm = log10(squeeze(mean(fft_GA.powspctrm,1)));


% average LAVI over participants
strct = LAVI_arr{1};
allCels = cellfun(@(s) s.powspctrm, LAVI_arr, 'UniformOutput', false);
allCels = cat(3, allCels{:});
strct.powspctrm = nanmean(allCels, 3);
strct.sd = nanstd(allCels, 0, 3);
LAVI_GA = strct;

% average over electrodes
cfg             = [];
cfg.channel     = chosen_ch;
cfg.avgoverchan = 'yes';
cfg.nanmean     = 'yes';

LAVI_EA = ft_selectdata(cfg,LAVI_GA);
fft_EA  = ft_selectdata(cfg,fft_GA);  

%% plot GA LAVI
close all
lineC = [243, 212, 184]/255;

figure;
plot(Lcfg.foi, LAVI_EA.powspctrm, 'LineWidth', 3)
hold on
fill([foi, flip(foi)], [(LAVI_EA.powspctrm), ...
    (flip(LAVI_EA.powspctrm+(LAVI_EA.sd)))],lineC, ...
    'FaceAlpha', 0.2, 'EdgeAlpha', 0.8);
fill([foi, flip(foi)], [(LAVI_EA.powspctrm), ...
    (flip(LAVI_EA.powspctrm-(LAVI_EA.sd)))], lineC,...
    'FaceAlpha', 0.2, 'EdgeAlpha', 0.8);
title({['LAVI spectrum, N=', num2str(N)], ...
    ['electrodes: ', strjoin(chosen_ch, ', ')]}, 'FontSize', 12);
xlabel('Frequency');
ylabel('LAVI');
set(gca, 'XScale', 'log');  % Set logarithmic x-axis
xlim([foi(1), foi(end)]);
xticks([foi(1:5:end) foi(end)]);  
%xticks([1:5:round(foi(end))])
xticklabels([string(round(foi(1:5:end),1)) foi(end)]);  
axis square;
saveas(gcf, [env.paths.preproc 'LAVI_spectrum.png']);

%% plot GA FFT
figure; hold on;
lineC = [0.0745, 0.6235, 1];
xlim([foi(1), foi(end)]);
plot(Fcfg.foi,fft_EA.powspctrm,'LineWidth', 3);
fill([Fcfg.foi, flip(Fcfg.foi)], [(fft_EA.powspctrm), ...
    flip((fft_EA.powspctrm+fft_EA.sd))],lineC, ...
    'FaceAlpha', 0.2, 'EdgeAlpha', 0.8);
fill([Fcfg.foi, flip(Fcfg.foi)], [(fft_EA.powspctrm), ...
    flip((fft_EA.powspctrm -fft_EA.sd))],lineC, ...
    'FaceAlpha', 0.2, 'EdgeAlpha', 0.8);
title({['fft spectrum, N=', num2str(N)], ...
    ['electrodes: ', strjoin(chosen_ch, ', ')]}, 'FontSize', 12);
set(gca, 'XScale', 'log');  % Set logarithmic x-axis
xticks([foi(1:5:end) foi(end)]);  
xticklabels([string(round(foi(1:5:end),1)) foi(end)]);  
ylabel('log power')
axis square
saveas(gcf, [env.paths.preproc 'fft_spectrum.png']);


