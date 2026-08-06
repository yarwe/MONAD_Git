%% Clear all 
clear all;
clc; close all;

%% load enviroment and folder paths according to the experiment
% The experiment (and the MONAD_Git folder) are set in config_local.m,
% see config_template.m. Experiment names: 'OSF_simple', 'TalKennet',
% 'NMSG', 'SFARI_EEG_multi',
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)

env = setupEnviroment11();
cd(env.paths.git)
addpath(env.paths.extra_func); addpath(fullfile(env.paths.ft_path, 'external', 'eeglab'));

% clean previous data to not create confusions
clear EEG pEEG_zclean pEEG_mcleanCh pEEG pEEG_mclean man_art2 man_art comp badCh Mart dat_after_ICA
% clear weird stuff that comes when you load EEGlab data
clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

addpath(env.paths.LAVI);

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