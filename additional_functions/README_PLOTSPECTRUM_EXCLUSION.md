# plotSpectrum Subject Exclusion Feature - Documentation Index

## Overview
This is the complete documentation for the subject exclusion feature added to `plotSpectrum.m`. Choose the document that best fits your needs.

---

## 📚 Documentation Files

### 1. **PLOTSPECTRUM_QUICK_REFERENCE.md** ⭐ START HERE
- **Best for:** Quick lookup and copy-paste examples
- **Length:** 2 pages
- **Contains:** TL;DR, input formats, real-world examples
- **When to use:** You just want to use the feature quickly

```matlab
cfg.exclude_subjects = {'030801', '030805'};
plotSpectrum(cfg, groups);
```

### 2. **PLOTSPECTRUM_EXCLUSION_GUIDE.md**
- **Best for:** Complete user guide with detailed examples
- **Length:** 4 pages
- **Contains:** Usage examples, troubleshooting, requirements, data structure
- **When to use:** You need comprehensive understanding

### 3. **PLOTSPECTRUM_CHANGES_SUMMARY.md**
- **Best for:** Understanding what changed and how
- **Length:** 5 pages
- **Contains:** Before/after code, algorithm explanation, working examples
- **When to use:** You want to understand the implementation

### 4. **PLOTSPECTRUM_MODIFICATIONS_TABLE.md**
- **Best for:** Exact line-by-line modifications reference
- **Length:** 6 pages
- **Contains:** Complete line numbers, function descriptions, verification checklist
- **When to use:** You need precise technical details (or are code-reviewing)

---

## 🎯 Quick Usage Guide

### Your Specific Use Case (Exclude 030801)

```matlab
cfg = [];
cfg.dependant_variable = 'LAVI';
cfg.plot_groups = {'NT', 'ASD'};
cfg.chosen_ch = chosen_ch;
cfg.FOI = foi;
cfg.exclude_subjects = {'030801'};  % ← Your subject

[p, legend_names] = plotSpectrum(cfg, groups);

% Output:
% Group "NT": Excluded 1 subject(s) from grand average
% Legend: "NT, N=49 (1 excluded)"
```

### Flexible Input Formats

All these work the same way:

```matlab
cfg.exclude_subjects = {'030801'};              % Recommended: strings
cfg.exclude_subjects = '030801';                % Single string
cfg.exclude_subjects = [30801];                 % Single number
cfg.exclude_subjects = {'030801', '030805'};   % Multiple subjects
cfg.exclude_subjects = [101, 102, 103];        % Multiple numbers
cfg.exclude_subjects = [];                      % No exclusions (default)
```

---

## 🔍 Finding Specific Information

### "How do I use this feature?"
→ **PLOTSPECTRUM_QUICK_REFERENCE.md**

### "What if my data doesn't have .ID field?"
→ **PLOTSPECTRUM_EXCLUSION_GUIDE.md** → Troubleshooting → "Data Structure"

### "Show me the exact line numbers that changed"
→ **PLOTSPECTRUM_MODIFICATIONS_TABLE.md** → First table

### "How does the filtering algorithm work?"
→ **PLOTSPECTRUM_CHANGES_SUMMARY.md** → "How It Works (Algorithm)"

### "I'm code-reviewing, what changed?"
→ **PLOTSPECTRUM_MODIFICATIONS_TABLE.md** → "Summary of All Changes"

### "What was the output before/after exclusion?"
→ **PLOTSPECTRUM_CHANGES_SUMMARY.md** → "Output Examples"

---

## 📊 Comparison with plotBandPower

Both functions now support the same exclusion API:

```matlab
% plotBandPower
cfg.exclude_subjects = {'030801'};
stats = plotBandPower(cfg, bandPow);

% plotSpectrum  
cfg.exclude_subjects = {'030801'};  % Same option!
plotSpectrum(cfg, groups);
```

See: **PLOTSPECTRUM_EXCLUSION_GUIDE.md** → "Comparison with plotBandPower"

---

## 🆘 Troubleshooting

### Quick Checklist

- [ ] Subject IDs match exactly (case-sensitive)
- [ ] Format is correct (string vs numeric)  
- [ ] Your data has .ID field in each struct
- [ ] No extra spaces in string IDs
- [ ] Using correct field name: `cfg.exclude_subjects`

**Still stuck?** See **PLOTSPECTRUM_EXCLUSION_GUIDE.md** → Troubleshooting

---

## 📝 Key Changes Summary

| Aspect | Details |
|--------|---------|
| **New Config** | `cfg.exclude_subjects` |
| **Formats** | Strings, numbers, single or multiple |
| **Default** | `[]` (no exclusions) |
| **Backward Compat** | ✅ Yes, fully compatible |
| **Lines Changed** | ~60 lines added/modified |
| **Console Output** | Shows exclusion count |
| **Legend Output** | Shows final N and excluded count |
| **Helper Functions** | `filterExcludeSubjects()` and `iif()` |

---

## 🚀 Common Use Cases

### Case 1: Exclude Known Outlier
```matlab
cfg.exclude_subjects = {'030801'};  % One problematic subject
```

### Case 2: Exclude Multiple Bad Subjects  
```matlab
cfg.exclude_subjects = {'030801', '030805', '050201'};
```

### Case 3: Exclude No One (Default)
```matlab
% Just don't specify exclude_subjects
cfg = [];  % exclude_subjects omitted
```

### Case 4: Conditional Exclusion
```matlab
bad_subjects = {};
if is_this_bad; bad_subjects = {'030801'}; end
cfg.exclude_subjects = bad_subjects;
```

---

## 📖 Reading Order

**For first-time users:**
1. Start with this file (README)
2. Jump to PLOTSPECTRUM_QUICK_REFERENCE.md
3. Try your first example
4. Reference PLOTSPECTRUM_EXCLUSION_GUIDE.md as needed

**For code review:**
1. Read PLOTSPECTRUM_MODIFICATIONS_TABLE.md
2. Check verification checklist
3. Review helper functions section

**For troubleshooting:**
1. Check "Quick Checklist" above
2. Go to PLOTSPECTRUM_EXCLUSION_GUIDE.md → Troubleshooting
3. Verify data structure requirements

---

## ✅ Verification

The feature is ready to use. Verify with:

```matlab
% Test 1: Exclude one subject
cfg.exclude_subjects = {'030801'};
% Expected: Console shows "Excluded 1"

% Test 2: Exclude nothing
cfg = [];
% Expected: Normal output, no exclusion messages

% Test 3: Multiple subjects
cfg.exclude_subjects = {'030801', '030805'};
% Expected: Console shows "Excluded 2"
```

---

## 📞 Questions?

- **"Does this change my original data?"** No, only affects current plot
- **"Can I exclude from one group only?"** No, excludes from all groups with matching ID
- **"What if subject ID doesn't exist?"** Silently ignored
- **"Does this recalculate stats?"** Yes, grand average and SE use final N
- **"Is this backward compatible?"** Yes, 100%

---

## 🎓 Technical Details

**Configuration Lines:** 66-69  
**Filter Logic Lines:** 131-141  
**Legend Update Lines:** 153-159  
**Helper Functions Lines:** 191-238  
**Total Lines Modified:** ~60

See PLOTSPECTRUM_MODIFICATIONS_TABLE.md for complete breakdown.

---

## 📚 All Documentation Files

```
plotSpectrum/
├── README_PLOTSPECTRUM_EXCLUSION.md (this file)
├── PLOTSPECTRUM_QUICK_REFERENCE.md ⭐ START HERE
├── PLOTSPECTRUM_EXCLUSION_GUIDE.md
├── PLOTSPECTRUM_CHANGES_SUMMARY.md
└── PLOTSPECTRUM_MODIFICATIONS_TABLE.md
```

---

## ✨ Feature Highlights

✅ **Easy to use:** Just add one config line  
✅ **Flexible input:** Strings, numbers, or single values  
✅ **Clear reporting:** Console and legend show what was excluded  
✅ **Recalculates:** Grand average uses only included subjects  
✅ **Backward compatible:** Old code works unchanged  
✅ **Same API:** Matches `plotBandPower` exclusion feature  

---

**Last Updated:** 2026-07-19  
**Version:** plotSpectrum.m with subject exclusion feature  
**Status:** ✅ Ready to use
