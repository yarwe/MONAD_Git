function groups = groupDataByExperiment(env, LAVI_arr, FFT_arr, exp_groups)
% GROUPDATABYEXPERIMENT  Organize LAVI and FFT data into groups by experiment type
%
% Handles both OSF_simple and TalKennet experiments, organizing data into
% groups (ASD, NT, SCZ) for grand averaging and further analysis.
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
switch lower(env.exp)
    case 'osf_simple'
        % OSF_simple: group membership in ID label
        grouping_info = [];  % Not needed for OSF

    case 'talkennet'
        % TalKennet: load group membership from CSV
        grouping_info = loadTalKenetGrouping();

    otherwise
        error('Unknown experiment: %s', env.exp);
end

% Extract LAVI IDs for matching both LAVI and FFT (match original behavior)
LAVI_IDs = cellfun(@(s) s.ID, LAVI_arr, 'UniformOutput', false);
LAVI_IDs_str = string(LAVI_IDs);

% Assign LAVI data to groups
groups = assignDataToGroups(groups, LAVI_arr, grouping_info, env.exp, 'LAVI', LAVI_IDs_str);

% Assign FFT data to groups (use LAVI IDs to match, like original code does)
groups = assignDataToGroups(groups, FFT_arr, grouping_info, env.exp, 'FFT', LAVI_IDs_str);

% Compute grand averages for both LAVI and FFT
groups = computeGrandAverages(groups);

end

% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

function grouping_info = loadTalKenetGrouping()
% Load TalKenet group membership from CSV file
talKenet_group_file = fullfile( ...
    'D:\MONAD ASD project\TalKennet\NIMH data\Package_1235544-Tal Kenet MEG EEG biomarkers', ...
    'Number_group_meg_eeg_biomarkers.csv' ...
);

if ~isfile(talKenet_group_file)
    error('TalKenet group file not found: %s', talKenet_group_file);
end

TalKenet_table = readtable(talKenet_group_file);
TalKenet_table.Number = string(pad(string(TalKenet_table.Number), 6, 'left', '0'));
TalKenet_table.Group = string(TalKenet_table.Group);

% Convert TD to NT for consistency
TalKenet_table.Group(TalKenet_table.Group == "TD") = "NT";

grouping_info.table = TalKenet_table;
grouping_info.type = 'table';
end

% =========================================================================

function groups = assignDataToGroups(groups, data_arr, grouping_info, exp_type, data_type, IDs_str)
% Assign data to groups based on experiment type
%
% INPUTS:
%   groups        : group struct array to populate
%   data_arr      : cell array of data to assign
%   grouping_info : experiment-specific grouping (table or empty)
%   exp_type      : 'osf_simple' or 'talkennet'
%   data_type     : 'LAVI' or 'FFT' (for field naming)
%   IDs_str       : pre-extracted IDs as strings (optional, for matching)

% If IDs not provided, extract from data
if nargin < 6 || isempty(IDs_str)
    IDs = cellfun(@(s) s.ID, data_arr, 'UniformOutput', false);
    IDs_str = string(IDs);
end

% Assign data to each group
field_name = sprintf('data_%s', lower(data_type));
for i = 1:numel(groups)
    idx = getGroupIndices(groups(i), IDs_str, grouping_info, exp_type);
    groups(i).(field_name) = data_arr(idx);
end

% Explicitly return the modified groups
end

% =========================================================================

function idx = getGroupIndices(group, IDs_str, grouping_info, exp_type)
% Get indices of data belonging to a specific group
%
% For OSF_simple: match by label in ID
% For TalKennet: match by group table

switch lower(exp_type)
    case 'osf_simple'
        idx = contains(IDs_str, group.label);

    case 'talkennet'
        this_group = string(group.name);
        group_IDs = grouping_info.table.Number(...
            grouping_info.table.Group == this_group);
        idx = ismember(IDs_str, group_IDs);

    otherwise
        error('Unknown experiment: %s', exp_type);
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
