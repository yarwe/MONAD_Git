function [ftEEG] = load_data(env, filename)
    % load data for each data-set
    addpath('C:\Users\yoelgo\Documents\eeglab2024.2\');
    eeglab; close all
    clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG

    if strcmp(env.exp, 'OSF_simple') || strcmp(env.exp, 'OSF_complex')
        EEG = pop_biosig(filename);
        ftEEG = biosig2ft(EEG);
        
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
        cfg.channel = {env.lay.label{1:64}, 'ref1', 'ref2'};
        ftEEG = ft_selectdata(cfg, ftEEG);  % Process the data with the selected channels
        % append EEG and EOG
        ftEEG = ft_appenddata([],ftEEG, eogH, eogV);
        
    end
end
