%% Prepare for FOOOF
%% Clear
clear all; clc; close all;

%% Set main folder
% cd('C:\Users\yarde\Documents\GitHub\MONAD_Git\');
main_monad_git_folder = input('What is the path of MONAD_Git folder? ', 's');
if isempty(main_monad_git_folder)
    main_monad_git_folder=pwd;
end
cd(main_monad_git_folder)

%% load enviroment according to the experiment
% Experiment names: 'OSF_simple', 'TalKennet',
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)

env = setupEnviroment11();
addpath(env.paths.extra_func); addpath([env.paths.ft_path 'external\eeglab\']);
clc;


% clean previous data to not create confusions
clear EEG pEEG_zclean pEEG_mcleanCh pEEG pEEG_mclean man_art2 man_art comp badCh Mart dat_after_ICA
% clear weird stuff that comes when you load EEGlab data
clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

addpath("additional_functions\FOOOF\")

%% Paramteres
nsubjs=length(env.data.names);
nEEG=env.nEEG;
data_preproc = readtable([main_monad_git_folder '\csv_log\MONAD_log.csv']);

%% Check raw data folder

names = {dir(fullfile(env.paths.raw, sprintf('*.%s',env.data.type))).name};
IDs   = cellfun(@(x) extractBefore(x, '_'), names, 'UniformOutput', false);
%% Loop over subjects
for subj=1:length(IDs)
    clearvars -except env subj nsubjs nEEG data_preproc main_monad_git_folder IDs names
    ID          = IDs{subj};
    fprintf("Participant ID=%s \n",ID)
    idx = findParticipant(data_preproc, ID);
    filename=[env.paths.raw names{subj}];
    %% Load raw EEG
    EEG         = load_data12(env, filename);
    fs = EEG.fsample;
    %% High-pass at 1hz
    high_pass_freq=1;
    cfg             = [];
    cfg.hpfilter    = 'yes';
    cfg.hpfreq      = high_pass_freq;
    cfg.hpfilttype  = 'but';
    cfg.hpfiltord   = 3;
    cfg.hpfiltdir   = 'twopass'; % zero-phase
    pEEG_f = ft_preprocessing(cfg, EEG);


    %% Reject trials - part 1
    load([env.paths.art ID '_artifacts'])
    % for part 1
    if ~isempty(art_1)
        mask1 = strcmp(art_1.Decision, 'all'); nart1=sum(mask1);
        artifacts1=[cell2mat(art_1.RemoveSampStart(mask1)), cell2mat(art_1.RemoveSampEnd(mask1))];
    else
        artifacts1=[];
    end
    % for part 2
    if ~isempty(art_2)
        mask2 = strcmp(art_2.Decision, 'all'); nart2=sum(mask2);
        artifacts2=[cell2mat(art_2.RemoveSampStart(mask2)), cell2mat(art_2.RemoveSampEnd(mask2))];
    else
        artifacts2=[];
    end

    if fs>800 % Epochs were determined based on samples' number of the down-sampled data
        artifacts1=artifacts1*2;
        artifacts2=artifacts2*2;
    end
    % reject atrifact 
    if ~isempty(artifacts1)
        cfg = [];
        cfg.artfctdef.reject           = 'nan';
        cfg.artfctdef.manual.artifact = artifacts1;
        pEEG_f_aft_art = ft_rejectartifact(cfg, pEEG_f);
    else
        pEEG_f_aft_art = pEEG_f;
    end
    %% Reject bad channels
    bad_chans=data_preproc(idx,"rej_chans");
    bad_chans = strtrim(strsplit(bad_chans.rej_chans{1}, ','));
    cfg = [];
    cfg.channel = [{'all'}, strcat('-', bad_chans(:)')];   % {'all','-FC3',...}
    pEEG_f_aft_art_rej_chan = ft_selectdata(cfg, pEEG_f_aft_art);
    %% reject ICA eye-movement components
    % Run ICA
    cfg = [];
    cfg.method  = 'runica';
    cfg.numcomponent = 20;
    % cfg.runica.maxsteps = 100;
    comp = ft_componentanalysis(cfg, pEEG_f_aft_art_rej_chan);
    % view time series and topopraphy of ICs
    cfg = [];
    cfg.viewmode = 'component';
    cfg.allowoverlap = 'yes';
    cfg.continuous = 'yes';
    cfg.blocksize = 50;
    cfg.layout = env.lay;
    cfg.ylim  = [-550 550];
    % Show every 10 components
    cfg.channel = comp.label(1:10);
    cfg.plotevents = 'no';
    ft_databrowser(cfg, comp);
    bad_components=input('Which Component number do you wish to reject? e.g., 2, [1,3,20] : '); % e.g., [1,3,20]

    % Remove bad components
    cfg = [];
    cfg.component = bad_components;
    dat_after_ICA1h = ft_rejectcomponent(cfg, comp, pEEG_f_aft_art_rej_chan);
    
    % Sanity checks for ICA
    % Detect blinks and check if they were removed
    chans_blinks={'Fp1','Fp2','Fpz'}; 
    thres_lowpass_eyeblink_detect=15;
    eye_blinks_bef_af_ICA(subj, chans_blinks, thres_lowpass_eyeblink_detect,pEEG_f_aft_art_rej_chan,dat_after_ICA1h,fs,0)
    
    % See traces of frontal channels- how are they changed after ICA?
    time_sec_fps=5;
    nsamples_fps=min(EEG.fsample * time_sec_fps, EEG.sampleinfo(2));
    
    if sum(isnan(pEEG_f_aft_art_rej_chan.trial{1}(1,1:nsamples_fps))) > (nsamples_fps/2)
        nsamples_fps=nsamples_fps*5;
    end
    
    for chan=chans_blinks
        plot_signal_comparison(pEEG_f_aft_art_rej_chan, dat_after_ICA1h, ID ,1,chan,{'Before ICA','After ICA'},[1 nsamples_fps])
    end
    % Variance before and after
    comp_var_bef_aft(pEEG_f_aft_art_rej_chan,dat_after_ICA1h,nEEG-length(bad_chans), {'Before ICA','After ICA'});

    %% Reject trials- part 2
    % reject atrifact 
    if ~isempty(artifacts2)
        cfg = [];
        cfg.artfctdef.reject           = 'nan';
        cfg.artfctdef.manual.artifact = artifacts2;
        dat_after_ICA1h_art2 = ft_rejectartifact(cfg, dat_after_ICA1h);
    else
        dat_after_ICA1h_art2=dat_after_ICA1h;
    end
    %% Channel interpolation
    if ~isempty(bad_chans{1})
        missingchan = bad_chans;          % channels dropped prior to ICA
        dat_after_ICA1h_art2.elec = env.elec; 
        % Build neighbours from the FULL montage (includes the bad channels),
        % NOT from dat_after_ICA. Use the pre-rejection data so the neighbour
        % set is limited to your recorded channels but still defines the bad ones.
        cfg        = [];
        cfg.method = 'triangulation';         % or 'distance'
        cfg.elec   = env.elec;                % 3D elec -> works for spline
        neighbours = ft_prepare_neighbours(cfg, pEEG_f_aft_art);   % full, pre-rejection
         
        % Fix bad channels
        method_interpolate='spline';
        % Interpolate the missing channels back in
        cfg                = [];
        cfg.method         = method_interpolate; 
        cfg.missingchannel = missingchan;          
        cfg.neighbours     = neighbours;
        cfg.elec           = env.elec;
        cfg.senstype       = 'EEG';
        cfg.badchannel = missingchan;
        data_repaired      = ft_channelrepair(cfg, dat_after_ICA1h_art2);
        % Put channels back into the original montage order.
        % NOTE: ft_channelrepair only returns channels that are part of the EEG
        % electrode montage (env.elec), so non-scalp channels such as EOG
        % (e.g. eogH, eogV in the OSF data) are dropped here. That is expected
        % and fine for FOOOF, so we only require the EEG-montage channels to
        % survive; any tolerated non-montage channels are simply left out.
        orig_order = pEEG_f_aft_art.label;
        [tf, loc]  = ismember(orig_order, data_repaired.label);

        % A channel may legitimately be absent only if it is NOT in the EEG
        % montage (e.g. EOG). A missing channel that IS in the montage is a bug.
        in_montage         = ismember(orig_order, env.elec.label);
        missing_unexpected = orig_order(~tf & in_montage);
        assert(isempty(missing_unexpected), ...
            'Some EEG channels are missing from data_repaired: %s', ...
            strjoin(missing_unexpected, ', '));

        % Reorder to the original montage, keeping only channels that are
        % present (drops EOG etc.), so downstream sees EEG in a consistent order.
        loc = loc(tf);
        data_repaired.label = data_repaired.label(loc);
        for i = 1:numel(data_repaired.trial)
            data_repaired.trial{i} = data_repaired.trial{i}(loc(loc~=0), :);
        end
    
        % view the data again to ensure channel fix
        open_databrow(data_repaired, 'nchan',30);
        % show the difference in variance in the interpolated channels.
        % Pass the channel NAMES so comp_var_bef_aft looks up the correct index
        % in each dataset (their channel orders can differ, e.g. EOG dropped).
        comp_var_bef_aft(pEEG_f_aft_art, data_repaired, bad_chans, {'Before interpolation','After interpolation'});

    else
        data_repaired=dat_after_ICA1h_art2;
        method_interpolate='';
    end
    %% Save data for fooof
    save(fullfile(env.paths.foof, [ID '_fooof']),"data_repaired", '-v7.3', '-nocompression')
end