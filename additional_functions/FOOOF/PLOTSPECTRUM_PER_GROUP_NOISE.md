# plotSpectrum: Per-Group Pink Noise with 95% CI

## What Changed

Updated `plotSpectrum.m` to display **separate pink noise reference for each group** with **group-specific colors** and **95% confidence interval shading**.

---

## Visual Output

### Before
```
- Red line: Pink Noise (single reference for all groups)
- Blue line ± SE: ASD data
- Green line ± SE: NT data
- Black lines: Min/Max envelope of noise (confusing)
```

### After (NEW)
```
- Light Blue line ± 95% CI: ASD data
  - Dark Blue dashed line ± 95% CI: ASD Pink Noise reference
- Light Green line ± 95% CI: NT data  
  - Dark Green dashed line ± 95% CI: NT Pink Noise reference
```

**Key improvements:**
- ✅ Separate pink noise per group (not one global)
- ✅ Each group has its own darker-colored noise reference
- ✅ 95% confidence intervals for both data and pink noise
- ✅ Dashed lines distinguish pink noise from actual data
- ✅ Clear legend showing which noise goes with which group

---

## How It Works

### For Each Group:

1. **Plot group data line** (solid, bright color)
   - Color: Group's assigned color (e.g., light blue for ASD)
   - Shading: 95% CI band (±1.96 × SE)

2. **Plot pink noise line** (dashed, dark color)
   - Color: Darker version of group color (50% darkness)
   - Style: Dashed line (to distinguish from data)
   - Shading: 95% CI band (if available)

3. **Legend entry**: "GroupName - Pink Noise"

---

## Code Changes

### Change 1: Moved Noise Plotting Inside Group Loop

**Before:** Single pink noise plotted once (outside loop)  
**After:** Pink noise plotted separately for each group (inside loop)

```matlab
% --- Plot Groups (with per-group pink noise) --- %
for i = 1:numel(plot_groups)
    % ... get group data ...
    
    % NEW: Pink noise for THIS group
    if plot_noise
        pink_noise_line = G.GA_LAVI.noise.noise{noiseChIdx};
        clr_dark = clr * 0.5;  % Darker shade of group color
        
        % Plot pink noise with 95% CI
        fill([FOI, fliplr(FOI)], ...
            [pink_noise_line - noise_ci, fliplr(pink_noise_line + noise_ci)], ...
            clr_dark, 'FaceAlpha', 0.12, 'EdgeAlpha', 0.15, 'HandleVisibility', 'off');
        
        plot(FOI, pink_noise_line, 'LineWidth', 2, 'Color', clr_dark, 'LineStyle', '--');
    end
    
    % Then plot group data as before...
end
```

### Change 2: Updated 95% CI Calculation

**Before:** Used SE (Standard Error)  
**After:** Uses 95% CI = ±1.96 × SE (true 95% confidence interval)

```matlab
% 95% CI band for LAVI/FFT
SE = EA.sd / sqrt(N);
ci_95 = 1.96 * SE;  % 95% confidence interval
fill([FOI, fliplr(FOI)], ...
    [EA.powspctrm - ci_95, fliplr(EA.powspctrm + ci_95)], ...
    clr, 'FaceAlpha', 0.2, 'EdgeAlpha', 0.3, 'HandleVisibility', 'off');
```

### Change 3: Clearer Title

**Before:** "Pink Noise Electrode: Cz"  
**After:** "Pink Noise (Electrode: Cz, dashed lines = darker group colors)"

---

## Usage Example

```matlab
pcfg = [];
pcfg.dependant_variable = 'LAVI';
pcfg.plot_groups = {'ASD','NT'};
pcfg.chosen_ch = {'Cz'};
pcfg.noise_var = true;         % Enable per-group pink noise
pcfg.noiseCh = 'Cz';
pcfg.FOI = Lcfg.foi;
pcfg.xfoi = [1, 90];

[p, legend_names] = plotSpectrum(pcfg, groups);
```

### Expected Legend Output:
```
ASD - Pink Noise
ASD, N=14
NT - Pink Noise  
NT, N=10
```

---

## Color Scheme

### Example: If groups have these colors:
- **ASD:** Light Blue [0.4, 0.67, 0.8]
- **NT:** Light Green [0.61, 0.81, 0.58]

### Pink Noise Colors (50% darker):
- **ASD Pink Noise:** Dark Blue [0.2, 0.34, 0.4]
- **NT Pink Noise:** Dark Green [0.30, 0.40, 0.29]

---

## 95% CI Interpretation

### What the shaded area means:

**Data shading:** "95% confident the true group mean lies within this band"
- Computed from: ±1.96 × (SD / √N)
- Wider band = less certain about group mean
- Wider band with larger N suggests high variability within group

**Pink Noise shading:** "95% of pink noise simulations fall within this band"
- Shows expected random noise variability
- Compare to data shading to see if group signal exceeds noise

### Visual Interpretation:

```
If data line stays ABOVE pink noise → Signal exceeds noise
If data line crosses pink noise   → Signal and noise overlap
If data shading overlaps noise    → Confidence intervals overlap
```

---

## Technical Details

### Pink Noise Standard Deviation

The code looks for `G.noise.noise_sd` to compute 95% CI for pink noise:

```matlab
if isfield(G, 'noise') && isfield(G.noise, 'noise_sd')
    noise_sd = G.noise.noise_sd{noiseChIdx};
    noise_ci = 1.96 * noise_sd;  % 95% CI
else
    % Fallback: no CI shading for pink noise
    noise_ci = zeros(size(pink_noise_line)) * 0.05;
end
```

**If your structure doesn't have `noise_sd`:**
- Pink noise will still be plotted
- Just without the CI shading
- Consider adding SD calculation to your noise generation code

---

## Advantages of This Approach

| Feature | Benefit |
|---------|---------|
| Per-group noise | See if each group's noise profile differs |
| Color coding | Immediately know which noise matches which group |
| Dashed lines | Distinguish pink noise from actual data |
| 95% CI bands | Proper statistical representation |
| Same alpha for both | Data and noise use consistent transparency |

---

## Example Interpretation

**Scenario 1: ASD > NT in alpha range**

```
ASD (blue):
├─ Data line: HIGH
└─ Pink noise (dark blue dashed): LOW
   ✓ Signal clearly exceeds noise

NT (green):
├─ Data line: MEDIUM
└─ Pink noise (dark green dashed): LOW
   ✓ Signal exceeds noise, but less pronounced
```

**Scenario 2: Group data within pink noise range**

```
ASD (blue):
├─ Data line: OVERLAPS with pink noise
└─ Pink noise shading contains data shading
   ⚠️ Signal may not exceed noise floor
```

---

## Summary

- ✅ **Separate pink noise** for each group
- ✅ **Group colors** for easy identification
- ✅ **95% CI shading** for both data and noise
- ✅ **Dashed lines** for pink noise (distinguish from data)
- ✅ **Clear legend** showing what's what

Run your analysis exactly as before—no changes needed to your call to plotSpectrum!

```matlab
% Your existing code works unchanged:
[p, legend_names] = plotSpectrum(pcfg, groups);
% Just now with per-group pink noise and proper 95% CIs
```
