# plotSpectrum: Subject Exclusion Feature

## Overview
The `plotSpectrum` function now supports excluding specific subjects from the grand-average spectrum calculation. This allows you to remove outliers or flagged subjects before computing and plotting group spectra.

## New Configuration Option

### `cfg.exclude_subjects`
Specify which subjects to exclude from the grand average. Accepts multiple formats:

```matlab
% Format 1: Numeric array
cfg.exclude_subjects = [101, 102, 103];

% Format 2: Cell array of strings (like your example)
cfg.exclude_subjects = {'030801', '030802', '030803'};

% Format 3: Single subject
cfg.exclude_subjects = '030801';

% Format 4: Empty (no exclusions - default)
cfg.exclude_subjects = [];
```

---

## Changes by Line Number

| Line(s) | Type | Change |
|---------|------|--------|
| 15-18 | **DOCUMENTATION** | Added cfg.exclude_subjects to INPUTS section |
| 20-21 | **DOCUMENTATION** | Added note about .ID field requirement |
| 65-67 | **ADDED** | New default config: `cfg.exclude_subjects = []` |
| 129-138 | **ADDED** | Filter data and handle exclusions |
| 141-142 | **MODIFIED** | Update legend to show final N and excluded count |
| 147 | **MODIFIED** | Use `N_final` instead of `numel(dat)` |
| 164-205 | **ADDED** | Helper functions: `filterExcludeSubjects` and `iif` |

---

## Usage Examples

### Example 1: Exclude specific outliers
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.FOI = foi;
cfg.exclude_subjects = {'030801', '030805'};  % Remove these subjects

[p, legend_names] = plotSpectrum(cfg, groups);

% Console output:
% Group "NT": Excluded 1 subject(s) from grand average
% Group "ASD": Excluded 1 subject(s) from grand average
```

### Example 2: Exclude by numeric ID
```matlab
cfg = [];
cfg.dependant_variable = 'fft';
cfg.plot_groups = {'NT'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = [101, 105, 127];  % Numeric IDs

plotSpectrum(cfg, groups);
```

### Example 3: No exclusions (default)
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
% exclude_subjects field omitted - uses default (no exclusions)

plotSpectrum(cfg, groups);
```

---

## Output

### Console Output
When subjects are excluded, the console shows:
```
Group "NT": Excluded 2 subject(s) from grand average
Group "ASD": Excluded 1 subject(s) from grand average
```

### Legend Update
The legend automatically updates to show final N and excluded count:
```
Before:  NT, N=50
After:   NT, N=48 (2 excluded)
```

---

## Requirements

### Data Structure
Each element in the `dat` array (either `data_LAVI` or `data_fft`) must have an `.ID` field:

```matlab
dat{1}.ID = '030801'    % String ID
dat{2}.ID = {'030802'}  % or cell array of string
dat{3}.ID = 030803      % or numeric ID
```

If your data doesn't have `.ID` field, you'll need to add it:
```matlab
for i = 1:numel(groups)
    for s = 1:numel(groups(i).data_LAVI)
        groups(i).data_LAVI{s}.ID = your_subject_ids{s};
    end
end
```

---

## Flexible Format Handling

The function automatically converts ID formats:

| Input | Converted To | Example |
|-------|-------------|---------|
| `[101, 102, 103]` | `{'101', '102', '103'}` | Numeric array |
| `'030801'` | `{'030801'}` | Single string |
| `{'030801', '030802'}` | `{'030801', '030802'}` | Cell of strings (unchanged) |
| `{101, 102}` | `{'101', '102'}` | Cell of numbers → strings |

---

## How It Works

1. **Data Filtering**: Subjects matching `exclude_subjects` are removed from the data array
2. **Grand Average**: Spectrum is recalculated using only non-excluded subjects
3. **SE Band**: Standard error is computed with the final N
4. **Reporting**: Console and legend show how many subjects were excluded

### Algorithm
```matlab
1. Receive dat (cell array of structs) and exclude_subjects list
2. For each subject in dat:
   - Get subject ID from dat{i}.ID
   - Convert to string format
   - Compare with exclude_subjects list
   - Mark for removal if match found
3. Return filtered dat with only non-excluded subjects
4. Calculate grand average using filtered data
5. Display final N and excluded count in legend
```

---

## Complete Working Example

```matlab
%% Setup
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.FOI = foi;
cfg.xfoi = [1 90];
cfg.noise_var = true;
cfg.noiseCh = 'Cz';
cfg.newfig = true;

% [NEW] Exclude problematic subjects
cfg.exclude_subjects = {'030801', '030805', '050201'};

% Plot
[p, legend_names] = plotSpectrum(cfg, groups);

% Output:
% Group "NT": Excluded 2 subject(s) from grand average
% Group "ASD": Excluded 1 subject(s) from grand average
%
% Legend shows:
% NT, N=48 (2 excluded)
% ASD, N=47 (1 excluded)
% Pink Noise
```

---

## Troubleshooting

### Q: "Function does not recognize exclude_subjects option"
**A:** Ensure you're using the updated `plotSpectrum.m` file

### Q: Subjects not being excluded
**A:** Check:
1. Subject IDs match exactly (case-sensitive for strings)
2. Subject IDs are in the same format as in data (string vs numeric)
3. Each data struct has an `.ID` field
4. No extra spaces in string IDs

### Q: Grand average changed but legend didn't update
**A:** This shouldn't happen - the legend automatically updates. If it doesn't, the exclude function may not be filtering correctly. Check console output for exclusion messages.

### Q: How many subjects were actually used?
**A:** Check the legend - format is `N=final_count (n_excluded)`

---

## Notes

- **Original data unchanged**: `groups` struct is not modified; filtering only affects the current plot
- **Backward compatible**: Old code without `cfg.exclude_subjects` still works (defaults to no exclusions)
- **Per-group exclusion**: If a subject ID appears in multiple groups, it's excluded from all
- **Silent handling**: Non-existent subject IDs are silently ignored (no error)

---

## Comparison with plotBandPower

Both `plotSpectrum` and `plotBandPower` now support subject exclusion with the same API:

| Feature | plotSpectrum | plotBandPower |
|---------|--------------|---------------|
| Config option | `cfg.exclude_subjects` | `cfg.exclude_subjects` |
| Reporting | Console + legend | Console + plot labels |
| Input formats | Same (flexible) | Same (flexible) |
| Backward compat | Yes | Yes |

