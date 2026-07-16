# plotBandPower: Subject Exclusion Feature

## Overview
The updated `plotBandPower` function now allows you to exclude specific subjects from plots before analysis. This is useful for removing outliers, flagged subjects, or data quality issues.

## New Configuration Options

### `cfg.exclude_subjects`
Specify which subjects to exclude. Accepts multiple formats:

```matlab
% Format 1: Numeric array
cfg.exclude_subjects = [101, 102, 103];

% Format 2: Cell array of strings
cfg.exclude_subjects = {'A1', 'A2', 'A3'};

% Format 3: Cell array of numeric strings
cfg.exclude_subjects = {'101', '102', '103'};

% Format 4: Single subject
cfg.exclude_subjects = 101;
cfg.exclude_subjects = {'A1'};

% Format 5: Empty (no exclusions - default)
cfg.exclude_subjects = [];
```

### `cfg.subject_ids` (optional)
If your `bandPow` structure doesn't have a `.subjects` field, pass subject IDs via this config:

```matlab
% For a single group
cfg.subject_ids = [101, 102, 103, ..., 150];

% For multiple groups (cell array)
cfg.subject_ids = {
    [101, 102, 103, ...];  % Group 1 IDs
    [201, 202, 203, ...]   % Group 2 IDs
};
```

---

## Setup: Adding Subject IDs to bandPow

### If bandPow doesn't have .subjects field, you need to add it:

```matlab
% After creating bandPow via computeBandPower
for g = 1:numel(bandPow)
    bandPow(g).subjects = your_subject_ids_for_group_g;  % cell or numeric array
end

% Then call plotBandPower normally
cfg = [];
cfg.exclude_subjects = [101, 102];
stats = plotBandPower(cfg, bandPow);
```

---

## Usage Examples

### Example 1: Exclude outliers by subject ID (numeric)
```matlab
cfg = [];
cfg.bands = 'alpha';
cfg.measure = 'both';
cfg.exclude_subjects = [101, 105, 127];  % Remove these subject numbers

% Assuming bandPow has .subjects field with numeric IDs
stats = plotBandPower(cfg, bandPow);

% Output:
% Group "NT": Excluded 2 subject(s): 101, 105
% Group "ASD": Excluded 1 subject(s): 127
```

### Example 2: Exclude by string identifiers
```matlab
cfg = [];
cfg.bands = 'all';
cfg.exclude_subjects = {'sub_001', 'sub_045', 'sub_089'};

stats = plotBandPower(cfg, bandPow);
```

### Example 3: Multiple groups with different IDs
```matlab
% Define subject IDs for each group
cfg = [];
cfg.exclude_subjects = [101, 102];  % Will exclude across all groups
cfg.subject_ids = {
    [101, 102, 103, 104, ...];     % NT group subjects
    [201, 202, 203, 204, ...]      % ASD group subjects
};

stats = plotBandPower(cfg, bandPow);
```

### Example 4: No exclusions (default behavior)
```matlab
cfg = [];
cfg.exclude_subjects = [];  % or just omit this field

stats = plotBandPower(cfg, bandPow);
% Plot includes all subjects
```

---

## Output & Reporting

### Console Output Example
```
Group "NT": Excluded 3 subject(s): 101, 105, 127
Group "ASD": Excluded 2 subject(s): 102, 110
```

### Plot Labels Example
```
Before exclusion:  NT (N=50)  |  ASD (N=48)
After exclusion:   NT (N=47, 3 excluded)  |  ASD (N=46, 2 excluded)
```

The plot title shows:
- **Final N**: Number of subjects included in the plot
- **Excluded count**: How many subjects were removed from each group

### Statistics Output
The returned `stats` struct includes the final N values (after exclusions):
```matlab
stats(1).n = [47, 46];  % Final sample sizes after exclusion
```

---

## Requirements

### Option A: bandPow has .subjects field (RECOMMENDED)
```matlab
% Your bandPow must have:
bandPow(1).subjects = [101, 102, 103, ..., 150];  % subject IDs for group 1
bandPow(2).subjects = [201, 202, 203, ..., 250];  % subject IDs for group 2
```

### Option B: Pass subject IDs in cfg
```matlab
% Alternative if bandPow.subjects doesn't exist
cfg.subject_ids = {
    [101, 102, 103, ...];  % Group 1
    [201, 202, 203, ...]   % Group 2
};
```

---

## Flexible Format Handling

The function automatically handles format conversions:

| Input | Converted To | Example |
|-------|-------------|---------|
| `[101, 102, 103]` | `{'101', '102', '103'}` | Numeric array |
| `'101'` | `{'101'}` | Single string |
| `{'101', '102'}` | `{'101', '102'}` | Cell of strings (unchanged) |
| `{101, 102}` | `{'101', '102'}` | Cell of numbers → strings |

---

## Troubleshooting

### Warning: "No subject IDs found"
```
Warning: Group 1: No subject IDs found. Skipping exclusions for this group.
```
**Solution**: Add `.subjects` field to bandPow or pass `cfg.subject_ids`

### Subjects Not Being Excluded
**Check**:
1. Subject IDs match exactly (case-sensitive)
2. Subject IDs are in the same format (string vs numeric)
3. bandPow.subjects field exists and is correctly populated

**Debug**:
```matlab
% Check what IDs are in bandPow
bandPow(1).subjects  % Print group 1 IDs
bandPow(2).subjects  % Print group 2 IDs

% Check your exclude list
cfg.exclude_subjects  % Print what you're trying to exclude
```

---

## Complete Working Example

```matlab
%% Compute band power for two groups
bandPow = computeBandPower(cfg, EEG_data);

%% Add subject IDs to bandPow
bandPow(1).subjects = NT_subject_ids;   % e.g., [101, 102, 103, ..., 150]
bandPow(2).subjects = ASD_subject_ids;  % e.g., [201, 202, 203, ..., 250]

%% Configure for plotting with exclusions
cfg = [];
cfg.bands = 'all';
cfg.measure = 'both';
cfg.units = 'µV²/Hz';
cfg.exclude_subjects = [105, 110, 127];  % Remove identified outliers

%% Create plots
stats = plotBandPower(cfg, bandPow);

%% Review output
% Console shows:
% "Group 'NT': Excluded 2 subject(s): 105, 110"
% "Group 'ASD': Excluded 1 subject(s): 127"
%
% Plot x-axis shows:
% "NT (N=48, 2 excluded)"
% "ASD (N=47, 1 excluded)"
```

---

## Notes

- **Exclusions are applied per-group**: If a subject ID exists in multiple groups, it's excluded from all
- **Non-existent IDs are silently ignored**: If you try to exclude subject ID 999 but it doesn't exist, the function skips it
- **Original bandPow is NOT modified**: Exclusions only affect the plots and stats; the input `bandPow` remains unchanged
- **All statistics (t-test, Cohen's d) use final N**: The between-group comparison uses the final sample sizes after exclusion

