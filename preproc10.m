%% Clear all and set main folder
clearvars -except env nsubjs
clc; close all;

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

env = setupEnviroment11(input('Enter experiment name (OSF_simple /  TalKennet / SFARI_EEG_multi): ', 's'));
addpath(env.paths.extra_func); addpath([env.paths.ft_path 'external\eeglab\']);
clc;

% clean previous data to not create confusions
clear EEG pEEG_zclean pEEG_mcleanCh pEEG pEEG_mclean man_art2 man_art comp badCh Mart dat_after_ICA
% clear weird stuff that comes when you load EEGlab data
clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

%% Load single participant
nsubjs=length(env.data.names);
s = input(sprintf('Enter Participant number (e.g., 1) out of %d participants.\n',nsubjs)); % participant number to load
ID          = env.data.ID{s}; 
fprintf("Participant ID=%s \n",ID)
% check if there is already clean data of that ID
if contains(ID, env.data.clean_names) %|| any(contains(all_data(2,:), env.data.clean_names))
    rerun = input('Data already cleaned. Rerun pre-processing? Press 1 for yes, 0 to exit. ');
    if ~rerun
        error([ID ' Data already cleaned: Stopped running script'])
    end
end

filename    = env.data.files{s};
EEG         = load_data12(env, filename);

% initiate the ID in the CSV
log_file=csv_init15(env, ID);


%% Look at raw data before doing anything
clc;
fs = EEG.fsample; % Get sampling frequnecy
nEEG=env.nEEG;
rec_time_raw=EEG.time{1}(end) / 60;
fprintf(2,'Recording time raw EEG = %.2f minutes. \n',round(rec_time_raw,2))
csv_addCol16(env, log_file, ID, {'rec_time_raw_min',"num_chans","fs"}, {rec_time_raw, nEEG, fs});

% Look at layout
cfg=[];
env.lay.width(:)  = 0.07;   % 0.1003 for OSF
env.lay.height(:) = 0.05; % 0.0707 for OSF
cfg.layout = env.lay;
figure; ft_layoutplot(cfg);
clear cfg; 

% % Variance of EEG channels
% Look at variance of channels and mark potential outliers
[var_chans_raw, out_nums, out_labels]=plot_var_all_chans(ID, EEG, nEEG, 'outlier_methods', {'zscore'}, 'window_sec', 0);

% % According to sliding window
% [var_chans_slide, max_var_win_info] =plot_var_all_chans(ID, EEG, nEEG, 'window_sec', 1,'n_top_wins',5);
% Note about variance - could be eliminated at the end of the
% preprocessing, so don't exclude only according to this

% Display EEG channels- raw waveform: is there a problem in a certain
% channel?
% Use 'identify' interactive option to mark the lines of the possible
% problematic channels
open_databrow(EEG);
% If does not close- delete(gcf)

% % Power spectrum of raw data of chosen channels
% Channels where the line noise is most visible are usually O1,O2
chans_plot = choose_chans(EEG,'plotted');
plot_spect_chans(EEG,fs,s,chans_plot)

% Overlayed- all channels
plot_spect_all_chans(ID,EEG,nEEG,EEG.fsample,[],[],0)

%% Downsample for zapline and future uses

% Downsample to half the original rate for sampling rate > 800
if fs>800  
    cfg.resamplefs = EEG.fsample/2;
    cfg.detrend = 'no';
    EEG_ds = ft_resampledata(cfg, EEG);
    EEG_ds.sampleinfo=[1,EEG.sampleinfo(2)/2];
    fs_ds=EEG.fsample/2;
    env.data.fsample = fs_ds;
    env.data.fsample_original=fs;
else
    EEG_ds=EEG;
    fs_ds=fs;
end


%% Epochs marked to be removed later due to artifacts (before ICA but after other pre-processing)
% Mark in the fieldtrip GUI time zones of suspected artifacts,
% and later mark if indeed to remove them, anf if so- for all channels or
% some. Save the artifacts.

data_brow_info=open_databrow(EEG_ds,'title',"Mark visible artifacts Manually");
man_artf=data_brow_info.artfctdef.visual.artifact;
if ~isempty(man_artf)   
    art_epochs=concat_man_artf(man_artf,fs_ds,0.05);
    % There is an option to reject just some channels, but not used now
    art_1 = elec_choose_artf(ID, EEG_ds, art_epochs, 'context_sec',2);
else
    art_1=table();
end

% Save artifacts
save([env.paths.art ID '_artifacts.mat'], "art_1");


%% Zapline Clean (plus)
% References: 
% 1) Klug, M., & Kloosterman, N. A. (2022). 
% Zapline‐plus: A Zapline extension for automatic and adaptive removal of frequency‐specific noise artifacts in M/EEG. 
% Human Brain Mapping, 43(9), 2743-2758.
% 2) De Cheveigné, A. (2020). 
% ZapLine: A simple and effective method to remove power line artifacts. 
% NeuroImage, 207, 116356.

% Choose only EEG channels;
cfg = []; 
cfg.channel = 'eeg';
EEG_ds = ft_selectdata(cfg, EEG_ds);


% For the main cleaning
[eeg_Dat_clean, zaplineConfig, analyticsResults, plothandles] = ...
        clean_data_with_zapline_plus(EEG_ds.trial{1}, EEG_ds.fsample,maxfreq=EEG_ds.fsample/2);
eeg_postZap = [];
eeg_postZap.label = EEG_ds.label;
eeg_postZap.sampleinfo = EEG_ds.sampleinfo;
eeg_postZap.trial{1} = eeg_Dat_clean;
eeg_postZap.time = EEG_ds.time;
eeg_postZap.fsample = EEG_ds.fsample;

% Save zapline config and previous config
eeg_postZap.cfg.zapline_Config=zaplineConfig;
eeg_postZap.cfg.zapline_analyticsResults=analyticsResults;
eeg_postZap.cfg.zapline_plothandles=plothandles;
eeg_postZap.cfg.previous = EEG_ds.cfg;

clear zaplineConfig analyticsResults plothandles

%% basic preproc: demean, detrend, and filters
% for ICA - create a copy of 1hz high pass filter threshold (instead of 0.5)
clc;

% Set filter parameters
high_pass=0.5; high_pass_ica=1; low_pass=100;

% band pass filter and notch filters for line noise
cfg             = [];
cfg.demean      = 'yes';
cfg.detrend     = 'yes';

% For ICA create a narrower bandpass
cfg.bpfilter    = 'yes';
cfg.bpfreq      = [high_pass_ica low_pass];
cfg.bpfilttype  = 'but';
cfg.bpfiltord   = 3;
cfg.bpfiltdir   = 'twopass'; % zero-phase
pEEG_ica = ft_preprocessing(cfg, eeg_postZap);

% Initial Band-pass filter: 0.5–100 Hz
cfg.bpfreq      = [high_pass low_pass];
pEEG = ft_preprocessing(cfg, eeg_postZap);


%% Sanity check for preprocessing
% Plot after basic preproc (and compare to previous)
% Signal- all channels
open_databrow(pEEG);
% signal- selected channels
for chan={pEEG.label{chans_plot}}
    plot_signal_comparison(EEG_ds, pEEG, ID ,0,chan{1},{'Raw','After demean, detrend and filters'})
end
% Spectra - all channels
plot_spect_all_chans(ID,pEEG,nEEG,fs_ds,[],[],0,[],'after: demean, detrend, filters')
% Spectra - same selected channels
for chan={pEEG.label{chans_plot}}
    plot_power_spectrum_comparison(EEG_ds, pEEG, ID, 'demean, detrend, filters', chan{1})
end

% Variance
comp_var_bef_aft(eeg_postZap,pEEG,nEEG, {'Raw EEG','After demean, detrend and filters'});

csv_addCol16(env, log_file, ID,...
    {'bpfilter', 'bsfilter','detrend', 'demean','zapline'},...
    {mat2str(cfg.bpfreq), mat2str([]), cfg.detrend, cfg.demean,'yes'});


%% Verify artifact epochs and state duration etc.
% First, verify
if ~isempty(art_1)
    art_1_verified = verify_art_before_rem2(ID, pEEG, art_1, 'context_sec', 2);
    % Update
    art_1=art_1_verified;

    % Calculate the percent of data removed from the total data -in time and in
    % samples
    mask1 = strcmp(art_1.Decision, 'all'); nart1=sum(mask1);
    artifacts1=[cell2mat(art_1.RemoveSampStart(mask1)), cell2mat(art_1.RemoveSampEnd(mask1))];
    total_samps_art1 = sum(artifacts1(:,2)- artifacts1(:,1)) + nart1;
    total_min_art1 = total_samps_art1 / fs_ds / 60;
else
    nart1=0; total_samps_art1=0; total_min_art1=0;
end



fprintf(2,'Removed epochs (all-channels): %d\n', nart1);
fprintf(2,'Total samples removed:        %d\n', total_samps_art1);
fprintf(2,'Total time removed:           %.2f minutes\n', total_min_art1);
fprintf(2,'Time removed: %.2f percentage \n', (total_min_art1 / rec_time_raw)*100);

% add information to CSV log
csv_addCol16(env, log_file, ID, {'art1_time_min', 'art1_nepochs', 'art1_nsamples', 'art1_perc_time'},...
    {total_min_art1, nart1, total_samps_art1,  (total_min_art1 / rec_time_raw)*100});

% Save artifacts
save([env.paths.art ID '_artifacts.mat'], "art_1");

clear art_epochs man_artf data_brow_info mask1

%% Remove the artifacts- part 1 out of 2

if ~isempty(art_1)
    % reject atrifact 
    cfg = [];
    cfg.artfctdef.reject           = 'nan';
    cfg.artfctdef.manual.artifact = artifacts1;
    pEEG_aft_art = ft_rejectartifact(cfg, pEEG);
    pEEG_aft_art_ica = ft_rejectartifact(cfg, pEEG_ica);

    % Look at variance before and after
    comp_var_bef_aft(pEEG,pEEG_aft_art,nEEG, {'Before Artifact removal','After artifact removal'});
    % Signal- specific channels
    for chan={pEEG.label{chans_plot}}
        plot_signal_comparison(pEEG, pEEG_aft_art, ID ,0,chan{1},{'Before Artifact removal','After artifact removal'},[1 artifacts1(1,2)+fs_ds])
    end
else
    pEEG_aft_art =pEEG;
    pEEG_aft_art_ica=pEEG_ica;
end


%% Reject bad channels
clc;
fprintf('Previous Outlier Channels due to extreme variance: %s\n', strjoin(out_labels, ', '));
open_databrow(pEEG_aft_art, 'title','Look at suspected channels','nchan',30);


[rej_chans_num, rej_chans_lab] = choose_chans(EEG_ds,'rejected');
rej_chans_str = strjoin(rej_chans_lab, ',');
csv_addCol16(env, log_file, ID, {'rej_chans'},{rej_chans_str});
clear rej_chans_str
clc;

%% Run ICA

% Choose only clean channels
cfg = [];
cfg.channel = [{'all'}, strcat('-', rej_chans_lab(:)')];   % {'all','-FC3',...}
pEEG_aft_art_ica = ft_selectdata(cfg, pEEG_aft_art_ica);
pEEG_aft_art_rej=ft_selectdata(cfg, pEEG_aft_art);
chans_ind_af_rej=find(ismember(pEEG_aft_art.label,pEEG_aft_art_ica.label));

% Run ICA
cfg = [];
cfg.method  = 'runica';
cfg.numcomponent = 20;
% cfg.runica.maxsteps = 100;
comp = ft_componentanalysis(cfg, pEEG_aft_art_ica);

% Save ICA components
save([env.paths.ica_comp ID '_comp.mat'],'comp');

%% View ICA components
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

%% save the current figure of the components for quality check.
fig = gcf;
saveas(fig, [env.paths.ICApng env.exp '_' ID '_ICAcomp.png']);

%% reject components

bad_components=input('Which Component number do you wish to reject? e.g., 2, [1,3,20] : '); % e.g., [1,3,20]

% % Reject the components
% cfg = [];
% cfg.component = bad_components;
% dat_after_ICA1h = ft_rejectcomponent(cfg, comp, EEG_for_ica);

% Use the 0.5hz high-pass and the not downsampled data
cfg           = [];
cfg.unmixing  = comp.unmixing;   % reuse the weights from ICA on filtered copy
cfg.topolabel = comp.topolabel;  % channel labels the ICA was trained on
comp_orig     = ft_componentanalysis(cfg, pEEG_aft_art_rej);  % apply to original data

cfg           = [];
cfg.component = bad_components;
dat_after_ICA = ft_rejectcomponent(cfg, comp_orig, pEEG_aft_art_rej);

%% Sanity checks for ICA
% if not good enough, consider repeat the previous code segment 
% and remove more / other components 
open_databrow(dat_after_ICA);

% Detect blinks and check if they were removed
chans_blinks={'Fp1','Fp2','Fpz'}; 
thres_lowpass_eyeblink_detect=15;
eye_blinks_bef_af_ICA(s, chans_blinks, thres_lowpass_eyeblink_detect,pEEG_aft_art_rej,dat_after_ICA,fs_ds,0)
% eye_blinks_bef_af_ICA(s, chans_blinks, thres_lowpass_eyeblink_detect,EEG_for_ica,dat_after_ICA1h,fs_ds,0)

% See traces of frontal channels- how are they changed after ICA?
time_sec_fps=5;
nsamples_fps=min(EEG_ds.fsample * time_sec_fps, EEG_ds.sampleinfo(2));

if sum(isnan(pEEG_aft_art_rej.trial{1}(1,1:nsamples_fps))) > (nsamples_fps/2)
    nsamples_fps=nsamples_fps*5;
end

for chan=chans_blinks
    plot_signal_comparison(pEEG_aft_art_rej, dat_after_ICA, ID ,1,chan,{'Before ICA','After ICA'},[1 nsamples_fps])
end
% Variance before and after
comp_var_bef_aft(pEEG_aft_art_rej,dat_after_ICA,nEEG-length(rej_chans_num), {'Before ICA','After ICA'});

% Save which components were rejected via ICA and the components themselves
csv_addCol16(env, log_file, ID,...
    {'reject_ica_components'},...
    {mat2str(bad_components)});

%% If Channels were rejected - interpolate them
if ~isempty(rej_chans_lab)
    missingchan = rej_chans_lab;          % channels dropped prior to ICA
    dat_after_ICA.elec = env.elec; 
    % Build neighbours from the FULL montage (includes the bad channels),
    % NOT from dat_after_ICA. Use the pre-rejection data so the neighbour
    % set is limited to your recorded channels but still defines the bad ones.
    cfg        = [];
    cfg.method = 'triangulation';         % or 'distance'
    cfg.elec   = env.elec;                % 3D elec -> works for spline
    neighbours = ft_prepare_neighbours(cfg, pEEG_aft_art);   % full, pre-rejection
     
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
    data_repaired      = ft_channelrepair(cfg, dat_after_ICA);
    % Put channels back into the original montage order
    [tf, loc] = ismember(pEEG_aft_art.label, data_repaired.label);
    assert(all(tf), 'Some original channels are missing from data_repaired: %s', ...
           strjoin(pEEG_aft_art.label(~tf), ', '));
    data_repaired.label = data_repaired.label(loc);
    for i = 1:numel(data_repaired.trial)
        data_repaired.trial{i} = data_repaired.trial{i}(loc, :);
    end

    % view the data again to ensure channel fix
    open_databrow(data_repaired, 'nchan',30);
    % show the difference in variance in these  channels
    comp_var_bef_aft(pEEG_aft_art,data_repaired,rej_chans_num, {'Before interpolation','After interpolation'});

else
    data_repaired=dat_after_ICA;
    method_interpolate='';
end

% save to the CSV
csv_addCol16(env, log_file, ID, {'method_interpolate'}, ...
    {method_interpolate});

%% View the data again for final Manual Epoch removal
clc; close all;
data_brow_info2=open_databrow(data_repaired,'title','Mark visible artifacts Manually');
man_artf2=data_brow_info2.artfctdef.visual.artifact;
if ~isempty(man_artf2)
    art_epochs2=concat_man_artf(man_artf2,fs_ds,0.05);
    % There is an option to reject just some channels, but not used now
    art_2 = elec_choose_artf(ID, data_repaired, art_epochs2, 'context_sec',2);
    % Calculate the percent of data removed from the total data -in time and in
    % samples
    mask2 = strcmp(art_2.Decision, 'all'); nart2=sum(mask2);
else
    nart2=0;
end

if nart2>=1
    artifacts2=[cell2mat(art_2.RemoveSampStart(mask2)), cell2mat(art_2.RemoveSampEnd(mask2))];
    total_samps_art2 = sum(artifacts2(:,2)- artifacts2(:,1)) + nart2;
    total_min_art2 = total_samps_art2 / fs_ds / 60;
    fprintf(2,'Second Artifact removal\n')
    fprintf(2,'Removed epochs (all-channels): %d\n', nart2);
    fprintf(2,'Total samples removed:        %d\n', total_samps_art2);
    fprintf(2,'Total time removed:           %.2f minutes\n', total_min_art2);
    fprintf(2,'Time removed: %.2f percentage \n', (total_min_art2 / rec_time_raw)*100);
    fprintf(2,'Time removed from both artifact removals: %.2f percentage \n', ((total_min_art1 + total_min_art2) / rec_time_raw)*100')

    % add information to CSV log
    csv_addCol16(env, log_file, ID, {'art2_time_min', 'art2_nepochs', 'art2_nsamples', 'art2_perc_time'},...
    {total_min_art2, nart2, total_samps_art2,  (total_min_art2 / rec_time_raw)*100});
    
    %% Remove artifact epochs
    % reject atrifact 
    cfg = [];
    cfg.artfctdef.reject           = 'nan';
    cfg.artfctdef.manual.artifact = artifacts2;
    data_repaired_aft_art = ft_rejectartifact(cfg, data_repaired);
    
    % Look at variance before and after
    comp_var_bef_aft(data_repaired,data_repaired_aft_art,nEEG, {'Before Artifact removal','After artifact removal'});
    % Signal
    plot_signal_comparison(data_repaired, data_repaired_aft_art, ID ,0,'Cz',{'Before Artifact removal','After artifact removal'},[1 artifacts2(1,2)*2])
    plot_signal_comparison(data_repaired, data_repaired_aft_art, ID ,1,'Cz',{'Before Artifact removal','After artifact removal'},[1 artifacts2(1,2)*2])
    
    
else
    data_repaired_aft_art=data_repaired;
    % add information to CSV log
    csv_addCol16(env, log_file, ID, {'art2_time_min', 'art2_nepochs', 'art2_nsamples', 'art2_perc_time'},...
    {0, 0, 0,  (0 / rec_time_raw)*100});
    total_min_art2=0;
    art_2=table();
end

% Save artifacts
save([env.paths.art ID '_artifacts.mat'], "art_1","art_2");

%% Final recording time (without NaN epochs of all channels due to artifacts)
open_databrow(data_repaired_aft_art)
nsamples_final_not_nan=sum(all(~isnan(data_repaired_aft_art.trial{1}), 1));
rec_time_final=nsamples_final_not_nan / fs_ds / 60;
fprintf(2,'Recording time raw EEG = %.2f minutes vs. final= %.2f minutes. \n',round(rec_time_raw,2),round(rec_time_final,2))


% add information to CSV log
csv_addCol16(env, log_file, ID, {'art1_2_perc_time','final_time_min'},...
    {((total_min_art1+total_min_art2) / rec_time_raw)*100, rec_time_final});


%% re-reference: CAR (Common Average Refrencing) - mean of all channels
cfg=[];
cfg.reref       = 'yes';
cfg.refchannel  = 'all';
dat_final = ft_preprocessing(cfg, data_repaired_aft_art);

% View final
open_databrow(dat_final);
plot_var_all_chans(ID, dat_final, nEEG, 'window_sec', 0);

% Date
date_t = datetime("today", "Format", "dd/MM/yyyy");

% add information to CSV log
csv_addCol16(env, log_file, ID, {'reref_channel','date_preproc','fs_ds'},...
    {cfg.refchannel,date_t,fs_ds});


%% Adjust final fields
if isfield(dat_final, 'elec')
    dat_final=rmfield(dat_final, 'elec');
end
dat_final.sampleinfo_no_nan=[1,nsamples_final_not_nan];
dat_final.ID= ID;
dat_final.experiment=env.exp;

% Save final dataset
save([env.paths.clean ID '_clean'], "dat_final", '-v7.3', '-nocompression');

%%  See power spectrum (deals with nan)
fs   = dat_final.fsample;
data = dat_final.trial{1};                 % chan x samp, with NaN gaps
nCh  = size(data,1);

win_sec=1; print_window_info=0;

[~, f] = psd_nan(data(1,:), fs, win_sec, 0.5, print_window_info);
Pxx = zeros(numel(f), nCh);
for ch = 1:nCh
    Pxx(:,ch) = psd_nan(data(ch,:), fs, win_sec, 0.5,print_window_info);
    if ch== (nCh-1) % Show only for the last channel the window details
        % Assumes at the moment that if epochs are reject- all of the
        % channels are rejected
        print_window_info=1;
    end
end
plot_psd_channels(f, Pxx,'window_sec',win_sec);



%% nchans rejected + add final notes?
final_notes=input('Enter General Notes or empty string: \n', 's');

%
nchan_rej=length(rej_chans_num);
csv_addCol16(env, log_file, ID, {'Nchan_rej'},...
    {nchan_rej});

% add notes to CSV log
csv_addCol16(env, log_file, ID, {'Notes'},...
    {final_notes});


%% Save
disp('Saving previous data...');

% Save previous datasets
save([env.paths.prev_dat ID '_prev_dat'], ...
    "EEG","pEEG","pEEG_ica","pEEG_aft_art","pEEG_aft_art_ica",...
    "pEEG_aft_art_rej","dat_after_ICA",...
    "data_repaired","data_repaired_aft_art","eeg_postZap", '-v7.3', '-nocompression');

disp('All Data Saved!');
figure;