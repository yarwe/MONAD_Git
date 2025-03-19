function [GA_all, GA_elec] = data_grandAvg(cfg,data)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
chosen_ch = cfg.channel;
type = cfg.type;
% average over electrodes
cfg             = [];
cfg.channel     = chosen_ch;
cfg.avgoverchan = 'yes';
cfg.nanmean     = 'yes';

if strcmp(type, 'fft')
    % average FFT over participants
    cfg2 = [];
    cfg2.keepindividual = 'yes';
    GA_all = ft_freqgrandaverage(cfg2, data{:});
    GA_all.sd = log10(squeeze(std(GA_all.powspctrm,1)));
    GA_all.powspctrm = log10(squeeze(mean(GA_all.powspctrm,1)));

    GA_elec  = ft_selectdata(cfg,GA_elec);

elseif strcmp(type,'LAVI')
    % average LAVI over participants
    strct = data{1};
    allCels = cellfun(@(s) s.powspctrm, data, 'UniformOutput', false);
    allCels = cat(3, allCels{:});
    strct.powspctrm = nanmean(allCels, 3);
    strct.sd = nanstd(allCels, 0, 3);
    GA_all = strct;

    GA_elec = ft_selectdata(cfg,GA_all);
end

end