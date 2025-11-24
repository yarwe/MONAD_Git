function [grandAvg] = data_grandAvg22(cfg,data)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
chosen_ch = cfg.channel;
type = cfg.type;
% average over electrodes
cfg             = [];
cfg.channel     = chosen_ch;
cfg.avgoverchan = 'yes';
cfg.nanmean     = 'yes';

if strcmp(type, 'powspctrm')
    % average FFT over participants
    cfg2 = [];
    cfg2.keepindividual = 'yes';
    grandAvg = ft_freqgrandaverage(cfg2, data{:});
    grandAvg.sd = log10(squeeze(std(grandAvg.powspctrm,1)));
    grandAvg.powspctrm = log10(squeeze(mean(grandAvg.powspctrm,1)));
    grandAvg.ID = 'grandAvg';

elseif strcmp(type,'LAVI')
    % average LAVI over participants
    strct = data{1};
    allCels = cellfun(@(s) s.powspctrm, data, 'UniformOutput', false);
    allCels = cat(3, allCels{:});
    strct.powspctrm = nanmean(allCels, 3);
    strct.sd = nanstd(allCels, 0, 3);
    grandAvg = strct;

    avgNoise = cell(1, 11);
    for k = 1:11
        mats = cellfun(@(s) s.noise.noise{k}, data, 'UniformOutput', false);
        avgNoise{k} = nanmean(cat(3, mats{:}), 3);
    end
    rowMax = cellfun(@(m) max(m, [], 1), avgNoise, 'UniformOutput', false);
    rowMin = cellfun(@(m) min(m, [], 1), avgNoise, 'UniformOutput', false);

    grandAvg.noise.noise = avgNoise;
    grandAvg.noise.max = rowMax;
    grandAvg.noise.min = rowMin;
    grandAvg.ID = 'grandAvg';
end
end

