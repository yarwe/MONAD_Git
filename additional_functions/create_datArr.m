function [LAVI_arr, FFT_arr] = freqanalysis_array(cfg, subj)
% Add new data to the LAVI dataset.
% The dataset contains LAVI results for each ID at each electrode.

env = cfg.env;
addpath(env.paths.LAVI);

% LAVI and fft config
Lcfg = cfg.Lcfg;
Fcfg = cfg.Fcfg;

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
neigh_labels = {neigh_labels{idx}};


% Initialize variables
if strcmp(subj, 'all')
    IDs = 1:length(env.data.clean_files);
    prev_fft_arr = [];
    prev_LAVI_arr = [];

elseif strcmp(subj,'addall')
    prev_LAVI_arr = load([env.paths.preproc 'LAVI_arr.mat']).LAVI_arr;
    prev_fft_arr = load([env.paths.preproc 'FFT_arr.mat']).FFT_arr;

    % find the missing files
    prev_IDs = cellfun(@(s) s.ID, prev_LAVI_arr, 'UniformOutput', false);
    clean_IDs = cellfun(@(s) extractBefore(s, '_'), env.data.clean_names, 'UniformOutput', false);
    IDs = find(~ismember(clean_IDs, prev_IDs));

else
    prev_LAVI_arr = load([env.paths.preproc 'LAVI_arr.mat']).LAVI_arr;
    prev_fft_arr = load([env.paths.preproc 'FFT_arr.mat']).FFT_arr;
    IDs = subj;
end
N = length(IDs);

% EEG structure template
strct = struct('powspctrm', [], 'dimord', 'chan_freq', 'freq', {Lcfg.foi}, ...
    'label', {env.lay.label(1:64)}, 'elec', {env.elec}, 'time', []);

LAVI_arr = {};
FFT_arr  = {}; 
j = 1;
% Iterate over participants
for s = 1:N
    k = IDs(s);
    file = env.data.clean_files{k};
    disp(['participant number:' num2str(s)]);
    EEG = load(file).dat_after_ICA;
    ID = regexp(file, '([A-Za-z0-9]+)_clean.mat', 'tokens', 'once');
    
    noise_labels = {};
    noise        = {};

    % LAVI analysis
    strct.ID = ID{1};    
    LAVI = zeros(62, length(Lcfg.foi));
    % Calculate LAVI for each electrode
    for e = 1:length(EEG.label)
        disp(['Participant: '  num2str(s)  '/' num2str(N) '  ;  ID: ' char(ID) '  ;  Electrode: ' num2str(e)]);
        LAVI(e,:) = Prepare_LAVI(Lcfg, EEG.trial{1}(e,:));
        if ismember(EEG.label{e}, neigh_labels)
            Ncfg = [];
            Ncfg.foi = Lcfg.foi;
            Ncfg.fs = env.data.fsample;
            Ncfg.Pink_reps = 20;
            NoiseSim = computePinkLAVI(Ncfg,EEG.trial{1}(e,:));
            noise_labels{end+1} = EEG.label{e};
            noise{end+1}        = NoiseSim;
        end
    end

    % Store results
    % noise struct
    noiseStrct        = [];
    noiseStrct.noise  = noise;
    noiseStrct.labels = noise_labels;
    noiseStrct.fs     = Ncfg.fs;
    noiseStrct.simNum = Ncfg.Pink_reps;

    strct.time      = [EEG.sampleinfo(1), EEG.sampleinfo(2)];
    strct.powspctrm = LAVI;
    strct.noise     = noiseStrct;
    LAVI_arr{j} = strct;

    
    % FFT analysis
    cfg = [];
    cfg.length = 15;
    EEGtrl = ft_redefinetrial(cfg,EEG)
    cfg = [];
    cfg.trials = find(~cellfun(@(x) any(isnan(x(:))), EEGtrl.trial));
    % Remove trials with NaNs
    EEGtrl_clean = ft_selectdata(cfg, EEGtrl);
    
    fftstrct = [];
    fftstrct = ft_freqanalysis(env.Fcfg, EEGtrl_clean);
    fftstrct.num_win = length(EEGtrl.trial);
    fftstrct.rem_win =  fftstrct.num_win - length(cfg.trials);
    fftstrct.ID = ID;
    fftstrct.cfg.previous = [];
    FFT_arr{j} = fftstrct;
    
    j = j + 1;

    if mod(j, 10) == 0
        LAVI_arr = [prev_LAVI_arr, LAVI_arr];
        FFT_arr  = [prev_fft_arr, FFT_arr];
        %save([env.paths.preproc 'LAVI_arr'], 'LAVI_arr', '-v7.3', '-nocompression');
        %save([env.paths.preproc 'FFT_arr'], 'FFT_arr', '-v7.3', '-nocompression');
    end
end


% Merge with previous data
if exist('prev_LAVI_arr', 'var')
    LAVI_arr = [prev_LAVI_arr, LAVI_arr];
    FFT_arr  = [prev_fft_arr, FFT_arr];
end


% Save the data
disp('Saving All Data...');
%save([env.paths.preproc 'LAVI_arr'], 'LAVI_arr', '-v7.3', '-nocompression');
%save([env.paths.preproc 'FFT_arr'], 'FFT_arr', '-v7.3', '-nocompression');
disp('Data saved!');


end



