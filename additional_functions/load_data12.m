function [ftEEG] = load_data(env, filename)
    % load data for each data-set
    clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
    if strcmp(env.exp, 'OSF_simple')
        addpath(genpath(env.paths.eeglab));
        eeglab; close all;
        EEG = pop_biosig(filename);
        ftEEG = biosig2ft(EEG);
        %%
        var = [];
        for i=1:100
            var(:,i) = std(ftEEG.trial{1}(i,:));
        end
        find(var<12)

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
        ftEEG2 = ftEEG;
        ftEEG.label(1:64) = env.lay.label(1:64);
        %ftEEG.label{65} = 'ref1';
        %ftEEG.label{66} = 'ref2';
        % append EEG and EOG
        ftEEG = ft_appenddata([],ftEEG, eogH, eogV);
        
        cfg = [];
        cfg.channel = {'all', '-ref1', '-ref2'};
        ftEEG = ft_selectdata(cfg, ftEEG);


       
    elseif strcmp(env.exp, 'TalKennet')
        cfg = [];
        cfg.dataset = filename;
        ftEEG = ft_preprocessing(cfg);
        ftEEG.trial{1} = ftEEG.trial{1} * 1000000; 

        ftEEG.label = env.lay.label(1:length(ftEEG.label));

    elseif strcmp(env.exp, 'NMSG')
        ftEEG = load(filename);

    elseif strcmp(env.exp, 'IAASA')
        cfg = [];
        cfg.dataset = filename;
        cfg.continuous  = 'yes';
        ftEEG = ft_preprocessing(cfg);
    end
end
