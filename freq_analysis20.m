clc; clear all; close all;
% experiment names: 
% 'OSF_simple', 'TalKennet',
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)
[env] = setupEnviroment11('TalKennet');
addpath(env.paths.LAVI);

% set parameters for LAVI and FFT
chosen_ch = { 'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'} ;
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
Fcfg.channel = 'all'; 
Fcfg.method  = 'mtmfft';
Fcfg.pad = 'nextpow2';
Fcfg.taper   = 'hanning';

%% add participants to LAVI/fft arrays
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

%% Grand Average of Each Group (ASD, NT, SCZ, fft and LAVI)
exp_groups = {'ASD', 'NT'};
groups = [];

% --- Grand average LAVI across participats --- %
% Extract IDs and split groups
IDs = cellfun(@(s) s.ID, LAVI_arr, 'UniformOutput', false);
% Define all possible groups
all_groups = struct( ...
    'name', {'ASD', 'NT', 'SCZ'}, ...
    'label', {'A', 'C', 'S'}, ...
    'color', {env.plots.lineASD, env.plots.lineNT, env.plots.lineSCZ} ...
);

% Filter based on plot_groups
groups = all_groups(ismember({all_groups.name}, exp_groups));

% TalKenet group file
talKenet_group_file = fullfile( ...
    'C:\Users\yarde\Documents\GitHub\MONAD_Git\NIMH data', ...
    'Package_1235544-Tal Kenet MEG EEG biomarkers', ...
    'Number_group_meg_eeg_biomarkers.csv' ...
);

% Load TalKenet group table only when needed
if strcmpi(env.exp, 'TalKennet')
    TalKenet_table = readtable(talKenet_group_file);

    % Make sure IDs are comparable as strings
    TalKenet_table.Number = string(TalKenet_table.Number);
    TalKenet_table.Group  = string(TalKenet_table.Group);

    IDs_str = string(IDs);

    % Convert TD in the file to NT in your code terminology
    TalKenet_table.Group(TalKenet_table.Group == "TD") = "NT";
    
    % CSV removes zero at begining when treated as number
    TalKenet_table.Number = pad(TalKenet_table.Number, 6, 'left', '0');
end


% Load data into groups
for i = 1:numel(groups)

    if strcmpi(env.exp, 'OSF_simple')

        idx = contains(IDs, groups(i).label);
        groups(i).data_LAVI = LAVI_arr(idx);

    elseif strcmpi(env.exp, 'TalKennet')

        this_group = string(groups(i).name);

        % Find IDs that belong to the current group
        group_IDs = TalKenet_table.Number(TalKenet_table.Group == this_group);

        % Match LAVI_arr IDs to table IDs
        idx = ismember(IDs_str, group_IDs);

        groups(i).data_LAVI = LAVI_arr(idx);

    end
end

% Grand averages
cfg = [];
cfg.channel = chosen_ch;
cfg.type = 'LAVI'; % grand average LAVI values

for i = 1:numel(groups)
    [groups(i).GA_LAVI] = data_grandAvg22(cfg, groups(i).data_LAVI);
end

% --- Gran average fft across participants --- %
% Extract IDs and split groups for fft
IDs = cellfun(@(s) s.ID{:}, FFT_arr, 'UniformOutput', false);
IDs_str = string(IDs);

if strcmpi(env.exp, 'OSF_simple')
    IDs = cellfun(@(x) x{1}, IDs, 'UniformOutput', false);
end

% Load data into groups
for i = 1:numel(groups)

    if strcmpi(env.exp, 'OSF_simple')
        idx = contains(IDs, groups(i).label);
        groups(i).data_fft = FFT_arr(idx);

    elseif strcmpi(env.exp, 'TalKennet')

        this_group = string(groups(i).name);

        % Find IDs that belong to the current group
        group_IDs = TalKenet_table.Number(TalKenet_table.Group == this_group);

        % Match FFT_arr IDs to table IDs
        idx = ismember(IDs_str, group_IDs);

        groups(i).data_fft = FFT_arr(idx);

    end
end
% Grand averages
cfg = [];
cfg.channel = chosen_ch;
cfg.type = 'powspctrm'; % grand average powerspectrm values
for i = 1:numel(groups)
    [groups(i).GA_fft] = data_grandAvg22(cfg, groups(i).data_fft);
end


%% find peaks
cfg = [];
cfg.env = env;
cfg.foi = foi;
for i=1:length(LAVI_arr)
    data = LAVI_arr{i};
    pks{i} = LAVI_findPeaks(cfg,data);
end


%% plotting
% Plots LAVI or FFT grand-average spectra for the chosen groups via plotSpectrum.
% pcfg.dependant_variable : 'fft' or 'LAVI', which spectrum to plot
% pcfg.plot_groups        : which groups to plot (ASD, NT, SCZ)
% pcfg.chosen_ch          : channels to plot (averaged if more than one)
% pcfg.noise_var          : whether to plot the pink noise simulations (LAVI only)
% pcfg.noiseCh            : which channel's pink noise to show
pcfg = [];
pcfg.dependant_variable = 'fft';   % 'LAVI' or 'fft'
pcfg.plot_groups = {'ASD','NT'};
pcfg.chosen_ch   ={'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'};
pcfg.noise_var   = false;            % set false to hide the pink noise (LAVI only)
pcfg.noiseCh     = 'Cz';
pcfg.FOI  = Lcfg.foi;
pcfg.xfoi = [1, 90];

close all;
[p, legend_names] = plotSpectrum(pcfg, groups);

%% FFT real time 
[durTbl, summary] = fftRecordingTime(FFT_arr, 5)

%% Compute relative alpha (8-13hz) and absolute and relative gamma (>30hz)
% Following this review from 2023: "Resting-state EEG power differences in autism spectrum
% disorder: a systematic review and meta-analysis".
% absolute power = integral of the FFT power spectrum within a band.
% relative power = band absolute power / total absolute power (sum over bands).
% Bands: delta (<4), theta (4-8), alpha (8-13), beta (13-30), gamma (>30).

% --- Compute absolute & relative band power per participant, per group ---
bpcfg = [];
bpcfg.chosen_ch = chosen_ch;      % region of interest (central channels)
bpcfg.fmax      = max(foi);       % cap the open gamma band to the analysis range (90 Hz)

% NOTE: gamma (30-fmax) spans the 60 Hz line-noise frequency; if line noise is
% not fully removed, lower fmax (e.g. 45) or notch it before trusting gamma power.
bandPow = computeBandPower(bpcfg, groups);        % both groups (ASD, NT)
% For a single group only:
% bandPow = computeBandPower(bpcfg, groups(strcmp({groups.name}, 'ASD')));

% --- Plot distributions per band and report group statistics ---
% One figure per band; shows absolute & relative power for each group with
% mean +/- SD, Cohen's d, t-value and p-value (Welch's two-sample t-test).
ppcfg = [];
ppcfg.bands   = 'all';            % or e.g. 'alpha', or {'alpha','gamma'}
ppcfg.measure = 'both';           % 'abs', 'rel', or 'both'
ppcfg.colors  = [env.plots.lineASD; env.plots.lineNT];
bandStats = plotBandPower(ppcfg, bandPow);

% Example: only alpha and gamma, relative power, single group:
% ppcfg.bands = {'alpha','gamma'}; ppcfg.measure = 'rel';
% plotBandPower(ppcfg, bandPow(strcmp({bandPow.name}, 'ASD')));

% With outliers
ppcfg.exclude_subjects = {'102901', '104001', '101801'};
bandStats = plotBandPower(ppcfg, bandPow);

%% plot signle subject LAVI with noise
figure;
ID = 10;
ch = 'POz';
chIdx1 = find(strcmp(ch,env.lay.label))
chIdx2 = find(strcmp(ch,LAVI_arr{1}.noise.labels))
maxNoise = max(LAVI_arr{ID}.noise.noise{chIdx2}, [], 1);  % Max across simulations per frequency
minNoise = min(LAVI_arr{ID}.noise.noise{chIdx2}, [], 1);  % Min across simulations per frequency

plot(Lcfg.foi, LAVI_arr{ID}.powspctrm(chIdx1,:)  , 'LineWidth', 3, 'Color', env.plots.lineASD);
hold on
plot(Lcfg.foi, LAVI_arr{ID}.noise.noise{chIdx2});
hold on
plot(Lcfg.foi, maxNoise, 'LineWidth', 1.5, 'Color', 'black');
hold on
plot(Lcfg.foi, minNoise, 'LineWidth', 1.5, 'Color', 'black');
%ylim([0.32, 0.55])
set(gca, 'XScale', 'log');
xlim([xfoi(1), xfoi(end)]);
xt = logspace(log10(xfoi(1)), log10(xfoi(2)), 12);
xt = round(xt, 1);  % round to 1 decimal place
xticks(xt);
xticklabels(string(xt));
xtickangle(0)


