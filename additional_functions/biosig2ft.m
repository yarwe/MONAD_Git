function [ftEEG] = biosig2ft(EEG)


    % turn to fieldtrip data
    ftEEG = [];
   
    % Basic Fields
    ftEEG.label    = {EEG.chanlocs.labels};     % Channel labels
    ftEEG.fsample  = EEG.srate;                 % Sampling rate
    ftEEG.trial    = {double(EEG.data)};        % EEG data (convert to double for FieldTrip)
    ftEEG.time     = {EEG.times / 1000};        % Time vector in seconds (FieldTrip uses seconds)
    
    % Dimensionality (important for FieldTrip functions)
    ftEEG.dimord   = 'chan_time';               % Specifies the data format
    
    % Header Information (hdr)
    ftEEG.hdr              = [];
    ftEEG.hdr.Fs           = EEG.srate;                         % Sampling frequency
    ftEEG.hdr.nChans       = EEG.nbchan;                        % Number of channels
    ftEEG.hdr.nSamples     = EEG.pnts;                          % Number of time points
    ftEEG.hdr.nSamplesPre  = 0;                                % Pre-stimulus samples (0 for continuous)
    ftEEG.hdr.nTrials      = EEG.trials;                        % Number of trials (1 if continuous)
    ftEEG.hdr.label        = {EEG.chanlocs.labels};             % Channel labels
    ftEEG.hdr.chantype     = repmat({'eeg'}, EEG.nbchan, 1);    % Define channel types
    ftEEG.hdr.chanunit     = repmat({'µV'}, EEG.nbchan, 1);     % Channel units (microvolts)
    
    % Configuration Field (cfg)
    ftEEG.cfg              = [];
    ftEEG.cfg.dataset      = EEG.filename;                      % Store dataset filename
    ftEEG.cfg.original     = EEG;                               % Keep original EEGLAB struct for reference
    
    clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
end