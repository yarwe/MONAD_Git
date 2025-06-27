%% Clear all
cd('C:\Users\yoelgo\Documents\GitHub\MONAD_Git');
%cd('C:\Users\yarde\Documents\GitHub\MONAD_Git\');
clc; clear all; close all;
all_data = [];
%%

% experiment names:
% 'OSF_simple', 'TalKennet', 'NMSG' (Neural Markers of Shared Gaze...)
% 'IAASA' (Influence of Attention and Aroudal on Sensory Abnormailities...)

s = 40;


clear EEG pEEG pEEG_zclean pEEG_mclean dat_after_ICA zArt man_art_final man_art2 man_art...
    segment seg cfg cfg2

all_data_idx = length(all_data) + 1;
env = setupEnviroment('OSF_simple');
addpath(env.paths.extra_func);
new_clean_path = 'R:\Yarden\analysis_MONAD\MONAD_preproc\OSF_simple\new_clean\'; 
new_art_path   = 'R:\Yarden\analysis_MONAD\MONAD_preproc\OSF_simple\new_art\';
% Load single participant
% use s=24 for demonstration at lab meeting.
env.data.clean_names;
clean_names = cellfun(@(x) strrep(x, '_clean.mat', ''), env.data.clean_names, 'UniformOutput', false);


ID          = clean_names{s};
filename    = env.data.files{s};

EEG         = load_data(env, filename);
mArt        = load([env.paths.art ID '_MANartifact.mat']);
zArt        = load([env.paths.art ID '_Zartifact.mat']);

% initiate the ID in the CSV
csv_init(env, ID);

clear s ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY TMPEEG tmpEEG filename

% basic preproc
cfg             = [];
cfg.demean      = 'yes';
cfg.detrend     = 'yes';
cfg.reref       = 'yes';
cfg.refchannel  = 'all';
% Band-pass filter: 1–200 Hz
cfg.bpfilter    = 'yes';
cfg.bpfreq      = [0.1 200];
cfg.bpfilttype  = 'but';
cfg.bpfiltord   = 3;
cfg.bpfiltdir   = 'twopass'; % zero-phase

% Notch filters to remove 50Hz and harmonics
cfg.bsfilter    = 'yes';
cfg.bsfreq      = [49 51; 99 101; 149 151; 199 201];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 3; % 3rd order
cfg.bsfiltdir   = 'twopass'; % zero-phase

pEEG = ft_preprocessing(cfg, EEG);

csv_addCol(env, ID,...
    {'bpfilter', 'bsfilter','detrend', 'demean'},...
    {mat2str(cfg.bpfreq), mat2str(cfg.bsfreq), cfg.detrend, cfg.demean});

% high amplitude artifact detection
cfg = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.zvalue.channel     = {'all', '-eogV', '-eogH'};
cfg.artfctdef.zvalue.cutoff      = 50;
cfg.artfctdef.zvalue.artpadding  = 0.2;
cfg.artfctdef.zvalue.zscore      = 'yes';
cfg.artfctdef.zvalue.interactive = 'yes';
z_artifact = zArt.z_artifact;


% calculate the percent of data removed from the total data

Zrem = sum(z_artifact(:, 2) - z_artifact(:, 1))/...
    size(pEEG.time{1},2) * 100;

% add information to CSV log
csv_addCol(env, ID, {'Zval', 'Zart_num', 'Z_rem'}, {cfg.artfctdef.zvalue.cutoff, ...
    size(z_artifact,1), Zrem});
% reject atrifact
cfg = [];
cfg.artfctdef.reject            = 'nan';
cfg.artfctdef.visual.artifact   = z_artifact;
pEEG_zclean = ft_rejectartifact(cfg,pEEG);

%save([env.paths.art ID '_Zartifact'], "z_artifact");

% Manual: Remove Artifacts
man_art = mArt.man_art;
if isempty(man_art) || ischar(man_art)
    disp 'No previous manual artifacts!'
    Mrem = sum(man_art(:, 2) - man_art(:, 1))/...
        size(pEEG_zclean.time{1},2) * 100;
    man_art = [];

end
cfg = [];
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art;
pEEG_mclean = ft_rejectartifact(cfg,pEEG_zclean);

% update csv
if isempty(man_art); man_art = '--'; end
Mrem = sum(man_art(:, 2) - man_art(:, 1))/...
    size(pEEG_zclean.time{1},2) * 100;

%save([env.paths.art ID '_MANartifact'], "man_art");
csv_addCol(env, ID, {'manual_art_num', 'manual_rem', 'ch_interpolate', 'interpolated_sections'}, {size(man_art,1), Mrem, '--', '--'});
clear z_artifact Zrem Mrem


%
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 100;
man_art2 = ft_databrowser(cfg,pEEG_mclean)


cfg = [];
cfg.channel = {'all', '-eogV', '-eogH'};
pEEG_mclean = ft_selectdata(cfg,pEEG_mclean);
%% remove extra manual
cfg = [];
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact  = man_art2.artfctdef.visual.artifact;
pEEG_mclean = ft_rejectartifact(cfg, pEEG_mclean);
x = man_art2.artfctdef.visual.artifact;
save([new_art_path ID '_MANartifact2'], "x");
clear x
%% Manual: Remove Channel (by trial or all)
% Run this cell only if there are channels to remove
% A code I built which can fix a channel (based on adjacent channels) in
% either a specific trial or in all trials. 
man_blocksize = 30;
%badchannel = {'CP6', 'C3', 'C1', 'F3'};      % insert the bad channel(s) name(s) here
%seg = {{0 'lst'}, {0 'lst'}, {0 'lst'}, {25 27}};                 % 'all' or trial number to fix channel
badchannel = {'F4'};      % insert the bad channel(s) name(s) here
seg = {{0 'lst'}};                 % 'all' or trial number to fix channel
if any(~ismember(badchannel, EEG.label))
    error('Some channel name if wrong!!!!!!');
end

%seg = {{0,'lst'}};                 % 'all' or trial number to fix channel
if ~isempty(badchannel)
    cfg = [];
    cfg.layout      = env.lay;
    cfg.method      = 'triangulation';
    neighbours      = ft_prepare_neighbours(cfg, pEEG_mclean);

    for i=1:length(badchannel)
        cfg = [];
        cfg.badchannel  = {badchannel{i}};
        cfg.neighbours  = neighbours;
        cfg.method      =  'spline';
        cfg.elec        = ft_read_sens([env.paths.ft_path 'template\electrode\standard_1020.elc']);
        segment = seg{i};
        if strcmp(segment{2}, 'lst')
            segment{2} = ceil(EEG.time{1}(end)/man_blocksize);
        end
        segment{1} = segment{1} * man_blocksize;
        segment{2} = segment{2} * man_blocksize;
        cfg2 = [];
        cfg2.latency = [segment{1}, segment{2}];
        tmp = ft_selectdata(cfg2,pEEG_mclean);
        tmp = ft_channelrepair(cfg, tmp);

        [~, t1] = min(abs(pEEG_mclean.time{1} - segment{1}));
        [~, t2] = min(abs(pEEG_mclean.time{1} - segment{2}));
        chan_idx = find(strcmp(badchannel{i}, pEEG_mclean.label));
        pEEG_mclean.trial{1}(chan_idx,t1:t2) =  tmp.trial{1}(chan_idx,:);
    end
else
    pEEG_mclean = ft_channelrepair(cfg, pEEG_mclean);
end

singleCell_seg = cellfun(@mat2str, [seg{:}], 'UniformOutput', false);
singleCell_seg = {strjoin(singleCell_seg, ',')};

save([new_art_path ID 'badch'], "badchannel");
save([new_art_path ID 'chsegments'], "seg");


if length(badchannel) > 1; badchannel = {strjoin(badchannel, ', ')}; end
csv_addCol(env, ID, {'ch_interpolate', 'interpolated_sections'}, {badchannel, singleCell_seg});
clear singleCell_seg badchannel

%% Run ICA
addpath([env.paths.ft_path 'external\eeglab\']);
cfg = [];
cfg.method  = 'runica';
cfg.numcomponent = 20;
%cfg.runica.maxsteps = 100;
comp = ft_componentanalysis(cfg, pEEG_mclean);
%% view ICA components
% view time seriers and topopraphy of ICs
cfg = [];
cfg.viewmode = 'component';
cfg.allowoverlap = 'yes';
cfg.continuous = 'yes';
cfg.blocksize = 80;
cfg.layout = env.lay;
cfg.ylim  = [-850 850];
% Show the first 20 components
cfg.channel = comp.label(1:20);

ft_databrowser(cfg, comp);

fig = gcf;

saveas(fig, ['R:\Yarden\analysis_MONAD\MONAD_preproc\OSF_simple\new_ICApng\' ID '_components.png']);

%% reject components
cfg = [];
cfg.component = [1,4];
dat_after_ICA = ft_rejectcomponent(cfg, comp);

comp_idx = {arrayfun(@num2str, cfg.component, 'UniformOutput', false)};
comp_idx = strjoin(comp_idx{1}, ', ');
csv_addCol(env, ID, {'ICA_comp'}, {comp_idx});

all_data{1,all_data_idx} = dat_after_ICA;
all_data{2,all_data_idx} = ID;
%% view the data again
cfg = [];
cfg.ylim  = [-30 30];
cfg.blocksize = 100;
man_art_final = ft_databrowser(cfg,dat_after_ICA);
%man_art_final = ft_databrowser(cfg,pEEG_mclean)
%% Manual: Remove Artifacts
cfg = [];
cfg.artfctdef.reject           = 'nan';
cfg.artfctdef.visual.artifact = man_art_final.artfctdef.visual.artifact;
dat_after_ICA = ft_rejectartifact(cfg,dat_after_ICA);

%% save data after preproc
save([new_clean_path ID '_clean'], "dat_after_ICA");
%save([new_art_path ID '_ICAcomp'], "comp");
disp(['Saved Data!']);

%%
figure;
cfg = [];
cfg.layout = env.lay;  % assuming env.lay is your layout struct
ft_layoutplot(cfg);



%%
for i=1:length(all_data)
    ID = all_data{2,i};
    dat_after_ICA = all_data{1,i};
    save([new_clean_path ID '_clean'], "dat_after_ICA");
end