# plotSpectrum: Subject Exclusion Feature - Complete Summary

## What Changed?

The `plotSpectrum` function now supports excluding specific subjects from the grand-average spectrum calculation by adding a new configuration option: `cfg.exclude_subjects`.

---

## Quick Start

### Before (No Exclusions)
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;

plotSpectrum(cfg, groups);
% All subjects included
```

### After (With Exclusions)
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = {'030801', '030805'};  % ← NEW

plotSpectrum(cfg, groups);
% Specified subjects excluded
% Console: "Group 'NT': Excluded 1 subject(s) from grand average"
% Legend: "NT, N=49 (1 excluded)"
```

---

## Line-by-Line Changes

### Documentation (Lines 9-21)
```
Line 15-18 | [ADDED] Documented cfg.exclude_subjects input option
Line 20-21 | [ADDED] Noted .ID field requirement for subjects
```

### Configuration Setup (Lines 66-69)
```matlab
% [ADDED] Subject exclusion option
if ~isfield(cfg, 'exclude_subjects') || isempty(cfg.exclude_subjects)
    cfg.exclude_subjects = [];
end
```

### Data Processing (Lines 131-141)
```matlab
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
```

### Legend Update (Lines 153-159)
```matlab
% [MODIFIED] Update legend to show final N after exclusion
N_final = numel(dat_filtered);
if n_excluded > 0
    legend_names{end+1} = sprintf('%s, N=%d (%d excluded)', groups(g_idx).name, N_final, n_excluded);
else
    legend_names{end+1} = sprintf('%s, N=%d', groups(g_idx).name, N_final);
end
```

### Standard Error Calculation (Line 162)
```matlab
% [MODIFIED] Use N_final instead of numel(dat)
N = N_final;
```

### Helper Functions (Lines 191-238)
```matlab
% [ADDED] filterExcludeSubjects function
% [ADDED] iif (inline if) helper function
```

---

## Configuration Options

### cfg.exclude_subjects

**Type:** Flexible (multiple formats accepted)  
**Default:** `[]` (no exclusions)  
**Required:** No

**Accepted Formats:**

```matlab
% Numeric array
cfg.exclude_subjects = [101, 102, 103];

% String cell array (RECOMMENDED for ID-based exclusion)
cfg.exclude_subjects = {'030801', '030805', '050201'};

% Single subject (string)
cfg.exclude_subjects = '030801';

% Single subject (number)
cfg.exclude_subjects = 101;

% Mixed cell (auto-converted to strings)
cfg.exclude_subjects = {101, '030801'};

% Empty (default - no exclusions)
cfg.exclude_subjects = [];
```

---

## Output Examples

### Console Output
When subjects are excluded, you'll see:
```
Group "NT": Excluded 2 subject(s) from grand average
Group "ASD": Excluded 1 subject(s) from grand average
```

### Legend Changes
**Before:**
```
NT, N=50
ASD, N=48
Pink Noise
```

**After:**
```
NT, N=48 (2 excluded)
ASD, N=47 (1 excluded)
Pink Noise
```

---

## Usage Examples

### Example 1: Your Specific Case (Exclude 030801)
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = {'030801'};  % Exclude this subject

[p, legend_names] = plotSpectrum(cfg, groups);
```

### Example 2: Exclude Multiple Subjects
```matlab
cfg.exclude_subjects = {'030801', '030805', '050201', '101501'};
```

### Example 3: FFT with Exclusions
```matlab
cfg.dependant_variable = 'fft';  % FFT instead of LAVI
cfg.exclude_subjects = [101, 105, 127];  % Numeric IDs
```

### Example 4: Conditional Exclusion
```matlab
% Only exclude if needed
bad_subjects = {};  % Empty by default

% Add subject if some condition is met
if some_condition
    bad_subjects = {'030801'};
end

cfg.exclude_subjects = bad_subjects;
```

---

## Data Requirements

Each subject in the data struct must have an `.ID` field:

```matlab
% Example data structure
groups(1).data_LAVI{1}.ID = '030801'    % String ID
groups(1).data_LAVI{2}.ID = {'030802'}  % or cell array
groups(1).data_LAVI{3}.ID = 30803       % or numeric ID
```

### Adding .ID if Missing
```matlab
for g = 1:numel(groups)
    for s = 1:numel(groups(g).data_LAVI)
        groups(g).data_LAVI{s}.ID = your_subject_IDs{s};
    end
end
```

---

## How It Works (Algorithm)

1. **Input Check**: User provides `cfg.exclude_subjects` (or uses default)
2. **Format Conversion**: Convert all IDs to strings for comparison
3. **Data Filtering**:
   - Loop through each subject in `dat`
   - Extract subject ID from `dat{i}.ID`
   - Compare with exclude list
   - Mark for exclusion if matched
4. **Filtered Grand Average**:
   - Calculate spectrum using only non-excluded subjects
   - Recalculate SE with final N
5. **Reporting**:
   - Print to console how many were excluded
   - Update legend to show final N and excluded count

---

## Backward Compatibility ✓

✅ Old code still works without any changes:

```matlab
% This will work exactly as before (no exclusions)
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
plotSpectrum(cfg, groups);
```

---

## Complete Working Example

```matlab
%% Load your data and set up groups
% ... your data loading code ...

%% Configure plot with subject exclusion
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.FOI = foi;
cfg.xfoi = [1 90];
cfg.noise_var = true;
cfg.noiseCh = 'Cz';

% [NEW] Exclude problematic subjects
cfg.exclude_subjects = {'030801', '030805'};

%% Create plot
figure;
[p, legend_names] = plotSpectrum(cfg, groups);

% Console output:
% Group "NT": Excluded 1 subject(s) from grand average
% Group "ASD": Excluded 1 subject(s) from grand average
%
% Plot legend:
% NT, N=49 (1 excluded)
% ASD, N=47 (1 excluded)
% Pink Noise
```

---

## Comparison with plotBandPower Exclusion

Both functions now support subject exclusion with compatible APIs:

| Aspect | plotSpectrum | plotBandPower |
|--------|--------------|---------------|
| Config option | `cfg.exclude_subjects` | `cfg.exclude_subjects` |
| Input formats | Same (flexible) | Same (flexible) |
| Reporting | Console + legend | Console + plot labels |
| Backward compat | Yes | Yes |
| Recalculates stats | Grand average only | T-test, Cohen's d |

---

## Troubleshooting

### Q: Subjects not being excluded?

**Check:**
1. Subject IDs match exactly (case-sensitive)
2. Format is correct (string vs numeric)
3. Each data struct has `.ID` field
4. No extra spaces in string IDs

**Debug:**
```matlab
% Check what IDs are in your data
for i = 1:3
    disp(groups(1).data_LAVI{i}.ID)
end

% Check your exclude list
disp(cfg.exclude_subjects)
```

### Q: Console shows no exclusions but I specified them?

**Check:** Are the IDs exactly the same? String comparison is case-sensitive.

### Q: How do I verify the exclusion worked?

Look for:
1. Console message: "Excluded N subject(s)"
2. Legend update: Shows "(N excluded)"
3. Change in grand average shape (if excluding outliers)

---

## Summary of Changes

| Component | Lines | Type | Change |
|-----------|-------|------|--------|
| **Documentation** | 15-21 | Added | Input/output docs for exclude_subjects |
| **Config default** | 66-69 | Added | Initialize cfg.exclude_subjects |
| **Data filtering** | 131-141 | Added | Filter excluded subjects from data |
| **Legend update** | 153-159 | Modified | Show final N and excluded count |
| **SE calculation** | 162 | Modified | Use N_final instead of original N |
| **Helper functions** | 191-238 | Added | filterExcludeSubjects() and iif() |

**Total Impact:** ~60 lines added/modified, fully backward compatible

