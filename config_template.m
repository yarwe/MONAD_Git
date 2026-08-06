function cfg = config_template()
%CONFIG_TEMPLATE  Template for the per-machine MONAD configuration.
%
%   This file is tracked by git and is only a reference. To set up a new
%   machine:
%
%       1. Copy this file to  config_local.m  in the repository root.
%       2. Rename the function on the first line to  config_local.
%       3. Fill in the values below for this machine.
%
%   config_local.m is git-ignored on purpose - every machine keeps its own
%   copy with its own paths, and it never gets committed. setupEnviroment11
%   reads all of its machine-specific settings from it.
%
%   Path values may be written with either '\' or '/' separators and with or
%   without a trailing separator; setupEnviroment11 normalises them with
%   fullfile(), so the same file works on Windows, Linux and macOS.

%% Who / where -----------------------------------------------------------
% Free-text label for this machine's user, e.g. 'yarden' or 'yoel'.
cfg.user           = 'CHANGE_ME';

%% Toolbox and repository locations --------------------------------------
% Root of this MONAD_Git clone (the folder holding setupEnviroment11.m).
% Every data path is derived from this - see the Data layout note below.
cfg.git_path       = 'C:\Users\CHANGE_ME\Documents\GitHub\MONAD_Git\';

% Folder holding the manually installed MATLAB toolboxes below.
cfg.matlab_path    = 'C:\Users\CHANGE_ME\Documents\MATLAB\';

% FieldTrip root (the folder containing ft_defaults.m).
cfg.ft_path        = [cfg.matlab_path 'fieldtrip-20210614\'];

% EEGLAB root (the folder containing eeglab.m).
cfg.eeglab_path    = [cfg.matlab_path 'eeglab_current\eeglab2025.0.0\'];

% zapline-plus root (added to the path for line-noise removal).
cfg.zapline_path   = [cfg.matlab_path 'zapline-plus-main\'];

% OPTIONAL. Folder holding biosig4octmat, on machines where BioSig has to be
% (re)installed at start-up. setupEnviroment11 cd's here and runs
% biosig_installer. Leave as '' to skip the installer entirely.
cfg.biosig_path    = '';

%% Data locations --------------------------------------------------------
% There are none to configure. Every data file lives under a single
% git-ignored folder, <cfg.git_path>/Data. Every experiment uses the same
% layout:
%
%   Data/<exp>/                        experiment-level files, shared by all
%                                      paradigms (e.g. TK_customLay.mat)
%   Data/<exp>/<paradigm>/             LAVI/FFT arrays for that run
%   Data/<exp>/<paradigm>/<data_type>  raw, clean, art, ICApng, ica_comp,
%                                      prev_dat
%
% e.g. Data/TalKennet/tactile/clean/. setupEnviroment11 creates any missing
% output folder and warns about a missing Data or raw folder.

%% What to analyse -------------------------------------------------------
% Experiment to load. One of:
%   'OSF_simple', 'TalKennet', 'NMSG', 'IAASA', 'SFARI_EEG_multi'
cfg.exp            = 'OSF_simple';

% Paradigm within the experiment. Only used by 'TalKennet' and
% 'SFARI_EEG_multi'; ignored by the other experiments.
%   TalKennet:        'tactile', 'aud', 'rest'
%   SFARI_EEG_multi:  'ASSR_run', 'FAST_run', 'Beepflash_run', 'AVSRT_run',
%                     'Motor_run', 'IC_run', 'rest'
cfg.paradigm       = 'rest';

%% Parallel pool ---------------------------------------------------------
% OPTIONAL. Number of parfor workers for create_datArr21. Leave as [] to let
% MATLAB pick its default pool size.
%
% This is bound by RAM, not by core count: every worker is a separate MATLAB
% process holding its own full copy of the participant it is working on, and
% the loop body briefly holds two copies at once. Estimate with
%
%   n_workers = floor( (RAM_total - RAM_reserved) / peak_RAM_per_worker )
%
% where peak_RAM_per_worker ~ 2x the largest clean .mat plus ~1 GB of MATLAB
% baseline, and RAM_reserved covers the OS, the desktop and the client MATLAB
% session. Over-subscribing does not raise a clean error - it exhausts RAM
% and freezes the machine.
cfg.n_workers      = [];

end
