# plotSpectrum: Subject Exclusion - Quick Reference

## TL;DR

```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = {'030801', '030805'};  % ← NEW: Exclude subjects

plotSpectrum(cfg, groups);
% Console: "Group 'NT': Excluded X subject(s) from grand average"
% Legend: "NT, N=49 (1 excluded)"
```

---

## What Changed - Summary

```
Line 15-21   | [ADDED] Documentation for cfg.exclude_subjects
Line 66-69   | [ADDED] cfg.exclude_subjects = [] (default)
Line 131-141 | [ADDED] Data filtering and exclusion logic
Line 153-159 | [MODIFIED] Legend shows final N and excluded count
Line 162     | [MODIFIED] Use N_final instead of numel(dat)
Line 191-238 | [ADDED] Helper functions
```

---

## Input Formats (All Supported)

```matlab
% Strings (recommended)
cfg.exclude_subjects = {'030801', '030805'};

% Numbers
cfg.exclude_subjects = [101, 102, 103];

% Single
cfg.exclude_subjects = '030801';

% Empty (default)
cfg.exclude_subjects = [];
```

---

## Output Examples

### Console
```
Group "NT": Excluded 2 subject(s) from grand average
Group "ASD": Excluded 1 subject(s) from grand average
```

### Legend Changes
```
Before: NT, N=50
After:  NT, N=48 (2 excluded)
```

---

## Real-World Example

```matlab
%% Setup and exclude your problematic subject
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.FOI = foi;
cfg.xfoi = [1 90];
cfg.noise_var = true;

% Exclude the subject you showed me (030801)
cfg.exclude_subjects = {'030801'};

plotSpectrum(cfg, groups);

% Output:
% Group "NT": Excluded 1 subject(s) from grand average
% Legend: "NT, N=49 (1 excluded)"
```

---

## Key Points

✅ **Backward Compatible**: Old code works unchanged  
✅ **Flexible Input**: Strings, numbers, or single values  
✅ **Smart Conversion**: Auto-converts numeric IDs to strings  
✅ **Clear Reporting**: Console + legend show exclusion details  
✅ **Recalculates**: Grand average uses only included subjects  

---

## Requirement

Your data must have `.ID` field in each subject struct:

```matlab
% Check if your data has IDs
groups(1).data_LAVI{1}.ID  % Should return subject ID (string or number)

% If missing, add it:
groups(1).data_LAVI{1}.ID = '030801';
```

---

## Matches plotBandPower API

Same `cfg.exclude_subjects` option format across both functions:

```matlab
% plotBandPower exclusion
cfg.exclude_subjects = {'030801'};
bandPow = computeBandPower(cfg, groups);

% plotSpectrum exclusion
cfg.exclude_subjects = {'030801'};  % Same format!
plotSpectrum(cfg, groups);
```

---

## FAQ

**Q: Does it change the original data?**  
A: No, filtering only affects the current plot.

**Q: Can I exclude from specific groups only?**  
A: No, if ID matches in any group, it's excluded from all.

**Q: What if subject ID doesn't exist?**  
A: Silently ignored (no error).

**Q: Does this recalculate statistics?**  
A: Yes, grand average and SE use final N after exclusion.

**Q: Can I use this with FFT?**  
A: Yes: `cfg.dependant_variable = 'fft'; cfg.exclude_subjects = {...}`

