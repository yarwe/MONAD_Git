# Peak Frequency Feature - Implementation Guide

## Overview
Both `computeBandPower` and `plotBandPower` have been extended to support computation and visualization of **peak frequency** (the frequency with maximum power within each frequency band).

---

## Changes to `computeBandPower.m`

### What is Peak Frequency?
For each band and each subject, peak frequency is the single frequency (Hz) that contains the maximum power within that band's frequency range.

**Example:** If alpha band (8-13 Hz) has max power at 10.5 Hz, then `peakFreq('alpha') = 10.5 Hz`

### New Configuration Option

```matlab
cfg.compute_peak_freq = true;   % Enable peak frequency computation (default: false)
```

### Changes by Line Number

| Line(s) | Type | Change |
|---------|------|--------|
| 21-23 | **DOCUMENTATION** | Added cfg.compute_peak_freq to INPUTS section |
| 36 | **DOCUMENTATION** | Added .peakFreq field to OUTPUT section |
| 52-54 | **ADDED** | New default config: `cfg.compute_peak_freq = false` |
| 71-75 | **MODIFIED** | Updated struct definition to conditionally include 'peakFreq' field |
| 80-82 | **ADDED** | Initialize `peakFreq = nan(nSubj, nBands)` array inside group loop |
| 121-122 | **ADDED** | Compute peak frequency within band loop: `peakFreq(s, b) = f(...)` |
| 124-126 | **ADDED** | Set peakFreq to NaN if no valid band data |
| 151-153 | **ADDED** | Assign `bandPow(g).peakFreq = peakFreq` to output struct |

### Usage Example

```matlab
% Compute both absolute/relative power AND peak frequency
cfg = [];
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};  % ROI channels
cfg.compute_peak_freq = true;          % Enable peak frequency computation

bandPow = computeBandPower(cfg, groups);

% Output structure now includes:
% bandPow(1).peakFreq = [nSubj x nBands]  ← NEW FIELD
```

### Output Structure

```matlab
% With cfg.compute_peak_freq = true, bandPow contains:
bandPow(g).name       % 'NT' or 'ASD'
bandPow(g).abs        % [50 x 5] - absolute power per subject/band
bandPow(g).rel        % [50 x 5] - relative power per subject/band
bandPow(g).peakFreq   % [50 x 5] - peak frequency per subject/band ← NEW
bandPow(g).bandNames  % {'delta', 'theta', 'alpha', 'beta', 'gamma'}
bandPow(g).IDs        % subject IDs
```

### Algorithm Details

For each band and subject:
```matlab
1. Extract power spectrum for frequency range [lo, hi]
2. Find index of maximum power: [~, idx_max] = max(P(mask))
3. Convert index back to frequency: peakFreq = f(idx_of_max)
```

---

## Changes to `plotBandPower.m`

### New Configuration Option

```matlab
cfg.show_peak_freq = true;   % Display peak frequencies on plots (default: false)
```

### Changes by Line Number

| Line(s) | Type | Change |
|---------|------|--------|
| 31-32 | **DOCUMENTATION** | Added cfg.show_peak_freq to INPUTS section |
| 53-56 | **ADDED** | New default config: `cfg.show_peak_freq = false` |
| 158-167 | **ADDED** | Display peak frequency text box on plot if requested |

### What Gets Displayed

When `cfg.show_peak_freq = true`, each plot shows:
- **Text box** at top-right with mean peak frequency for each group
- **Format:** "Peak freq (Hz):  NT: 10.2  |  ASD: 9.8"
- **Color:** Gray background for visibility
- **Updates per band:** Changes dynamically for each band plotted

### Usage Example

```matlab
% Plot band power with peak frequencies displayed
cfg = [];
cfg.bands = 'all';
cfg.measure = 'both';
cfg.show_peak_freq = true;     % Display peak frequencies ← NEW

stats = plotBandPower(cfg, bandPow);

% Output:
% - Figures with absolute and relative power distributions
% - Peak frequency text box visible on each subplot
```

### Visual Example

```
╔════════════════════════════════════════════════════════════╗
║            Absolute alpha band                            ║
║                                                            ║
║  Peak freq (Hz): NT: 10.2 | ASD: 9.8                    ║ ← NEW
║                                                            ║
║         ●●●●  ─────────  ●●●●                            ║
║         ●●●●  ─────────  ●●●●                            ║
║                                                            ║
║     NT (N=48)         ASD (N=50)                          ║
║     10.4±0.3          9.7±0.4                             ║
╚════════════════════════════════════════════════════════════╝
```

---

## Complete Working Example

```matlab
%% Step 1: Compute band power WITH peak frequencies
cfg = [];
cfg.chosen_ch = {'Cz', 'CPz', 'Pz'};
cfg.compute_peak_freq = true;           % ← Enable peak frequency

bandPow = computeBandPower(cfg, groups);

%% Step 2: Plot with peak frequency display
cfg = [];
cfg.bands = 'alpha';
cfg.measure = 'abs';
cfg.show_peak_freq = true;              % ← Show peak frequencies

stats = plotBandPower(cfg, bandPow);

%% Step 3: Access peak frequency data programmatically
fprintf('NT Alpha Peak Freq (mean): %.2f Hz\n', nanmean(bandPow(1).peakFreq(:, 3)));
fprintf('ASD Alpha Peak Freq (mean): %.2f Hz\n', nanmean(bandPow(2).peakFreq(:, 3)));

% bandPow(g).peakFreq(:, b) = [nSubj x 1] peak frequencies for group g, band b
```

---

## Important Notes

### 1. Peak Frequency Only Available If Computed
```matlab
% If cfg.compute_peak_freq = false (default):
isfield(bandPow(1), 'peakFreq')  % Returns false
cfg.show_peak_freq = true;        % Has no effect - nothing to display

% If cfg.compute_peak_freq = true:
isfield(bandPow(1), 'peakFreq')  % Returns true
cfg.show_peak_freq = true;        % Displays peak frequencies
```

### 2. Peak Frequency Resolution
Peak frequency resolution depends on FFT resolution:
- FFT bin width = sampling_rate / FFT_length
- Example: 512 Hz sample rate, 1024-point FFT → resolution = 0.5 Hz

### 3. Handling NaN Values
- If a band has no valid data for a subject, `peakFreq = NaN`
- The plot display uses `nanmean()` to compute group mean peak frequency
- Invalid subjects are automatically excluded from the average

### 4. Backward Compatibility
- Old code without `cfg.compute_peak_freq` still works (defaults to false)
- Old code without `cfg.show_peak_freq` still works (defaults to false)
- Both are **optional** - existing workflows unchanged

---

## Troubleshooting

### Q: peakFreq field doesn't exist in bandPow
**A:** Ensure `cfg.compute_peak_freq = true` when calling `computeBandPower`

### Q: Peak frequencies not displaying on plots
**A:** Ensure:
1. `cfg.compute_peak_freq = true` was used in `computeBandPower`
2. `cfg.show_peak_freq = true` in `plotBandPower`

### Q: Peak frequency values seem unreasonable
**A:** Check:
1. Frequency vector in your data (data_fft.freq)
2. Band definitions (cfg.bands)
3. Is peakFreq in expected range [band_lo, band_hi]?

### Q: How do I get peak frequency for a specific band?
```matlab
% Get peak frequencies for alpha band (band index 3)
alpha_peak = bandPow(1).peakFreq(:, 3);  % [nSubj x 1] for group 1

% Group mean peak frequency for alpha
mean_alpha_peak = nanmean(bandPow(1).peakFreq(:, 3));
```

---

## Summary of Modified Lines

### computeBandPower.m
- **Lines Added:** 52-54, 80-82, 121-126, 151-153
- **Lines Modified:** 21-23 (docs), 36 (docs), 71-75 (struct definition)
- **Total Changes:** ~25 lines of code

### plotBandPower.m
- **Lines Added:** 31-32 (docs), 53-56, 158-167
- **Total Changes:** ~15 lines of code

**Total Impact:** ~40 lines added, backward compatible with existing code.

