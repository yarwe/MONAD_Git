# Peak Frequency Feature - Quick Reference

## TL;DR - Enable & Use

### computeBandPower
```matlab
cfg = [];
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.compute_peak_freq = true;              % ← NEW: Enable peak frequency

bandPow = computeBandPower(cfg, groups);

% Now bandPow includes:
bandPow(1).peakFreq  % [nSubj × 5] peak frequency per subject/band
```

### plotBandPower
```matlab
cfg = [];
cfg.bands = 'all';
cfg.show_peak_freq = true;                 % ← NEW: Display peak frequencies

stats = plotBandPower(cfg, bandPow);
% Plots show mean peak frequency in text box for each group
```

---

## What Changed - Line-by-Line Summary

### computeBandPower.m

```
Line 21-23   | Added docs for cfg.compute_peak_freq
Line 36      | Added docs for bandPow.peakFreq
Line 52-54   | [ADDED] cfg.compute_peak_freq = false (default)
Line 71-75   | [MODIFIED] Struct init - conditionally add peakFreq field
Line 80-82   | [ADDED] peakFreq = nan(nSubj, nBands) initialization
Line 121-122 | [ADDED] Compute peakFreq: peakFreq(s,b) = f(max_idx)
Line 124-126 | [ADDED] Set peakFreq=NaN for invalid band data
Line 151-153 | [ADDED] bandPow(g).peakFreq = peakFreq (output)
```

### plotBandPower.m

```
Line 31-32   | Added docs for cfg.show_peak_freq
Line 53-56   | [ADDED] cfg.show_peak_freq = false (default)
Line 158-167 | [ADDED] Display peak freq text box on plot
```

---

## Output Structure Comparison

### Before (without peak frequency)
```matlab
bandPow(1) = 
    name: 'NT'
    bandNames: {'delta', 'theta', 'alpha', 'beta', 'gamma'}
    bandEdges: [5×2 double]
    abs: [50×5 double]
    rel: [50×5 double]
    IDs: {1×50 cell}
    chan: {3×1 cell}
```

### After (with peak frequency)
```matlab
bandPow(1) = 
    name: 'NT'
    bandNames: {'delta', 'theta', 'alpha', 'beta', 'gamma'}
    bandEdges: [5×2 double]
    abs: [50×5 double]
    rel: [50×5 double]
    peakFreq: [50×5 double]  ← NEW
    IDs: {1×50 cell}
    chan: {3×1 cell}
```

---

## Accessing Peak Frequency Data

```matlab
% Group 1 (NT), all subjects, alpha band (index 3)
alpha_peaks_nt = bandPow(1).peakFreq(:, 3);

% Group 1 (NT), all subjects, all bands
all_peaks_nt = bandPow(1).peakFreq;

% Mean peak frequency for alpha in each group
mean_alpha_nt = nanmean(bandPow(1).peakFreq(:, 3));
mean_alpha_asd = nanmean(bandPow(2).peakFreq(:, 3));

% Subject 10, all bands
subj10_peaks = bandPow(1).peakFreq(10, :);
```

---

## Plot Output

When `cfg.show_peak_freq = true`:

```
┌──────────────────────────────────────────────┐
│        Absolute alpha band                   │
│                                              │
│ ┌─────────────────────────────────────────┐ │
│ │ Peak freq (Hz): NT: 10.2  │  ASD: 9.8  │ │ ← Text box
│ └─────────────────────────────────────────┘ │
│                                              │
│        ●●●●        ●●●●                     │
│        ●●●●        ●●●●                     │
│                                              │
│   NT (N=48)     ASD (N=50)                   │
│   10.4±0.3      9.7±0.4                      │
└──────────────────────────────────────────────┘
```

---

## Configuration Matrix

| Feature | Config Option | Default | Effect |
|---------|---------------|---------|--------|
| Compute peak freq | `cfg.compute_peak_freq` | `false` | Adds peakFreq field to bandPow |
| Display peak freq | `cfg.show_peak_freq` | `false` | Shows peak freq text on plots |
| Exclude subjects | `cfg.exclude_subjects` | `[]` | Removes subjects from plot |
| Show measure | `cfg.measure` | `'both'` | 'abs', 'rel', or 'both' |

---

## Backward Compatibility ✓

Old code still works without changes:
```matlab
% This still works (peak freq features are optional)
cfg = [];
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
bandPow = computeBandPower(cfg, groups);

cfg = [];
stats = plotBandPower(cfg, bandPow);
```

---

## Example Workflow

```matlab
%% 1. Load data and create FFT
% ... your data loading code ...
groups(1).name = 'NT';
groups(1).data_fft = NT_fft_structs;
groups(2).name = 'ASD';
groups(2).data_fft = ASD_fft_structs;

%% 2. Compute band power WITH peak frequencies
cfg = [];
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.compute_peak_freq = true;          % ← Enable peak frequency

bandPow = computeBandPower(cfg, groups);

%% 3. Plot results WITH peak frequencies displayed
cfg = [];
cfg.bands = {'alpha', 'beta'};
cfg.measure = 'abs';
cfg.show_peak_freq = true;             % ← Display peak frequencies

stats = plotBandPower(cfg, bandPow);

%% 4. Analyze peak frequencies programmatically
for b = 1:5
    fprintf('%s: NT=%.1f Hz, ASD=%.1f Hz\n', ...
        bandPow(1).bandNames{b}, ...
        nanmean(bandPow(1).peakFreq(:,b)), ...
        nanmean(bandPow(2).peakFreq(:,b)));
end
```

---

## FAQ

**Q: Does peak frequency replace relative/absolute power?**  
A: No, all three can coexist. Peak frequency is an additional optional metric.

**Q: Can I plot peak frequency?**  
A: Yes, see `cfg.show_peak_freq`. It displays as a text annotation.

**Q: What if peak frequency is NaN?**  
A: Automatically excluded from mean calculation using `nanmean()`.

**Q: Does this break existing code?**  
A: No, both features default to `false` for backward compatibility.

**Q: Where's the frequency resolution?**  
A: Determined by your FFT: `freq_resolution = sampling_rate / FFT_length`

