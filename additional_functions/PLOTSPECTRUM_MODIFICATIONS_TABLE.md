# plotSpectrum - Complete Modifications Table

## Summary of All Changes to plotSpectrum.m

### Documentation Updates

| Line(s) | Type | Content | Change |
|---------|------|---------|--------|
| 15-18 | **ADDED** | cfg.exclude_subjects documentation | New config option for subject exclusion |
| 20-21 | **ADDED** | Groups struct documentation | Added note: "Each data element should have .ID field" |

---

### Configuration & Initialization

| Line(s) | Type | Content | Change |
|---------|------|---------|--------|
| 66-69 | **ADDED** | Default config for exclude_subjects | ```if ~isfield(cfg, 'exclude_subjects') &#124;&#124; isempty(cfg.exclude_subjects) cfg.exclude_subjects = []; end``` |

---

### Main Logic - Data Processing

| Line(s) | Type | Content | Change |
|---------|------|---------|--------|
| 131-141 | **ADDED** | Subject exclusion filtering | Filter dat before grand average calculation |
| | | | ```dat_filtered = filterExcludeSubjects(dat, cfg.exclude_subjects)``` |
| | | | Reports excluded count to console |

| Line(s) | Type | Content | Change |
|---------|------|---------|--------|
| 153-159 | **MODIFIED** | Legend generation | Updated to show final N and excluded count |
| | | Before | ```sprintf('%s, N=%d', groups(g_idx).name, numel(dat))``` |
| | | After | ```sprintf('%s, N=%d (%d excluded)', groups(g_idx).name, N_final, n_excluded)``` |

| Line(s) | Type | Content | Change |
|---------|------|---------|--------|
| 162 | **MODIFIED** | Standard error calculation | Use final N instead of original |
| | | Before | ```N = numel(dat)``` |
| | | After | ```N = N_final``` |

---

### Helper Functions

| Line(s) | Type | Function Name | Purpose |
|---------|------|---------------|---------|
| 192-230 | **ADDED** | `filterExcludeSubjects(dat, exclude_subjects)` | Filters data array to exclude specified subjects |
| 232-238 | **ADDED** | `iif(condition, true_val, false_val)` | Inline if function for format conversion |

---

## Detailed Function Descriptions

### filterExcludeSubjects()

**Location:** Lines 192-230  
**Purpose:** Removes specified subjects from data array  
**Inputs:**
- `dat`: Cell array of FFT/LAVI structs (each with .ID field)
- `exclude_subjects`: Subject IDs to exclude (flexible format)

**Process:**
1. Convert exclude_subjects to strings (flexible handling)
2. Loop through dat and check each subject's ID
3. Mark subjects for removal if ID matches
4. Return filtered dat with matching subjects removed

**Returns:** `dat_filtered` (cell array with excluded subjects removed)

---

### iif()

**Location:** Lines 232-238  
**Purpose:** Inline if-then-else (helper function)  
**Inputs:**
- `condition`: Boolean condition
- `true_val`: Value if condition is true
- `false_val`: Value if condition is false

**Returns:** `result` (true_val or false_val based on condition)

---

## Configuration Option Details

### cfg.exclude_subjects

| Property | Value |
|----------|-------|
| **Location** | Lines 66-69 |
| **Type** | Flexible (numeric array, string, or cell) |
| **Default** | `[]` (no exclusions) |
| **Required** | No |
| **Example** | `{'030801', '030805'}` |

**Accepted Formats:**
```matlab
[101, 102, 103]              % Numeric array
{'030801', '030805'}         % Cell of strings (recommended)
'030801'                     % Single string
101                          % Single number
[]                           % Empty (default)
```

---

## Impact on Output

### Legend Changes

**Before exclusion:**
```
NT, N=50
ASD, N=48
Pink Noise
```

**After excluding {'030801'}:**
```
NT, N=49 (1 excluded)
ASD, N=48
Pink Noise
```

### Console Output

When subjects are excluded:
```
Group "NT": Excluded 1 subject(s) from grand average
```

---

## Data Flow Diagram

```
Input: groups struct + cfg
       ↓
   Load data_LAVI or data_fft
       ↓
   [NEW] filterExcludeSubjects()  ← Subject exclusion
       ↓
   Recalculate grand average
       ↓
   Calculate SE with final N      ← Uses N_final
       ↓
   Plot spectrum
       ↓
   [MODIFIED] Update legend       ← Shows "N (X excluded)"
       ↓
Output: plotted spectrum
```

---

## Code Examples

### Minimal Change Required (User's Code)

**Before:**
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
plotSpectrum(cfg, groups);
```

**After:**
```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = {'030801'};  % ← ONE LINE ADDED

plotSpectrum(cfg, groups);
```

---

## Backward Compatibility

✅ **100% Backward Compatible**

- Default value is `[]` (no exclusions)
- Omitting `cfg.exclude_subjects` defaults to no exclusions
- Old code runs unchanged with identical output
- No breaking changes to function signature

---

## Verification Checklist

- [ ] Function documentation updated (lines 15-21)
- [ ] Config default added (lines 66-69)
- [ ] Data filtering logic added (lines 131-141)
- [ ] Legend updated (lines 153-159)
- [ ] SE calculation uses final N (line 162)
- [ ] Helper functions added (lines 191-238)
- [ ] Test with `cfg.exclude_subjects = {'030801'}`
- [ ] Test without exclude_subjects (backward compatibility)
- [ ] Verify console output shows exclusion count
- [ ] Verify legend shows excluded count

---

## Statistics Recalculated

When subjects are excluded, the following are recalculated:

| Statistic | Before | After |
|-----------|--------|-------|
| N | Original sample size | Final sample size after exclusion |
| Grand average | All subjects | Only non-excluded subjects |
| SD | All subjects | Only non-excluded subjects |
| SE | SE = SD / √N_orig | SE = SD / √N_final |

---

## Files Modified

- ✅ `plotSpectrum.m` - Main function
- ✅ `PLOTSPECTRUM_EXCLUSION_GUIDE.md` - User guide
- ✅ `PLOTSPECTRUM_CHANGES_SUMMARY.md` - Detailed summary
- ✅ `PLOTSPECTRUM_QUICK_REFERENCE.md` - Quick ref
- ✅ `PLOTSPECTRUM_MODIFICATIONS_TABLE.md` - This file

---

## Testing Scenarios

### Scenario 1: Exclude one subject
```matlab
cfg.exclude_subjects = {'030801'};
% Expected: Console shows "Excluded 1 subject(s)"
%           Legend shows "(1 excluded)"
```

### Scenario 2: Exclude multiple subjects
```matlab
cfg.exclude_subjects = {'030801', '030805', '050201'};
% Expected: Console shows "Excluded X subject(s)"
%           Legend shows "(X excluded)"
```

### Scenario 3: Exclude with numeric IDs
```matlab
cfg.exclude_subjects = [101, 102, 103];
% Expected: Auto-converts to strings and filters
```

### Scenario 4: No exclusions (backward compatibility)
```matlab
cfg = [];  % exclude_subjects omitted
% Expected: Normal behavior, no exclusions
%           Legend shows "N=50" (not "50 (0 excluded)")
```

---

## Line Count Summary

| Component | Lines | Type |
|-----------|-------|------|
| Documentation | 7 | Added |
| Configuration | 4 | Added |
| Data filtering | 11 | Added |
| Legend update | 7 | Modified |
| SE calculation | 1 | Modified |
| Helper functions | 48 | Added |
| **Total** | **~60** | **Added/Modified** |

