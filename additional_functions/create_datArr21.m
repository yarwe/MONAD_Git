function [LAVI_arr, FFT_arr] = create_datArr21(cfg)
% Add new data to the LAVI dataset.
% The dataset contains LAVI results for each ID at each electrode.
%
% cfg.env:  the enviroment loaded from setupEnviroment11.
% cfg.Lcfg: LAVI cfg, containing the LAVI calculation variables.
% cfg.Fcfg: FFT cfg, containing the FFT calculation variables.
% cfg.prev: 'add'/'all'. whether to add the data to an existing previous
% dataframe or create a new dataframe and calculate across all
% participants.

env = cfg.env;
addpath(env.paths.LAVI);

% LAVI and fft config
Lcfg = cfg.Lcfg;
Fcfg = cfg.Fcfg;
prev = cfg.prev;

% find representative electrodes
cfg = [];
cfg.layout = env.lay;
cfg.compress = 'yes';
cfg.method = 'triangulation';
%cfg.feedback = 'yes';
neighbours = ft_prepare_neighbours(cfg);
if length(env.lay.label) == 64
    idx = find(cellfun(@(x) numel(x)==8, {neighbours.neighblabel}));
else
    idx = find(cellfun(@(x) numel(x)==16, {neighbours.neighblabel}));
end
neigh_labels = {neighbours.label};
neigh_labels = {neigh_labels(idx)};

% Initialize variables and load previous data if needed
if strcmp(prev, 'add')
    % load LAVI df
    fileList = dir(fullfile(env.paths.preproc, '*LAVI*.mat'));
    prevLAVI = load(fullfile(env.paths.preproc, fileList(1).name));
    fieldName = fieldnames(prevLAVI);
    LAVI_arr = prevLAVI.(fieldName{1});
    
    % load fft df
    fileList  = dir(fullfile(env.paths.preproc, '*fft*.mat'));
    prevFFT   = load(fullfile(env.paths.preproc, fileList(1).name));
    fieldName = fieldnames(prevFFT);
    FFT_arr   = prevFFT.(fieldName{1});

    % find the IDs of the previously processed data
    prevIDs = cellfun(@(s) s.ID, LAVI_arr, 'UniformOutput', false);

elseif strcmp(prev, 'all')
    LAVI_arr = {};
    FFT_arr  = {}; 
    prevIDs  = {};
else
    error('add to a previous data frame or start over?');
end

N = length(env.data.clean_files);

% EEG structure template
strct = struct('powspctrm', [], 'dimord', 'chan_freq', 'freq', {Lcfg.foi}, ...
    'label', {env.lay.label(1:64)}, 'elec', {env.elec}, 'time', []);
counter = 0;
% Iterate over participants
for s = 1:N
    file = env.data.clean_files{s};
    ID = regexp(file, '([A-Za-z0-9]+)_clean.mat', 'tokens', 'once');
    if ismember(ID, prevIDs)
        continue;
    end
    disp(['participant number:' num2str(s)]);
    
    % load file and extract the struct
    tmp = load(file);
    fieldName = fieldnames(tmp);
    try
        EEG = tmp.(fieldName{1}){1};
    catch
        EEG = tmp.(fieldName{1});
    end
    
    %%%%%% FIX THIS (!!)- numbers are not the only indicators for EOG/EEG types %%%%%%

    % check if there are accidentaly EOG channels
    sz = size(EEG.trial{1});
    if sz(1) > 64
        cfg = [];
        cfg.channel = 1:64;
        EEG = ft_selectdata(cfg,EEG);
    end
    %%%%%%

    % initiate noise variables
    noise_labels = {};
    noise        = {};

    % LAVI analysis %
    strct.ID = ID{1};    
    LAVI = zeros(62, length(Lcfg.foi));
    n_pink_rep=20;
    samp_rate=env.data.fsample;
    % Calculate LAVI for each electrode
    for e = 1:length(EEG.label)
        disp(['Participant: '  num2str(s)  '/' num2str(N) '  ;  ID: ' char(ID) '  ;  Electrode: ' num2str(e)]);
        LAVI(e,:) = Prepare_LAVI(Lcfg, EEG.trial{1}(e,:));
        if ismember(EEG.label{e}, neigh_labels{1})
            Ncfg = [];
            Ncfg.foi = Lcfg.foi;
            Ncfg.fs = samp_rate;
            Ncfg.Pink_reps = n_pink_rep;
            NoiseSim = computePinkLAVI(Ncfg,EEG.trial{1}(e,:));
            noise_labels{end+1} = EEG.label{e};
            noise{end+1}        = NoiseSim;
        end
    end

    % store LAVI results %
    % noise struct
    noiseStrct        = [];
    noiseStrct.noise  = noise;
    noiseStrct.labels = noise_labels;
    noiseStrct.fs     = samp_rate;
    noiseStrct.simNum = n_pink_rep;

    strct.time      = [EEG.sampleinfo(1), EEG.sampleinfo(2)];
    strct.powspctrm = LAVI;
    strct.noise     = noiseStrct;
    LAVI_arr{end+1} = strct;

    
    % FFT analysis %
    cfg = [];
    cfg.length = 15;
    EEGtrl = ft_redefinetrial(cfg,EEG);
    cfg = [];
    cfg.trials = find(~cellfun(@(x) any(isnan(x(:))), EEGtrl.trial));
    % Remove trials with NaNs
    EEGtrl_clean = ft_selectdata(cfg, EEGtrl);
    
    fftstrct = [];
    fftstrct = ft_freqanalysis(Fcfg, EEGtrl_clean);
    fftstrct.num_win = length(EEGtrl.trial);
    fftstrct.rem_win =  fftstrct.num_win - length(cfg.trials);
    fftstrct.ID = ID;
    fftstrct.cfg.previous = [];
    FFT_arr{end+1} = fftstrct;
    
    counter = counter + 1;

    if mod(counter, 5) == 0
        save([env.paths.preproc num2str(length(LAVI_arr)) '_LAVI_arr'], 'LAVI_arr', '-v7.3', '-nocompression');
        save([env.paths.preproc num2str(length(FFT_arr)) '_FFT_arr'], 'FFT_arr', '-v7.3', '-nocompression');
    end
end


% Save the data
disp('Saving All Data...');
save([env.paths.preproc 'LAVI_arr'], 'LAVI_arr', '-v7.3', '-nocompression');
save([env.paths.preproc 'FFT_arr'], 'FFT_arr', '-v7.3', '-nocompression');
disp('Data saved!');


end



