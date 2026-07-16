function regions = findRegions(mask, times)
    % returns struct array with fields: sampleStart, sampleEnd, timeStart, timeEnd
    d = diff([0, mask, 0]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;
    regions = struct('sampleStart', num2cell(starts), ...
                     'sampleEnd',   num2cell(ends), ...
                     'timeStart',   num2cell(times(starts)), ...
                     'timeEnd',     num2cell(times(ends)));
end