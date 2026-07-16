function [man_art] = open_databrow(EEG, options)
% open fieldtrip databrowser
arguments
    EEG
    % options.channel  (1,:) char   = 'eeg'
    options.ylim      (1,2) double = [-30 30]
    options.demean    (1,:) char   = 'yes'
    options.detrend   (1,:) char   = 'yes'
    options.viewmode  (1,:) char   = 'vertical'
    options.position  (1,4) double = [1 41 1680 933]
    options.blocksize (1,1) double = 30;
    options.event_disp (1,1) double = 0; % Default: don't display event markers
    options.title     (1,:) char   = '';
    options.nchan      (1,1) double  = Inf;
    options.plotlabels (1,:) char    = 'yes'; % 'yes' = never thin the channel labels
end

cfg = [];
if isfinite(options.nchan)
    n = min(options.nchan, numel(EEG.label));
    cfg.channel = EEG.label(1:n);   % first page; GUI channel </> pages by this many
else
    cfg.channel = 'all';            % show every channel at once
end
cfg.plotlabels = options.plotlabels;
cfg.demean    = options.demean;
cfg.detrend   = options.detrend;
cfg.viewmode  = options.viewmode;
cfg.position  = options.position;
cfg.ylim      = options.ylim;
cfg.blocksize = options.blocksize;
if ~options.event_disp
    cfg.plotevents = 'no';
end

% ft_databrowser blocks (uiwait). A timer fires while it is open, finds the
% figure, and drops a persistent title in the top margin (above the
% "segment .../time ..." subtitle). Redraws don't touch annotations.
t = timer('ExecutionMode','fixedSpacing', 'Period',0.3, 'StartDelay',0.3, ...
          'TimerFcn', @(tt,~) add_databrowser_title(tt, options.title));
start(t);
cleanup = onCleanup(@() delete_timer(t));

man_art = ft_databrowser(cfg, EEG);
end

function add_databrowser_title(tt, ttl)
h = findall(0, 'Type', 'figure');
for k = 1:numel(h)
    nm = get(h(k), 'Name');
    if ~(ischar(nm) && contains(nm, 'ft_databrowser')), continue; end
    if ~isempty(findall(h(k), 'Tag', 'db_custom_title')), stop(tt); return; end

    % find the axes that owns the "segment .../ time ..." subtitle, so our
    % title lines up exactly with it (not just any/biggest axes).
    ax = [];
    axesList = findall(h(k), 'Type', 'axes');
    for a = reshape(axesList, 1, [])
        s = get(get(a, 'Title'), 'String');
        if ischar(s) && contains(s, 'segment'), ax = a; break; end
    end
    if isempty(ax)   % fallback: subtitle is a standalone text object
        txt = findall(h(k), 'Type', 'text', '-regexp', 'String', 'segment');
        if ~isempty(txt), ax = ancestor(txt(1), 'axes'); end
    end
    if isempty(ax) && ~isempty(axesList)   % last resort: biggest axes
        areas = arrayfun(@(a) prod(a.Position(3:4)), axesList);
        [~, idx] = max(areas); ax = axesList(idx);
    end

    if ~isempty(ax)
        oldU = get(ax, 'Units'); set(ax, 'Units', 'normalized');
        p = get(ax, 'Position'); set(ax, 'Units', oldU);
        cx = p(1) + p(3)/2 + 0.1;              % horizontal center of the subtitle's axes
    else
        cx = 0.5;
    end
    

    w = 0.60;
    annotation(h(k), 'textbox', [cx - w/2, 0.93, w, 0.045], ...
        'String', ttl, 'Tag', 'db_custom_title', ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'EdgeColor','none', 'FitBoxToText','off', ...
        'FontSize',14, 'FontWeight','bold', 'Interpreter','none');
    stop(tt); return;
end
end

function delete_timer(t)
if isvalid(t)
    stop(t);
    delete(t);
end
end