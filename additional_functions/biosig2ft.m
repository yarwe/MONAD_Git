function [ftEEG] = biosig2ft(EEG, paradigm)
    if nargin < 2
        paradigm = '';
    end

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
    
    % --- OSF_simple event/trigger saving ---
    if strcmpi(paradigm, 'OSF_simple')

        % Numeric code → label map (from SimpleTone_codes.txt)
        codeMap = containers.Map( ...
            {1,  2,    3,     4,    5,    6,    11,           12}, ...
            {'Low_3','Mid_3','High_3','Low_9','Mid_9','High_9','Button_press','Attend_cross'} ...
        );

        nEv = length(EEG.event);
        ev = struct('type', cell(1,nEv), 'value', cell(1,nEv), ...
            'sample', cell(1,nEv), 'offset', cell(1,nEv), ...
            'duration', cell(1,nEv));

        for i = 1:nEv
            code = EEG.event(i).edftype;   % numeric trigger code

            if isKey(codeMap, code)
                label = codeMap(code);
            else
                label = sprintf('unknown_%d', code);
            end

            ev(i).type     = label;
            ev(i).value    = code;
            ev(i).sample   = EEG.event(i).latency;
            ev(i).offset   = [];
            ev(i).duration = [];
        end

        ftEEG.cfg.event = ev;
    end


    clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
end