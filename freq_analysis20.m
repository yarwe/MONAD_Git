%% Clear all 
clear all;
clc; close all;

%% load enviroment and folder paths according to the experiment
% The experiment (and the MONAD_Git folder) are set in config_local.m,
% see config_template.m. Experiment names: 'OSF', 'TalKennet',
% 'NMSG', 'SFARI_EEG_multi',
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)
% Pardigm- 'tactile','auditory', 'simple', 'rest' etc.

env = setupEnviroment11();
cd(env.paths.git)
addpath(env.paths.extra_func); addpath(fullfile(env.paths.ft_path, 'external', 'eeglab'));

% clean previous data to not create confusions
clear EEG pEEG_zclean pEEG_mcleanCh pEEG pEEG_mclean man_art2 man_art comp badCh Mart dat_after_ICA
% clear weird stuff that comes when you load EEGlab data
clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

addpath(env.paths.LAVI);

%% Add relevant paths- e.g., LAVI etc.
addpath(env.paths.LAVI)

%% Set parameters for LAVI and FFT
clc;

foi = 1:0.5:90;

% set LAVI parameters
Lcfg = [];
Lcfg.foi = foi;
Lcfg.lag = 1.5;
Lcfg.width = 5;
Lcfg.fs    = env.data.fsample;

% If was down-sample
if Lcfg.fs>800  
    Lcfg.fs = Lcfg.fs/2;
    warning('Sampling rate was higher than accepted, assumed half of it.')
end

% set fft parameters
Fcfg = [];
Fcfg.foi = foi;
Fcfg.output = 'pow';
Fcfg.channel ='all' ;
Fcfg.method  = 'mtmfft';
Fcfg.pad = 'nextpow2';
Fcfg.taper   = 'hanning';

%% Add participants to LAVI/fft arrays
% creates a cell array. for each participant, a cell is created with his
% LAVI and FFT analyses.
% cfg.prev  whether to add a new participant to a previous cell array or to
%           runn all the participants and create a new cell array for all
%           of them.
% cfg.Lcfg  the Lavi cfg with the parameters chosen above.
% cfg.Fcfg  the Fft cfg with the parameters chosen above.
% return:   1. LAVI_arr: a cell array with the LAVI analysis of each
%              participant. Each cell of the array contains:
%                  - ID: the ID of the participant
%                  - noise: a sturcture containing pink noise
%                    stimulations for this participant.
cfg = [];
cfg.env = env;
cfg.Lcfg = Lcfg;
cfg.Fcfg = Fcfg;
cfg.prev = 'all'; % add to existing dataframe? 'add' = (add to df), 'all' = run all participants
[LAVI_arr, FFT_arr] = create_datArr21(cfg);

%% load LAVI/fft participant arrays
LAVI_arr = load([env.paths.preproc 'LAVI_arr']).LAVI_arr;
FFT_arr  = load([env.paths.preproc 'FFT_arr']).FFT_arr;
N = length(env.data.clean_files);
nchans=length(LAVI_arr{1}.label);

%% Division to groups (ASD, NT, SCZ) - LAVI and FFT with grand averages
exp_groups = {'ASD', 'NT'};
groups = groupDataByExperiment(env, LAVI_arr, FFT_arr, exp_groups);

%% Possible channel clusters
chosen_ch = {'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'};
pari_chans={'P1', 'P2', 'Pz', 'P3', 'P4', 'CP1','CPz', 'CP2', 'CP3', 'CP4'}; % Parietal channels
occi_chans={'O1', 'Oz', 'O2'}; % Occipital
pari_occi_chans={'PO3', 'POz', 'PO4', 'PO7', 'PO8'}; %Parieto-Occipital
central_chans={'Cz', 'C1', 'C2', 'C3', 'C4'};
post_mid={'CPz', 'Pz', 'POz', 'Oz'};
post_left={'CP3', 'P3', 'P7','TP7', 'PO7', 'O1'};
post_right={'CP4', 'P4', 'P8','TP8', 'PO8', 'O2'};
% According to the paper of Shen et al. (2023), "resting-state activity in children.."
% Parietal ROI (For Low-Alpha: 8–9 Hz); 
% Ventral / Occipital-Temporal ROI (For High-Alpha: 11–12 Hz)
% Central ROI (For Control / Topography Checks)

%% Choose noise channel for LAVI
noise_chan = 'Cz';

%% find LAVI peaks
% For all channels
cfg = [];
cfg.use_noise_limits = true;
cfg.noise_channel = noise_chan;
cfg.freq_range = [6 14];
[borders_all_subj, sigVect_all_subj] = findLAVIBorders(cfg, LAVI_arr, foi);

% Average for central channels
cfg = [];
cfg.channels = chosen_ch;
cfg.use_noise_limits = true;
cfg.noise_channel = noise_chan;
cfg.freq_range = [8 13];
cfg.average_channels = true;
[borders_central_subj, sigVect_central_subj] = findLAVIBorders(cfg, LAVI_arr, foi);

% Average for left posterior channels
cfg = [];
cfg.channels = post_left;
cfg.use_noise_limits = true;
cfg.noise_channel = noise_chan;
cfg.freq_range = [8 13];
cfg.average_channels = true;
[borders_lp_subj, sigVect_lp_subj] = findLAVIBorders(cfg, LAVI_arr, foi);


%% plotting
% Plots LAVI or FFT grand-average spectra for the chosen groups via plotSpectrum.
% pcfg.dependant_variable : 'fft' or 'LAVI', which spectrum to plot
% pcfg.plot_groups        : which groups to plot (ASD, NT, SCZ)
% pcfg.chosen_ch          : channels to plot (averaged if more than one)
% pcfg.noise_var          : whether to plot the pink noise simulations (LAVI only)
% pcfg.noiseCh            : which channel's pink noise to show
pcfg = [];
pcfg.dependant_variable = 'LAVI';   % 'LAVI' or 'fft'
pcfg.plot_groups = {'ASD','NT'};
pcfg.chosen_ch   =chosen_ch; % chosen_ch
pcfg.noise_var   = true;            % set false to hide the pink noise (LAVI only)
pcfg.noiseCh     = noise_chan;
pcfg.FOI  = Lcfg.foi;
pcfg.xfoi = [1, 90];
% pcfg.exclude_subjects = {'011301','011302','013703','104001','104101'};

close all;
[p, legend_names] = plotSpectrum(pcfg, groups);

%% FFT real time 
[durTbl, summary] = fftRecordingTime(FFT_arr, 5);
% Check for outliers
outliers = plotFFTOutliers(durTbl, groups, 'outlier_methods', {'zscore', 'iqr', 'mad'});

%% Compute relative alpha (8-13hz) and absolute and relative gamma (>30hz)
% Following this review from 2023: "Resting-state EEG power differences in autism spectrum
% disorder: a systematic review and meta-analysis".
% absolute power = integral of the FFT power spectrum within a band.
% relative power = band absolute power / total absolute power (sum over bands).
% Bands: delta (<4), theta (4-8), alpha (8-13), beta (13-30), gamma (>30).

% --- Compute absolute & relative band power per participant, per group ---
bpcfg = [];
bpcfg.chosen_ch = chosen_ch;      %chosen_ch;  region of interest (central channels)
bpcfg.fmax      = max(foi);       % cap the open gamma band to the analysis range (90 Hz)
bpcfg.compute_peak_freq = true;
%bpcfg.overrideBandName = 'alpha';    % Target by name
%bpcfg.overrideBandLo = 6;             % New lower boundary
%bpcfg.overrideBandHi = 14;            % New upper boundary


% NOTE: gamma (30-fmax) spans the 60 Hz line-noise frequency; if line noise is
% not fully removed, lower fmax (e.g. 45) or notch it before trusting gamma power.
bandPow = computeBandPower(bpcfg, groups);        % both groups (ASD, NT)
% For a single group only:
% bandPow = computeBandPower(bpcfg, groups(strcmp({groups.name}, 'ASD')));

%% --- Plot distributions of power per band and report group statistics ---
% One figure per band; shows absolute & relative power for each group with
% mean +/- SD, Cohen's d, t-value and p-value (Welch's two-sample t-test).

% Example: only alpha and gamma, relative power, single group:
% ppcfg.bands = {'alpha','gamma'}; ppcfg.measure = 'rel';
% plotBandPower(ppcfg, bandPow(strcmp({bandPow.name}, 'ASD')));

ppcfg = [];
ppcfg.bands   = 'all';            % or e.g. 'alpha', or {'alpha','gamma'}
ppcfg.measure = 'both';           % 'abs', 'rel', or 'both'
ppcfg.colors  = [env.plots.lineASD; env.plots.lineNT];
ppcfg.show_peak_freq = false;
bandStats = plotBandPower(ppcfg, bandPow);

% % With outliers
% ppcfg.exclude_subjects = {'102901', '104001', '101801'};
% bandStats = plotBandPower(ppcfg, bandPow);

%% Peak Frequency - FFT

[stats_fft] = test_peak_freq_difference(bandPow);

% Overlayed histogram of alpha peak frequencies
cfg = [];
% cfg.exclude_subjects = {'030801'};
cfg.type = 'peak_freq';
cfg.band = 'alpha';  % or use index: 3
cfg.method = 'histogram'; % 'histogram' or 'density'
% cfg.show_individual_subjects = true;  % Shows each subject as a dot

% Density options:
% 'kde' - Smooth curves (default, has artifacts)
% 'violin' - Symmetric violin plots
% 'ecdf' - Cumulative dist (NO smoothing!)
% 'rug' - Individual subjects on line- lookss bad, not recommended
% 'strip' - Scatter with jitter
cfg.density_method = 'strip'; 
cfg.nbins = 3;      % optional
plot_peak_dist(cfg, bandPow); 

%% Analyze LAVI peaks in alpha range
% Alpha shows up as a LAVI peak, so these ask for 'peak' (the default).
% Ranges that are troughs instead - delta below - pass 'trough'.
% LAVI_arr is needed in every call: it maps each subject's ID to its row of
% the borders array. Without it the rows are matched by position, which reads
% the wrong subjects for every group after the first.
ch_idx = find(strcmp('Cz', env.lay.label));  % e.g., 34
alpha_range=[6 14];
delta_range=[1 4];
% Compare ALL channels between groups - alpha
stats_all = test_LAVI_peaks_difference(borders_all_subj, groups, alpha_range, ch_idx, LAVI_arr, 'peak');

% Compare AVERAGED central channels (no ch_idx needed for pre-averaged data)
stats_central = test_LAVI_peaks_difference(borders_central_subj, groups, alpha_range, LAVI_arr, 'peak');

% Compare AVERAGED left-posterior channels
stats_lp = test_LAVI_peaks_difference(borders_lp_subj, groups, alpha_range, LAVI_arr, 'peak');

%% Analyze LAVI troughs in delta range
stats_all_delta     = test_LAVI_peaks_difference(borders_all_subj, groups, delta_range, ch_idx, LAVI_arr, 'trough');
stats_central_delta = test_LAVI_peaks_difference(borders_central_subj, groups, delta_range, LAVI_arr, 'trough');


% Visualization (now pass LAVI_arr)
cfg = [];
cfg.freq_range = alpha_range;
cfg.ch_idx = ch_idx;
cfg.method = 'density';
cfg.density_method = 'ecdf';
plot_LAVI_peaks_dist(cfg, borders_all_subj, groups, LAVI_arr);

%% plot single subject LAVI with noise simulations and peaks
for id = 1:length(LAVI_arr)
    figure;
    
    % Get LAVI channel index
    ch_lavi = 'Cz';
    chIdx_lavi = find(strcmp(ch_lavi, env.lay.label));
    
    % Get noise channel index (same as LAVI if available, else Cz)
    ch_noise = ch_lavi;
    chIdx_noise = find(strcmp(ch_noise, LAVI_arr{id}.noise.labels));
    if isempty(chIdx_noise)
        chIdx_noise = find(strcmp('Cz', LAVI_arr{id}.noise.labels));
    end
    
    % Get all 20 pink noise simulations (20 x nFreq matrix)
    noise_all = LAVI_arr{id}.noise.noise{chIdx_noise};  % 20 simulations x 179 frequencies
    
    % Make darker version of LAVI color for noise
    clr_lavi = env.plots.lineASD;
    clr_dark = clr_lavi * 0.5;  % Darker shade
    
    hold on
    
    % Plot all 20 noise simulations as thin lines
    for sim = 1:size(noise_all, 1)
        plot(Lcfg.foi, noise_all(sim, :), 'Color', clr_dark, 'LineWidth', 0.7, 'HandleVisibility', 'off');
    end
    
    % Plot main LAVI line (on top of noise)
    plot(Lcfg.foi, LAVI_arr{id}.powspctrm(chIdx_lavi, :), 'LineWidth', 3, 'Color', clr_lavi, 'DisplayName', sprintf('LAVI (%s)', ch_lavi));
    
   
    % Plot detected peaks and troughs for this channel
    ch_idx_pks = chIdx_lavi;  % Use the same channel index as LAVI

    % Plot only significant peaks/troughs from borders_all_subj
    if ~isempty(borders_all_subj{id,ch_idx_pks})
        borders_matrix = borders_all_subj{id,ch_idx_pks};  % Matrix for this subject and channel
        
        % Loop through each detected border/band
        for b = 1:size(borders_matrix, 1)
            is_significant = borders_matrix(b, 11);  % Column 11: significance (boolean)
            
            if is_significant
                freq = borders_matrix(b, 6);        % Column 6: frequency at peak/trough
                lavi_val = borders_matrix(b, 7);    % Column 7: LAVI value at peak/trough
                direction = borders_matrix(b, 9);   % Column 9: 1=peak, -1=trough
                
                if direction == 1
                    % Peak - red star
                    plot(freq, lavi_val, 'r*', 'MarkerSize', 12, 'LineWidth', 3, 'HandleVisibility', 'off');
                else
                    % Trough - blue circle
                    plot(freq, lavi_val, 'bo', 'MarkerSize', 12, 'LineWidth', 2.5, 'HandleVisibility', 'off');
                end
            end
        end
    end
    % Collect significant peaks and troughs for text annotation
    peaks_freqs = [];
    troughs_freqs = [];
    
    if ~isempty(borders_all_subj{id,ch_idx_pks})
        borders_matrix = borders_all_subj{id,ch_idx_pks};
        
        for b = 1:size(borders_matrix, 1)
            is_significant = borders_matrix(b, 11);
            
            if is_significant
                freq = borders_matrix(b, 6);
                direction = borders_matrix(b, 9);
                
                if direction == 1
                    peaks_freqs = [peaks_freqs, freq];
                else
                    troughs_freqs = [troughs_freqs, freq];
                end
            end
        end
    end
    
    % Create text annotation
    text_str = '';
    if ~isempty(peaks_freqs)
        peaks_str = sprintf('%.1f, ', peaks_freqs);
        peaks_str = peaks_str(1:end-2);  % Remove trailing comma and space
        text_str = [text_str, sprintf('Peaks: %s Hz\n', peaks_str)];
    end
    if ~isempty(troughs_freqs)
        troughs_str = sprintf('%.1f, ', troughs_freqs);
        troughs_str = troughs_str(1:end-2);  % Remove trailing comma and space
        text_str = [text_str, sprintf('Troughs: %s Hz', troughs_str)];
    end
    
    % Add text box to plot if there are any peaks/troughs
    if ~isempty(text_str)
        text(0.98, 0.97, text_str, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'top', 'BackgroundColor', 'white', 'EdgeColor', 'black', ...
            'FontSize', 9, 'Interpreter', 'none', 'Margin', 4);
    end

    hold off;
    
    % Plot formatting
    xlim([Lcfg.foi(1), Lcfg.foi(end)]);
    xlabel('Frequency (Hz)'); 
    ylabel('LAVI');
    title(sprintf('Subject %s',LAVI_arr{id}.ID));
    % subtitle(sprintf('LAVI for channel %s with Pink Noise (Channel=%s) & Detected Peaks', ch_lavi,ch_noise));
    ylim([0 0.9]);
    grid on
    set(gca, 'GridAlpha', 0.3);
end

%% plot signle subject FFT
for id=1:length(FFT_arr)
    figure;
    ch = 'Cz';
    chIdx1 = find(strcmp(ch,env.lay.label));
    
    plot(Lcfg.foi, FFT_arr{id}.powspctrm(chIdx1,:)  , 'LineWidth', 3, 'Color', env.plots.lineASD);
   
    set(gca, 'XScale', 'log', 'YScale', 'log');
    xlim([foi(1), foi(end)]);
    % xt = logspace(log10(foi(1)), log10(foi(2)), 12);
    % xt = round(xt, 1);  % round to 1 decimal place
    % xticks(xt);
    % xticklabels(string(xt));
    % xtickangle(0)
    xlabel('Log (Frequency (Hz))'); ylabel('FFT (log)');
    id_subj=FFT_arr{id}.ID;
    if iscell(id_subj)
        id_subj=id_subj{1};
    elseif ~ischar(id_subj)
        error('ID is not a string or a cell, check!')
    end
    title(sprintf('Subject %s',id_subj));
    ylim([10^-3 10^1]);
end