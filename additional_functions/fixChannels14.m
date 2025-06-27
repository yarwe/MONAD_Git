function [pEEG_mcleanCh, cellBadCh, cellSegment] = fixChannels14(cfg,data)
% Fix a channel by interpolating it. You can interpolate specific segments
% of the data in a channel or the whole data.
% Also, you can remove channels beforehand, so two neighbouring channels aren't
% interpolated into each other.
%
% cfg.env           the envelope of the whole analysis, see setupEnviroment11
% cfg.badchannel    bad channels to interpolate
% cfg.remchannel    channels to remove before interpolation. needed in some cases
% cfg.segment       segments to interpolate ('all' or {n,m} or {n, 'lst'} where 'lst' is until the end
% cfg.man_blocksize block size used for manual inspection to calculate the data segments to fix

env = cfg.env;
badchannel = {};
seg = {};
man_blocksize = cfg.man_blocksize;

if isfield(cfg, 'badchannel')
    badchannel = cfg.badchannel;
    if any(~ismember(cfg.badchannel, data.label))
    error('One or more of the badchannel names are wrong!!!!!!');
    end
else
    warning('no channels being fixed!')
end

if isfield(cfg, 'segment')
    seg = cfg.segment;
    if length(seg) ~= length(badchannel) && ~strcmp(seg,'all')
    error('Channels and segments not in the same length.');
    end
end


pEEG_mcleanCh = data;
% if no channels were fixed, save the segments and bad channels as '--'
cellSegment = '--';
cellBadCh   = '--';

if strcmp(cfg.remchannel, 'yes')
    for i=1:length(badchannel)
        idx = find(strcmp(badchannel(i), data.label));
        pEEG_mcleanCh.trial{1}(idx,:) = 0;
    end
end

if ~isempty(badchannel)
    if ~isempty(badchannel)
        cfg = [];
        cfg.layout      = env.lay;
        cfg.method      = 'triangulation';
        neighbours      = ft_prepare_neighbours(cfg, pEEG_mcleanCh);
    
        for i=1:length(badchannel)
            cfg = [];
            cfg.badchannel  = {badchannel{i}};
            cfg.neighbours  = neighbours;
            cfg.method      =  'spline';
            cfg.elec        = ft_read_sens([env.paths.ft_path 'template\electrode\standard_1020.elc']);
            if strcmp(seg, 'all')
                segment = {0, 'lst'};
            else
                segment = seg{i};
            end
            if strcmp(segment{2}, 'lst')
                segment{2} = ceil(data.time{1}(end)/man_blocksize);
            end
            segment{1} = segment{1} * man_blocksize;
            segment{2} = segment{2} * man_blocksize;
            cfg2 = [];
            cfg2.latency = [segment{1}, segment{2}];
            tmp = ft_selectdata(cfg2,pEEG_mcleanCh);
            tmp = ft_channelrepair(cfg, tmp);
    
            [~, t1] = min(abs(pEEG_mcleanCh.time{1} - segment{1}));
            [~, t2] = min(abs(pEEG_mcleanCh.time{1} - segment{2}));
            chan_idx = find(strcmp(badchannel{i}, pEEG_mcleanCh.label));
            pEEG_mcleanCh.trial{1}(chan_idx,t1:t2) =  tmp.trial{1}(chan_idx,:);
        end
    else
        pEEG_mcleanCh = ft_channelrepair(cfg, pEEG_mcleanCh);
    end
    
    % save the segments and badchannels as a single cell to be saved in the CSV
    if strcmp(seg, 'all')
        cellSegment = {'all'};
    else
        singleCell_seg = cellfun(@mat2str, [seg{:}], 'UniformOutput', false);
        cellSegment = {strjoin(singleCell_seg, ',')};
    end

    if length(badchannel) > 1; cellBadCh = {strjoin(badchannel, ', ')}; end

end



end