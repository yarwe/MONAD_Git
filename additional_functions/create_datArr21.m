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
all_labels = {neighbours.label};

% % To allow comparisons between experiments, we aim to take the same
% % electrodes as noise baseline
target_labels ={'FC5', 'C3', 'C5', 'CP5', 'POz', 'AFz', 'FC6', 'Cz', 'C4', 'C6', 'CP6'};
existing_idx = ismember(target_labels, all_labels);
neigh_labels = target_labels(existing_idx);

% Optional: Print a warning if some of your target electrodes are missing
if ~all(existing_idx)
    missing_labels = target_labels(~existing_idx);
    num_missing = sum(~existing_idx);
    warning('The following target electrodes were not found in this dataset: %s', ...
            strjoin(missing_labels, ', '));
    % 1. Count the number of neighbors for ALL available electrodes
    neighbor_counts = cellfun(@numel, {neighbours.neighblabel});
    
    % 2. Exclude electrodes we already have in neigh_labels so we don't duplicate
    [~, already_used_idx] = ismember(neigh_labels, all_labels);
    neighbor_counts(already_used_idx) = -1; % Set to -1 so they aren't picked again
    
    % 3. Sort the remaining electrodes by their neighbor count in descending order
    [sorted_counts, sorted_idx] = sort(neighbor_counts, 'descend');
    
    % 4. Take the top N electrodes with the highest neighbor counts to fill the gap
    replacement_idx = sorted_idx(1:num_missing);
    replacement_labels = all_labels(replacement_idx);
    
    % 5. Append the replacement electrodes to your neigh_labels
    neigh_labels = [neigh_labels, replacement_labels];
    
    fprintf('Added replacement electrodes with maximal neighbors: %s\n', ...
            strjoin(replacement_labels, ', '));
end

% idx = find(cellfun(@(x) numel(x)==8, {neighbours.neighblabel}));
% neigh_labels = {neighbours.label};
% neigh_labels = {neigh_labels(idx)};

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
strctTemplate = struct('powspctrm', [], 'dimord', 'chan_freq', 'freq', {Lcfg.foi}, ...
    'label', {env.lay.cfg.channel}, 'elec', {env.elec}, 'time', []); % for label- {env.lay.label(1:64)}

% Broadcast only what the workers need, instead of the whole env struct
clean_files = env.data.clean_files;
nEEG        = env.nEEG;

% Per-participant results are written here as soon as they are computed. A run
% over the full dataset takes many hours, and the clean files sit on a soft
% mounted CIFS share where a single timed-out read is reported to MATLAB as an
% error - which aborts the whole parfor. Persisting each participant means such
% a crash costs one participant instead of the entire pass, and re-running
% picks up where it left off.
partial_dir = env.paths.partial;
if ~exist(partial_dir, 'dir')
    mkdir(partial_dir);
end

% Size the parallel pool from cfg.n_workers in config_local.m. Each worker is
% a separate process holding its own copy of the participant it loads, so this
% is a memory budget, not a core count - see the note in config_template.m.
pool = gcp('nocreate');
if isempty(env.n_workers)
    if isempty(pool), pool = parpool('local'); end
else
    if ~isempty(pool) && pool.NumWorkers ~= env.n_workers
        delete(pool);
        pool = [];
    end
    if isempty(pool), pool = parpool('local', env.n_workers); end
end
fprintf('Processing %d participants on %d workers.\n', N, pool.NumWorkers);

% Sliced outputs: one cell per participant. Skipped participants stay empty
% and are dropped after the loop.
LAVI_new = cell(1, N);
FFT_new  = cell(1, N);
% One entry per participant that could not be processed, reported after the loop
failed   = cell(1, N);

% Iterate over participants
parfor s = 1:N
    file = clean_files{s};
    ID = regexp(file, '([A-Za-z0-9]+)_clean.mat', 'tokens', 'once');
    if ismember(ID, prevIDs)
        continue;
    end

    % Reuse this participant's result if an earlier run already computed it
    partial_file = fullfile(partial_dir, [ID{1} '_partial.mat']);
    if exist(partial_file, 'file')
        done = load_with_retry(partial_file);
        LAVI_new{s} = done.lavi;
        FFT_new{s}  = done.fftres;
        disp(['participant ' ID{1} ' already done, reusing ' partial_file]);
        continue;
    end

    disp(['participant number:' num2str(s)]);

    % One unusable participant must not abort the whole pass. A run takes many
    % hours, and a single clean file that cannot be read - A5 and C14 are both
    % corrupt HDF5, written by an interrupted save - would otherwise throw away
    % every worker's progress. Record the failure and carry on; the IDs are
    % reported at the end so they can be regenerated and picked up on a re-run.
    try
        % load file and extract the struct
        tmp = load_with_retry(file);
        fieldName = fieldnames(tmp);
        try
            EEG = tmp.(fieldName{1}){1};
        catch
            EEG = tmp.(fieldName{1});
        end
        tmp = []; %#ok<NASGU> % released: nothing reads tmp past this point

        % % check if there are accidentaly EOG channels
        % sz = size(EEG.trial{1});
        % if sz(1) > 64
        %     cfg = [];
        %     cfg.channel = 1:64;
        %     EEG = ft_selectdata(cfg,EEG);
        % end
        % %%%%%%

        % initiate noise variables
        noise_labels = {};
        noise        = {};

        % LAVI analysis %
        strct = strctTemplate;
        strct.ID = ID{1};
        LAVI = zeros(nEEG, length(Lcfg.foi));
        n_pink_rep=20;
        samp_rate=Lcfg.fs;
        % Calculate LAVI for each electrode
        for e =1:length(EEG.label)
            disp(['Participant: '  num2str(s)  '/' num2str(N) '  ;  ID: ' char(ID) '  ;  Electrode: ' num2str(e)]);
            LAVI(e,:) = Prepare_LAVI(Lcfg, EEG.trial{1}(e,:));
            if ismember(EEG.label{e}, neigh_labels)
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
        LAVI_new{s}     = strct;


        % FFT analysis % (!) yarden changed window into 5s instead of 15: tcfg.length = 15;
        tcfg = [];
        tcfg.length = 5;
        EEGtrl = ft_redefinetrial(tcfg,EEG);
        EEG = []; %#ok<NASGU> % released: last use is the ft_redefinetrial call above
        num_win = length(EEGtrl.trial); % counted here, before EEGtrl is released
        tcfg = [];
        tcfg.trials = find(~cellfun(@(x) any(isnan(x(:))), EEGtrl.trial));
        % Remove trials with NaNs
        EEGtrl_clean = ft_selectdata(tcfg, EEGtrl);
        EEGtrl = []; %#ok<NASGU> % released

        fftstrct = ft_freqanalysis(Fcfg, EEGtrl_clean);
        EEGtrl_clean = []; %#ok<NASGU> % released
        fftstrct.num_win = num_win;
        fftstrct.rem_win =  num_win - length(tcfg.trials);
        fftstrct.ID = ID{1};
        fftstrct.cfg.previous = [];
        FFT_new{s} = fftstrct;

        % Persist this participant before moving on, so the work survives a crash
        save_partial(partial_file, strct, fftstrct);

    catch participant_err
        % Drop whatever this participant produced, so a half-filled LAVI result
        % cannot reach the output arrays and be mistaken for a complete one
        LAVI_new{s} = [];
        FFT_new{s}  = [];
        failed{s}   = sprintf('%s: %s', ID{1}, participant_err.message);
        warning('create_datArr21:participantFailed', ...
            'Participant %s (%d of %d) failed and was skipped: %s', ...
            ID{1}, s, N, participant_err.message);
    end
end

% Report anything that was skipped, so a run that "finished" cannot quietly
% hide missing participants
failed = failed(~cellfun(@isempty, failed));
if ~isempty(failed)
    warning('create_datArr21:someParticipantsFailed', ...
        '%d of %d participants were skipped:\n  %s', ...
        numel(failed), N, strjoin(failed, '\n  '));
else
    fprintf('All %d participants processed with no failures.\n', N);
end

% Append the newly processed participants, keeping the original order and
% dropping the participants that were skipped
LAVI_arr = [LAVI_arr(:).', LAVI_new(~cellfun(@isempty, LAVI_new))];
FFT_arr  = [FFT_arr(:).',  FFT_new(~cellfun(@isempty, FFT_new))];


% Save the data
disp('Saving All Data...');
save([env.paths.preproc 'LAVI_arr'], 'LAVI_arr', '-v7.3', '-nocompression');
save([env.paths.preproc 'FFT_arr'], 'FFT_arr', '-v7.3', '-nocompression');
disp('Data saved!');


end


function s = load_with_retry(file)
% LOAD_WITH_RETRY  load(), retrying transient read failures.
%
% The clean .mat files sit on a CIFS share mounted 'soft', which reports a
% timed-out read to the application as a plain error instead of retrying it.
% Inside a parfor that error aborts every worker, so a momentary network stall
% can throw away hours of work. Such reads almost always succeed on a second
% attempt, so retry a few times with a growing pause before giving up.

n_attempts = 3;
for attempt = 1:n_attempts
    try
        s = load(file);
        return
    catch err
        if attempt == n_attempts
            rethrow(err);
        end
        pause_s = 5 * attempt;
        warning('create_datArr21:loadRetry', ...
            'Reading %s failed (attempt %d of %d): %s Retrying in %d s.', ...
            file, attempt, n_attempts, err.message, pause_s);
        pause(pause_s);
    end
end

end


function save_partial(fname, lavi, fftres)
% SAVE_PARTIAL  Write one participant's LAVI and FFT results.
%
% Written to a temporary name first and then moved into place, so that a crash
% or a dropped connection midway through the write cannot leave behind a
% truncated file that a later run would happily load as if it were complete.

out = struct('lavi', lavi, 'fftres', fftres);
tmp_name = [fname '.tmp'];
save(tmp_name, '-struct', 'out', '-v7.3', '-nocompression');
movefile(tmp_name, fname);

end



