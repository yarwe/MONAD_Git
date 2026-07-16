function artf_out = concat_man_artf(artf, fs, min_gap_s)
% If artifacts are too close (less than 50ms, they are concatenated)
% art is a matrix - 1st coloum is the sample start, 2nd is the sample end
if nargin < 2, fs = 512; end
if nargin < 3, min_gap_s = 0.05; end

min_gap = round(min_gap_s * fs);

artf = sortrows(artf, 1);

% Find where gaps between consecutive artifacts exceed the threshold
gaps      = artf(2:end, 1) - artf(1:end-1, 2);  % gap between end_i and start_{i+1}
new_group = [true; gaps > min_gap];               % first row always starts a group

group_ids = cumsum(new_group);
artf_out  = [accumarray(group_ids, artf(:,1), [], @min), ...
             accumarray(group_ids, artf(:,2), [], @max)];
end