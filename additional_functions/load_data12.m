function [ftEEG] = load_data(env, filename)
    % load data for each data-set
    clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
    
    if strcmp(env.exp, 'OSF') %%% (!!!)  fix for more OSF datasets- for complex
        EEG = pop_biosig(filename);
        ftEEG = biosig2ft(EEG, 'OSF_simple');
        events = ftEEG.cfg.event;
        %%
        ftEEG.label{129} = 'ref1';
        ftEEG.label{130} = 'ref2';
        ftEEG.label{131} = 'eogH1';
        ftEEG.label{132} = 'eogH2';
        ftEEG.label{133} = 'eogV1';
        ftEEG.label{134} = 'eogV2';

        % select eye channels
        cfg = [];
        cfg.channel = {'eogH1', 'eogH2', 'eogV1', 'eogV2'};
        eogDat = ft_selectdata(cfg,ftEEG);

        %extracting EOG signals from horizontal sensors
        cfg = [];
        cfg.channel = {'eogH1' 'eogH2'};
        cfg.refref = 'yes';
        cfg.refchannel = {'eogH1'};
        eogH = ft_preprocessing(cfg,eogDat);
        %keep only one channel and rename to eogH
        cfg = [];
        cfg.channel = {'eogH2'};
        eogH = ft_selectdata(cfg,eogH);
        eogH.label = {'eogH'};

        %extracting EOG signals from vertical sensors
        cfg = [];
        cfg.channel = {'eogV1' 'eogV2'};
        cfg.refref = 'yes';
        cfg.refchannel = {'eogV1'};
        eogV = ft_preprocessing(cfg,eogDat);
        %keep only one channel and rename to eogH
        cfg = [];
        cfg.channel = {'eogV2'};
        eogV = ft_selectdata(cfg,eogV);
        eogV.label = {'eogV'};

        % Select the channels to keep
        cfg = [];
        cfg.channel = {ftEEG.label{1:64}, 'ref1', 'ref2'};
        ftEEG = ft_selectdata(cfg, ftEEG);  % Process the data with the selected channels
        ftEEG.label(1:64) = env.lay.label(1:64);
        %ftEEG.label{65} = 'ref1';
        %ftEEG.label{66} = 'ref2';
        % append EEG and EOG
        ftEEG = ft_appenddata([],ftEEG, eogH, eogV);
        
        cfg = [];
        cfg.channel = {'all', '-ref1', '-ref2'};
        ftEEG = ft_selectdata(cfg, ftEEG);
        ftEEG.cfg.event = events;
        ftEEG.sampleinfo=[1, length(ftEEG.time{1})];
       
    elseif strcmp(env.exp, 'TalKennet')
        cfg = [];
        cfg.dataset = filename;
        ftEEG = ft_preprocessing(cfg);
        
        % Some "EEG" TalKennet datasets actually contain only MEG channels.
        % Warn if no EEG channel is present so the bad dataset can be caught.
        if isfield(ftEEG, 'hdr') && isfield(ftEEG.hdr, 'chantype')
            isEEG = strcmpi(ftEEG.hdr.chantype, 'eeg');
            if ~any(isEEG)
                error('load_data:noEEGchannels', ...
                    'TalKennet dataset "%s" contains no EEG channels (all %d channels are non-EEG, e.g. MEG). Skipping/check this dataset.', ...
                    filename, numel(ftEEG.hdr.chantype));
            end
        end

        ftEEG.trial{1} = ftEEG.trial{1} * 10^6; % Change units from volts to micro volts

        ftEEG.label = env.lay.label(1:length(ftEEG.label));
    
    elseif strcmp(env.exp, 'SFARI_EEG_multi')  
        EEG = pop_biosig(filename);
        ftEEG = biosig2ft(EEG, 'SFARI_EEG_multi');
        % events = ftEEG.cfg.event;
        % ftEEG.cfg.event = events;
        ftEEG.sampleinfo=[1, length(ftEEG.time{1})];

    elseif strcmp(env.exp, 'NMSG')
        ftEEG = load(filename);

    elseif strcmp(env.exp, 'IAASA')
        cfg = [];
        cfg.dataset = filename;
        cfg.continuous  = 'yes';
        ftEEG = ft_preprocessing(cfg);
    end
end
