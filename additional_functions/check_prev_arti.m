% EEG data: [nChannels x nTimepoints]
data = dat_after_ICA{1,1}.trial{1};
times = dat_after_ICA{1,1}.time{1};
art=dat_after_ICA{1}.cfg.previous{1}.previous.artfctdef.visual.artifact;

% --- All-channel NaN regions ---
allChanNaN  = all(isnan(data), 1);
regionsAll  = findRegions(allChanNaN, times);

fprintf('=== All-channel NaN regions (%d) ===\n', numel(regionsAll));
for i = 1:numel(regionsAll)
    r = regionsAll(i);
    fprintf('  Region %d: samples %d–%d | time %.1f–%.1f ms\n', ...
        i, r.sampleStart, r.sampleEnd, r.timeStart, r.timeEnd);
end

% --- Some-channel NaN regions ---
anyChanNaN  = any(isnan(data), 1);
someChanNaN = anyChanNaN & ~allChanNaN;
regionsSome = findRegions(someChanNaN, times);

fprintf('\n=== Some-channel NaN regions (%d) ===\n', numel(regionsSome));
for i = 1:numel(regionsSome)
    r = regionsSome(i);
    nanChanMap = any(isnan(data(:, r.sampleStart:r.sampleEnd)), 2);
    nanChanIdx = find(nanChanMap)';
    fprintf('  Region %d: samples %d–%d | time %.1f–%.1f ms | chans: %s\n', ...
        i, r.sampleStart, r.sampleEnd, r.timeStart, r.timeEnd, mat2str(nanChanIdx));
end

