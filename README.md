Project Overview
This repository contains the EEG preprocessing and frequency analysis pipeline. Below is a guide to the codebase structure and how to run it.

Code Organization
Files and functions are numbered to indicate their stage and role:

The first digit(s) indicate the pipeline stage (e.g., 10 runs before 20)
Subsequent digits identify sub-functions belonging to that stage (e.g., setupEnvironment11 is a helper for the 10 stage)
Pipeline
1. preproc10 — Preprocessing
The first script to run. It steps through the following:

Environment setup — setupEnvironment11() loads file paths, FieldTrip, and general variables
Data loading — load_data12() loads participant data from each dataset (paths, file types, etc.)
General preprocessing — demeaning, detrending, filtering, etc.
Automatic artifact removal — detects and removes abnormal peaks in the data using Z-score thresholding
Manual artifact inspection — visual review to identify remaining artifacts and bad channels
Channel repair — fixChannels14() removes artifacts and interpolates bad channels
Logging — a CSV file documents each processing step (filters applied, channels interpolated, etc.)
csv_init15() adds a new row for each participant
csv_addcol16() updates that row as processing progresses
2. freq_analysis20 — Frequency Analysis
The second script to run. Steps:

Set desired parameters for the LAVI calculation (Lcfg) and FFT (Fcfg)
Compute the LAVI and build (or append to) a participant-level data frame using create_datArr21():
cfg.prev = 'add' — compute LAVI for specific participants and append to an existing data frame
cfg.prev = 'all' — recompute LAVI across all clean datasets
If you already have the complete data frame, skip to the load cell
Compute spectral peaks from the LAVI and generate plots	  


