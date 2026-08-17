%% Combine together LAVI measures from multiple experiments
%% Load LAVI arrays
load('C:\Users\yarde\Documents\GitHub\MONAD_Git\analysis_MONAD\MONAD_preproc\TalKennet.LAVI_arr.mat')
LAVI_arr_tk=LAVI_arr;
clear LAVI_arr
load('Z:\Yarden\analysis_MONAD\MONAD_preproc\OSF_simple\LAVI_arr.mat')
[env] = setupEnviroment11('TalKennet');
%% Combine into one array
combined_arr = [LAVI_arr, LAVI_arr_tk];

%% Mark for each cell - which group it belongs to
%% Grand Average of Each Group (ASD, NT, SCZ, fft and LAVI)
exp_groups = {'ASD', 'NT', 'SCZ'}; % Added SCZ just in case you want to compute all three
groups = [];

% --- Extract IDs for both datasets --- %
IDs_1 = cellfun(@(s) s.ID, LAVI_arr, 'UniformOutput', false);
IDs_2 = cellfun(@(s) s.ID, LAVI_arr_tk, 'UniformOutput', false);
IDs_2_str = string(IDs_2);

% Define all possible groups
all_groups = struct( ...
    'name', {'ASD', 'NT', 'SCZ'}, ...
    'label', {'A', 'C', 'S'}, ...
    'color', {env.plots.lineASD, env.plots.lineNT, env.plots.lineSCZ} ...
);

% Filter based on exp_groups
groups = all_groups(ismember({all_groups.name}, exp_groups));

% --- Load TalKenet group file unconditionally since we are merging --- %
talKenet_group_file = fullfile( ...
    'C:\Users\yarde\Documents\GitHub\MONAD_Git\NIMH data', ...
    'Package_1235544-Tal Kenet MEG EEG biomarkers', ...
    'Number_group_meg_eeg_biomarkers.csv' ...
);

TalKenet_table = readtable(talKenet_group_file);
TalKenet_table.Number = string(TalKenet_table.Number);
TalKenet_table.Group  = string(TalKenet_table.Group);
TalKenet_table.Group(TalKenet_table.Group == "TD") = "NT"; % Convert TD to NT
TalKenet_table.Number = pad(TalKenet_table.Number, 6, 'left', '0'); % Fix missing zeros

% --- Filter and Merge Data for each group --- %
for i = 1:numel(groups)
    current_group_name = string(groups(i).name);
    current_group_label = groups(i).label;
    
    % % 1. Filter First Dataset (by ID prefix letter)
    idx_ds1 = contains(IDs_1, current_group_label);
    data_ds1 = LAVI_arr(idx_ds1);
    
    % 2. Filter Second Dataset (by CSV lookup)
    group_IDs_tk = TalKenet_table.Number(TalKenet_table.Group == current_group_name);
    idx_ds2 = ismember(IDs_2_str, group_IDs_tk);
    data_ds2 = LAVI_arr_tk(idx_ds2);
    
    % 3. Combine them together into one group array
    groups(i).data_LAVI = [data_ds2,data_ds2];
end

%% Compute Average LAVI for each group
chosen_ch = { 'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'};
% --- Compute Grand Averages using your function --- %
cfg = [];
cfg.channel = chosen_ch;
cfg.type = 'LAVI'; 

for i = 1:numel(groups)
    if ~isempty(groups(i).data_LAVI)
        % Call your function with the combined data cell array
        groups(i).grandAvg = data_grandAvg22(cfg, groups(i).data_LAVI);
    else
        groups(i).grandAvg = [];
    end
end

%% set LAVI parameters
Lcfg = []; foi = 1:0.5:90; %
Lcfg.foi = foi;
Lcfg.lag = 1.5;
Lcfg.width = 5;

%% plotting
% this code allows for plotting of both fft and LAVI spectrums.
% dependant_variable: 'fft' or 'LAVI' whether to plot the fft or LAVI spectrums
% plot_groups: which groups to plot. ASD (autism), NT (Neuro Typical) and SCZ (scizophrenia)
% chosen_ch: which channels to plot. In case of more than one channel, plots the average
% noise_var: whether to plot the pink noise simulations or not (LAVI only)
% noiseCh: which channel of noise to show the pink noise simulations of.
dependant_variable = 'LAVI'; % 'LAVI' or 'fft'
plot_groups = {'ASD','NT'};
chosen_ch = {'Cz', 'C1', 'C2', 'FCz', 'FC1', 'FC2'};
noise_var = 1; % Only used when dependant_variable = 'LAVI'
noiseCh = 'Cz';
% foi
xfoi = [1, 40];
FOI = Lcfg.foi;

% Find noise channel index (only needed for LAVI)
if strcmp(dependant_variable, 'LAVI')
    noiseChIdx = find(strcmp(noiseCh, groups(1).grandAvg.noise.labels));
end

% --- Plots Setup --- %
close all; figure; hold on;
p = []; % Line handles (for legend)
legend_names = {}; % Legend text

% --- NOISE PLOTTING (LAVI only) --- %
if strcmp(dependant_variable, 'LAVI') && noise_var
    % Pink noise reference line
    h_noise = plot(FOI, G.noise.noise{noiseChIdx}, ...
    'Color', [0.8 0.2 0.5], 'LineWidth', 3);
    p(1)=h_noise(1);
    uistack(h_noise, 'top');
    legend_names{end+1} = 'Pink Noise';
    % Optional: envelope across groups
    allNoise = cat(3, groups.grandAvg); % easier than loop
    allNoise = [];
    for i = 1:numel(plot_groups)
        g_idx = find(strcmp({groups.name}, plot_groups{i}));
        allNoise = cat(3, allNoise, groups(g_idx).grandAvg.noise.noise{noiseChIdx});
    end
    maxNoise = max(allNoise, [], 3);
    minNoise = min(allNoise, [], 3);
    plot(FOI, maxNoise, 'Color', [0 0 0], 'LineWidth', 1.1, 'HandleVisibility', 'off');
    plot(FOI, minNoise, 'Color', [0 0 0], 'LineWidth', 1.1, ...
    'HandleVisibility', 'off');
end

% --- Plot Groups --- %
for i = 1:numel(plot_groups)
    % Which row corresponds to this group name?
    g_idx = find(strcmp({groups.name}, plot_groups{i}));
    % Select correct dependent variable struct
    if strcmp(dependant_variable, 'LAVI')
    G = groups(g_idx).grandAvg;
    dat = groups(g_idx).data_LAVI;
    else
    G = groups(g_idx).GA_fft;
    dat = groups(g_idx).data_fft;
    end

    % Get chosen channels
    [~, chIdx] = ismember(chosen_ch, G.label(:,1));
    chIdx = chIdx(chIdx > 0);
    % Average across channels
    EA.powspctrm = nanmean(G.powspctrm(chIdx,:), 1);
    EA.sd = nanmean(G.sd(chIdx,:), 1);
    clr = groups(g_idx).color;
    % ----- Main line -----
    if strcmp(dependant_variable, 'LAVI') && noise_var
        p(i+1) = plot(FOI, EA.powspctrm, 'LineWidth', 2.5, 'Color', clr);
    else
       p(i) = plot(FOI, EA.powspctrm, 'LineWidth', 2.5, 'Color', clr);
    end
    legend_names{end+1} = sprintf('%s, N=%d', groups(g_idx).name, numel(dat));
    % ----- CI Fill -----
    N = numel(dat);
    err = EA.sd / sqrt(N);
    % Make polygons
    fill([FOI, fliplr(FOI)], ...
    [EA.powspctrm - err, fliplr(EA.powspctrm + err)], ...
    clr, 'FaceAlpha', 0.15, 'EdgeAlpha', 0.2, ...
    'HandleVisibility', 'off');
end

% --- AXES, LABELS, LEGEND ---
xlabel('Frequency (Hz)');
ylabel(dependant_variable);
title_str = {[dependant_variable ' Spectrum'], ...
['Electrodes: ' strjoin(chosen_ch, ', ')]};
if strcmp(dependant_variable, 'LAVI') && noise_var
    title_str{end+1} = ['Pink Noise Electrode: ' noiseCh];
end
title(title_str, 'FontSize', 12);
% X-axis log scale
set(gca, 'XScale', 'log');
xlim(xfoi);
xt = logspace(log10(xfoi(1)), log10(xfoi(2)), 12);
xt = round(xt, 1);
xticks(xt);
xticklabels(string(xt));
xtickangle(0);
axis square;
% Legend
legend(p, legend_names, 'Location', 'northwest'); 


%% ===================================================================== %%
%%          ADDITIONAL PLOT: TALKENNET DATASET ONLY (WITH NOISE)         %%
%% ===================================================================== %%

fprintf('\nGenerating separate plot for TalKennet dataset results...\n');

% 1. Compute grand averages for TalKennet subjects only
groups_tk = groups; % Clone the struct setup (colors, names, labels)

for i = 1:numel(groups_tk)
    current_group_name = string(groups_tk(i).name);
    
    % Re-isolate just the TalKennet dataset participants
    group_IDs_tk = TalKenet_table.Number(TalKenet_table.Group == current_group_name);
    idx_ds2 = ismember(IDs_2_str, group_IDs_tk);
    data_ds2 = LAVI_arr_tk(idx_ds2);
    
    groups_tk(i).data_LAVI = data_ds2; 
    
    if ~isempty(groups_tk(i).data_LAVI)
        % Compute mean scores for TalKennet dataset only
        groups_tk(i).grandAvg = data_grandAvg22(cfg, groups_tk(i).data_LAVI);
        
        % --- NOISE INJECTION ---
        % Since TalKennet has no noise measurements, copy the noise calculation
        % structures over from the combined dataset results
        groups_tk(i).grandAvg.noise = groups(i).grandAvg.noise;
    else
        groups_tk(i).grandAvg = [];
    end
end

% 2. Open a separate figure window for TalKennet only plotting
figure; hold on;
p_tk = []; 
legend_names_tk = {}; 

% --- NOISE PLOTTING (TalKennet Figure) --- 
if strcmp(dependant_variable, 'LAVI') && noise_var
    % Pink noise reference line fetched from the injected noise properties
    h_noise_tk = plot(FOI, groups_tk(1).grandAvg.noise.noise{noiseChIdx}, ...
        'Color', [0.8 0.2 0.5], 'LineWidth', 3);
    p_tk(1) = h_noise_tk(1);
    uistack(h_noise_tk, 'top');
    legend_names_tk{end+1} = 'Pink Noise (OSF Sim)';
    
    % Build envelope across groups using the injected noise data
    allNoise_tk = [];
    for i = 1:numel(plot_groups)
        g_idx = find(strcmp({groups_tk.name}, plot_groups{i}));
        allNoise_tk = cat(3, allNoise_tk, groups_tk(g_idx).grandAvg.noise.noise{noiseChIdx});
    end
    maxNoise_tk = max(allNoise_tk, [], 3);
    minNoise_tk = min(allNoise_tk, [], 3);
    plot(FOI, maxNoise_tk, 'Color', [0 0 0], 'LineWidth', 1.1, 'HandleVisibility', 'off');
    plot(FOI, minNoise_tk, 'Color', [0 0 0], 'LineWidth', 1.1, 'HandleVisibility', 'off');
end

% --- PLOT TALKENNET ONLY GROUPS --- 
for i = 1:numel(plot_groups)
    g_idx = find(strcmp({groups_tk.name}, plot_groups{i}));
    
    G_tk = groups_tk(g_idx).grandAvg;
    dat_tk = groups_tk(g_idx).data_LAVI;
    
    % Get chosen channels
    [~, chIdx] = ismember(chosen_ch, G_tk.label(:,1));
    chIdx = chIdx(chIdx > 0);
    
    % Average across channels
    EA_tk.powspctrm = nanmean(G_tk.powspctrm(chIdx,:), 1);
    EA_tk.sd = nanmean(G_tk.sd(chIdx,:), 1);
    clr = groups_tk(g_idx).color;
    
    % Main line
    if strcmp(dependant_variable, 'LAVI') && noise_var
        p_tk(i+1) = plot(FOI, EA_tk.powspctrm, 'LineWidth', 2.5, 'Color', clr);
    else
        p_tk(i) = plot(FOI, EA_tk.powspctrm, 'LineWidth', 2.5, 'Color', clr);
    end
    legend_names_tk{end+1} = sprintf('%s (TalKennet), N=%d', groups_tk(g_idx).name, numel(dat_tk));
    
    % Confidence Intervals Fill
    N_tk = numel(dat_tk);
    err_tk = EA_tk.sd / sqrt(N_tk);
    fill([FOI, fliplr(FOI)], ...
        [EA_tk.powspctrm - err_tk, fliplr(EA_tk.powspctrm + err_tk)], ...
        clr, 'FaceAlpha', 0.15, 'EdgeAlpha', 0.2, ...
        'HandleVisibility', 'off');
end

% --- FINALIZE AXES, LABELS, LEGEND FOR TALKENNET PLOT ---
xlabel('Frequency (Hz)');
ylabel(dependant_variable);
title_str_tk = {[dependant_variable ' Spectrum - TalKennet Dataset Only'], ...
    ['Electrodes: ' strjoin(chosen_ch, ', ')]};
if strcmp(dependant_variable, 'LAVI') && noise_var
    title_str_tk{end+1} = ['Pink Noise Borrowed From OSF | Electrode: ' noiseCh];
end
title(title_str_tk, 'FontSize', 12);

set(gca, 'XScale', 'log');
xlim(xfoi);
xticks(xt);
xticklabels(string(xt));
xtickangle(0);
axis square;

legend(p_tk, legend_names_tk, 'Location', 'northwest');

% Alternative legend and title
legend(p_tk, {'Pink Noise','ASD, N=11','NT, N=8'}, 'Location', 'northwest');
title({'LAVI Spectrum',legend_names_tk{2},'Pink Noise Electrode: Cz'}, 'FontSize', 12);