function [p, legend_names] = plotSpectrum(cfg, groups)
% PLOTSPECTRUM  Plot LAVI or FFT grand-average spectra for one or more groups.
%
% Plots the channel-averaged grand-average spectrum for each requested group,
% with a shaded standard-error band, on a log frequency axis. For LAVI it can
% optionally overlay the pink-noise reference line and its min/max envelope.
%
% INPUTS
%   cfg.dependant_variable : 'LAVI' or 'fft'. Which spectrum to plot. Default 'LAVI'.
%   cfg.plot_groups        : cellstr of group names to plot, e.g. {'ASD','NT'}.
%                            Pass a single name to plot one group only.
%   cfg.chosen_ch          : cellstr of channels to average over.
%   cfg.FOI                : frequency vector (x-axis), e.g. Lcfg.foi.
%   cfg.xfoi               : (optional) [lo hi] x-limits. Default [min max](FOI).
%   cfg.noise_var          : (optional, LAVI only) logical, overlay pink-noise
%                            reference + envelope. Default true.
%   cfg.noiseCh            : (optional, LAVI only) channel label for the pink-noise
%                            trace. Default 'Cz'.
%   cfg.newfig             : (optional) logical, open a new figure. Default true.
%   cfg.exclude_subjects   : (optional) subject IDs to exclude from grand average. Accepts:
%                            - numbers: [101, 102, 103]
%                            - cell of strings: {'030801', '030802'} or {'A1', 'A2'}
%                            - empty: no exclusions (default)
%
%   groups : struct array with fields .name, .color, and (per dependent variable)
%            .GA_LAVI/.data_LAVI or .GA_fft/.data_fft. Each data element should have
%            .ID field with subject ID.
%
% OUTPUTS
%   p            : line handles used for the legend.
%   legend_names : matching legend text.
%
% Example (both groups, LAVI, with pink noise):
%   cfg = [];
%   cfg.dependant_variable = 'LAVI';
%   cfg.plot_groups = {'ASD','NT'};
%   cfg.chosen_ch   = chosen_ch;
%   cfg.FOI = Lcfg.foi; cfg.xfoi = [1 90];
%   cfg.noise_var = true; cfg.noiseCh = 'Cz';
%   plotSpectrum(cfg, groups);
%
% Example (FFT, no noise): cfg.dependant_variable='fft'; cfg.noise_var=false;

% ---- Defaults ----
if ~isfield(cfg, 'dependant_variable') || isempty(cfg.dependant_variable)
    cfg.dependant_variable = 'LAVI';
end
if ~isfield(cfg, 'plot_groups') || isempty(cfg.plot_groups)
    error('plotSpectrum:noGroups', 'cfg.plot_groups is required.');
end
if ~isfield(cfg, 'chosen_ch') || isempty(cfg.chosen_ch)
    error('plotSpectrum:noChannels', 'cfg.chosen_ch is required.');
end
if ~isfield(cfg, 'FOI') || isempty(cfg.FOI)
    error('plotSpectrum:noFOI', 'cfg.FOI (frequency vector) is required.');
end
if ~isfield(cfg, 'xfoi') || isempty(cfg.xfoi)
    cfg.xfoi = [min(cfg.FOI), max(cfg.FOI)];
end
if ~isfield(cfg, 'noiseCh') || isempty(cfg.noiseCh)
    cfg.noiseCh = 'Cz';
end
if ~isfield(cfg, 'newfig') || isempty(cfg.newfig)
    cfg.newfig = true;
end
% [ADDED] Subject exclusion option
if ~isfield(cfg, 'exclude_subjects') || isempty(cfg.exclude_subjects)
    cfg.exclude_subjects = [];
end

% Pink noise only applies to LAVI; force off for fft.
isLAVI = strcmp(cfg.dependant_variable, 'LAVI');
if ~isfield(cfg, 'noise_var') || isempty(cfg.noise_var)
    cfg.noise_var = isLAVI;      % default: on for LAVI, off for fft
end
plot_noise = isLAVI && cfg.noise_var;

dependant_variable = cfg.dependant_variable;
plot_groups = cfg.plot_groups;
chosen_ch   = cfg.chosen_ch;
FOI         = cfg.FOI;
xfoi        = cfg.xfoi;
noiseCh     = cfg.noiseCh;

% Find noise channel index (only needed for LAVI + noise)
if plot_noise
    noiseChIdx = find(strcmp(noiseCh, groups(1).GA_LAVI.noise.labels));
end

% --- Plots Setup --- %
if cfg.newfig; figure; end
hold on;
p = [];            % Line handles (for legend)
legend_names = {}; % Legend text

% --- NOISE PLOTTING (LAVI only, optional) --- %
if plot_noise
    % Pink noise reference line (use the first plotted group's grand-average noise)
    ref_idx = find(strcmp({groups.name}, plot_groups{1}));
    G_ref   = groups(ref_idx).GA_LAVI;
    h_noise = plot(FOI, G_ref.noise.noise{noiseChIdx}, ...
        'Color', [0.8 0.2 0.5], 'LineWidth', 3);
    p(end+1) = h_noise(1);
    uistack(h_noise, 'top');
    legend_names{end+1} = 'Pink Noise';
    % Envelope (min/max) across plotted groups
    allNoise = [];
    for i = 1:numel(plot_groups)
        g_idx = find(strcmp({groups.name}, plot_groups{i}));
        allNoise = cat(3, allNoise, groups(g_idx).GA_LAVI.noise.noise{noiseChIdx});
    end
    maxNoise = max(allNoise, [], 3);
    minNoise = min(allNoise, [], 3);
    plot(FOI, maxNoise, 'Color', [0 0 0], 'LineWidth', 1.1, 'HandleVisibility', 'off');
    plot(FOI, minNoise, 'Color', [0 0 0], 'LineWidth', 1.1, 'HandleVisibility', 'off');
end

% --- Plot Groups --- %
for i = 1:numel(plot_groups)
    % Which row corresponds to this group name?
    g_idx = find(strcmp({groups.name}, plot_groups{i}));
    % Select correct dependent variable struct
    if isLAVI
        G   = groups(g_idx).GA_LAVI;
        dat = groups(g_idx).data_LAVI;
    else
        G   = groups(g_idx).GA_fft;
        dat = groups(g_idx).data_fft;
    end

    % [ADDED] Handle subject exclusion
    dat_filtered = dat;  % Copy original data
    n_excluded = 0;
    if ~isempty(cfg.exclude_subjects)
        dat_filtered = filterExcludeSubjects(dat, cfg.exclude_subjects);
        n_excluded = numel(dat) - numel(dat_filtered);
        if n_excluded > 0
            fprintf('Group "%s": Excluded %d subject(s) from grand average\n', ...
                groups(g_idx).name, n_excluded);
        end
    end

    % Get chosen channels
    [~, chIdx] = ismember(chosen_ch, G.label(:,1));
    chIdx = chIdx(chIdx > 0);
    % Average across channels
    EA.powspctrm = nanmean(G.powspctrm(chIdx,:), 1);
    EA.sd = nanmean(G.sd(chIdx,:), 1);
    clr = groups(g_idx).color;

    % ----- Main line -----
    p(end+1) = plot(FOI, EA.powspctrm, 'LineWidth', 2.5, 'Color', clr); %#ok<AGROW>
    % [MODIFIED] Update legend to show final N after exclusion
    N_final = numel(dat_filtered);
    if n_excluded > 0
        legend_names{end+1} = sprintf('%s, N=%d (%d excluded)', groups(g_idx).name, N_final, n_excluded); %#ok<AGROW>
    else
        legend_names{end+1} = sprintf('%s, N=%d', groups(g_idx).name, N_final); %#ok<AGROW>
    end

    % ----- SE band -----
    N   = N_final;
    err = EA.sd / sqrt(N);
    fill([FOI, fliplr(FOI)], ...
        [EA.powspctrm - err, fliplr(EA.powspctrm + err)], ...
        clr, 'FaceAlpha', 0.15, 'EdgeAlpha', 0.2, 'HandleVisibility', 'off');
end

% --- AXES, LABELS, LEGEND ---
xlabel('Frequency (Hz)');
ylabel(dependant_variable);
title_str = {[dependant_variable ' Spectrum'], ...
    ['Electrodes: ' strjoin(chosen_ch, ', ')]};
if plot_noise
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
end

% ======================================================================= %
% [ADDED] Helper function to filter and exclude specific subjects
function dat_filtered = filterExcludeSubjects(dat, exclude_subjects)
% Filter data by excluding specified subject IDs
% Input:
%   dat              : cell array of FFT/LAVI struct, each with .ID field
%   exclude_subjects : subject IDs to exclude (numbers or strings)
% Output:
%   dat_filtered     : filtered data with excluded subjects removed

% Convert exclude_subjects to cell array of strings for flexible matching
exclude_list = exclude_subjects;
if isnumeric(exclude_list)
    exclude_list = cellfun(@num2str, num2cell(exclude_list), 'UniformOutput', false);
elseif ischar(exclude_list)
    exclude_list = {exclude_list};
elseif iscell(exclude_list)
    % Convert to strings if needed
    exclude_list = cellfun(@(x) iif(isnumeric(x), num2str(x), x), exclude_list, 'UniformOutput', false);
end

% Find subjects to keep
keep_idx = true(numel(dat), 1);
for i = 1:numel(dat)
    subj_id = dat{i}.ID;
    % Handle cell ID
    if iscell(subj_id)
        subj_id = subj_id{1};
    end
    % Convert to string
    subj_id_str = char(string(subj_id));

    % Check if this subject should be excluded
    if any(strcmp(subj_id_str, exclude_list))
        keep_idx(i) = false;
    end
end

% Return filtered data
dat_filtered = dat(keep_idx);
end

% ======================================================================= %
% [ADDED] Inline if function (helper)
function result = iif(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
