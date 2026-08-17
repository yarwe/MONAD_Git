function groups = groupDataByExperiment(env, LAVI_arr, FFT_arr, exp_groups)
% GROUPDATABYEXPERIMENT  Organize LAVI and FFT data into groups by experiment
%
% Organizes data into groups (ASD, NT, SCZ) for grand averaging and further
% analysis. Which experiment/paradigm the data comes from is taken from the
% environment struct: env.exp names the experiment ('OSF', 'TalKennet', ...)
% and env.paradigm the follow-up paradigm inside it ('simple', 'tactile',
% ...) - see setupEnviroment11 for the full list.
%
% How participants are assigned to groups depends on the experiment, not on
% the paradigm: every paradigm of an experiment shares the same participants
% and therefore the same group membership.
%
% INPUTS:
%   env           : environment struct with paths and settings
%   LAVI_arr      : cell array of LAVI data structures
%   FFT_arr       : cell array of FFT data structures
%   exp_groups    : cell array of group names to include, e.g. {'ASD', 'NT'}
%
% OUTPUT:
%   groups        : struct array with fields:
%     .name       - group name (e.g., 'ASD', 'NT')
%     .label      - single-letter code ('A', 'C', 'S')
%     .color      - RGB color for plotting
%     .data_lavi  - cell array of LAVI structures in this group
%     .data_fft   - cell array of FFT structures in this group
%     .ga_lavi    - grand average LAVI spectrograms for this group
%     .ga_fft     - grand average power spectra (powspctrm) for this group
%
% USAGE:
%   groups = groupDataByExperiment(env, LAVI_arr, FFT_arr, {'ASD', 'NT'});

% Define all available groups with colors
all_groups = struct( ...
    'name', {'ASD', 'NT', 'SCZ'}, ...
    'label', {'A', 'C', 'S'}, ...
    'color', {env.plots.lineASD, env.plots.lineNT, env.plots.lineSCZ} ...
);

% Filter to requested groups
groups = all_groups(ismember({all_groups.name}, exp_groups));

for i = 1:numel(groups)
    groups(i).data_lavi = {};
    groups(i).data_fft = {};
end

% Load experiment-specific grouping information
grouping_info = loadGroupingInfo(env);

% Extract LAVI IDs for matching both LAVI and FFT (match original behavior)
LAVI_IDs = cellfun(@(s) s.ID, LAVI_arr, 'UniformOutput', false);
LAVI_IDs_str = string(LAVI_IDs);

% Assign LAVI data to groups
groups = assignDataToGroups(groups, LAVI_arr, grouping_info, 'LAVI', LAVI_IDs_str);

% Assign FFT data to groups (use LAVI IDs to match, like original code does)
groups = assignDataToGroups(groups, FFT_arr, grouping_info, 'FFT', LAVI_IDs_str);

% Compute grand averages for both LAVI and FFT
groups = computeGrandAverages(groups);

end

% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

function grouping_info = loadGroupingInfo(env)
% Pick the grouping method for this experiment and load whatever it needs.
%
% grouping_info.method decides how getGroupIndices matches IDs:
%   'id_label' - the group's single-letter code is part of the ID itself
%   'table'    - membership comes from a lookup table (grouping_info.table)

switch lower(env.exp)
    case 'osf'
        % OSF: group membership is in the ID label ('A12' / 'C12')
        grouping_info.method = 'id_label';

    case 'talkennet'
        % TalKennet: numeric IDs, group membership comes from a CSV
        grouping_info = loadTalKenetGrouping(env);

    otherwise
        error(['Grouping is not defined for experiment ''%s'' (paradigm ' ...
               '''%s''). Add a case for it in groupDataByExperiment.'], ...
               env.exp, env.paradigm);
end

end

% =========================================================================

function grouping_info = loadTalKenetGrouping(env)
% Load TalKenet group membership from CSV file
%
% The file describes the whole experiment, not one paradigm, so it lives in
% the experiment-level folder (Data/TalKennet/) alongside TK_customLay.mat.

group_file = fullfile(env.paths.exp, 'Number_group_meg_eeg_biomarkers.csv');

if ~isfile(group_file)
    error(['TalKenet group file not found: %s\n' ...
           'It holds the group membership for every TalKennet paradigm, ' ...
           'so it belongs in the experiment-level folder, next to ' ...
           'TK_customLay.mat.'], group_file);
end

TalKenet_table = readtable(group_file);
TalKenet_table.Number = string(pad(string(TalKenet_table.Number), 6, 'left', '0'));
TalKenet_table.Group = string(TalKenet_table.Group);

% Convert TD to NT for consistency
TalKenet_table.Group(TalKenet_table.Group == "TD") = "NT";

grouping_info.table = TalKenet_table;
grouping_info.method = 'table';
end

% =========================================================================

function groups = assignDataToGroups(groups, data_arr, grouping_info, data_type, IDs_str)
% Assign data to groups based on the grouping method
%
% INPUTS:
%   groups        : group struct array to populate
%   data_arr      : cell array of data to assign
%   grouping_info : grouping method and its lookup table, from loadGroupingInfo
%   data_type     : 'LAVI' or 'FFT' (for field naming)
%   IDs_str       : pre-extracted IDs as strings (optional, for matching)

% If IDs not provided, extract from data
if nargin < 5 || isempty(IDs_str)
    IDs = cellfun(@(s) s.ID, data_arr, 'UniformOutput', false);
    IDs_str = string(IDs);
end

% Assign data to each group
field_name = sprintf('data_%s', lower(data_type));
for i = 1:numel(groups)
    idx = getGroupIndices(groups(i), IDs_str, grouping_info);
    groups(i).(field_name) = data_arr(idx);
end

% Explicitly return the modified groups
end

% =========================================================================

function idx = getGroupIndices(group, IDs_str, grouping_info)
% Get indices of data belonging to a specific group

switch grouping_info.method
    case 'id_label'
        idx = contains(IDs_str, group.label);

    case 'table'
        this_group = string(group.name);
        group_IDs = grouping_info.table.Number(...
            grouping_info.table.Group == this_group);
        idx = ismember(IDs_str, group_IDs);

    otherwise
        error('Unknown grouping method: %s', grouping_info.method);
end

end

% =========================================================================

function groups = computeGrandAverages(groups)
% Compute grand averages for both LAVI and FFT data
%
% For each group, computes:
%   .GA_LAVI - grand average of LAVI spectrograms
%   .GA_fft  - grand average of power spectra

% Compute LAVI grand averages (separate cfg to match original behavior)
cfg_lavi = [];
cfg_lavi.channel = 'all';  % Use all channels
cfg_lavi.type = 'LAVI';

for i = 1:numel(groups)
    [groups(i).ga_lavi] = data_grandAvg22(cfg_lavi, groups(i).data_lavi);
end

% Compute FFT grand averages (separate cfg to match original behavior)
cfg_fft = [];
cfg_fft.channel = 'all';  % Use all channels
cfg_fft.type = 'powspctrm';

for i = 1:numel(groups)
    [groups(i).ga_fft] = data_grandAvg22(cfg_fft, groups(i).data_fft);
end

end
