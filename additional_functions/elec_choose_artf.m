function artif_info = elec_choose_artf(ID, EEG, epochs, varargin)
% ELEC_CHOOSE_ARTF  Interactive artifact review of predefined epochs.
%
% Usage:
%   artif_info = elec_choose_artf(ID, EEG, epochs)
%   artif_info = elec_choose_artf(ID, EEG, epochs, 'context_sec', 5)
%
% Required inputs:
%   ID     - subject identifier (used in title)
%   EEG    - FieldTrip structure (fields: label, trial, fsample)
%   epochs - N×2 matrix: column 1 = SampStart, column 2 = SampEnd
%
% Optional name-value pairs:
%   'context_sec' - seconds of context shown before/after each window (default 10)
%   'chan_range'  - half-range in µV displayed per channel row (default 50)
%   'chan_scale'  - override: full spacing in µV between channel baselines
%   'fs'          - sampling frequency in Hz (default: EEG.fsample)
%
% Output:
%   artif_info - table, one row per epoch, columns:
%                  SampStart       first sample of the epoch
%                  SampEnd         last  sample of the epoch
%                  TimeStart       start time (s)
%                  TimeEnd         end   time (s)
%                  Decision        'keep' | 'all' | 'custom'
%                  RemoveChannels  cell array of channels to remove
%                  RemoveSampStart first sample of the removal window
%                  RemoveSampEnd   last  sample of the removal window

p = inputParser;
addParameter(p, 'context_sec', 10);
addParameter(p, 'chan_range',  50);
addParameter(p, 'chan_scale',  []);
addParameter(p, 'fs',         []);
parse(p, varargin{:});

context_sec = p.Results.context_sec;
chan_range  = p.Results.chan_range;
chan_scale  = p.Results.chan_scale;
fs          = p.Results.fs;

if isempty(fs)
    fs = EEG.fsample;
end

data   = EEG.trial{1};
labels = EEG.label;
nChans = numel(labels);
nSamps = size(data, 2);

if isempty(chan_scale)
    chan_scale = 2 * chan_range;
end

%% Assign a distinct color to each channel (recycled if nChans > palette size)
palette    = lines(max(nChans, 7));
chan_colors = palette(mod((1:nChans)-1, size(palette,1))+1, :);

h_highlight = [];   % handle for currently highlighted line
h_chan_tooltip = []; % text annotation showing channel name

%% Build win_data from epochs matrix
nWins = size(epochs, 1);
win_data(nWins) = struct('SampStart',[],'SampEnd',[],'TimeStart',[],'TimeEnd',[]);
for w = 1:nWins
    ss = epochs(w, 1);
    se = epochs(w, 2);
    win_data(w).SampStart = ss;
    win_data(w).SampEnd   = se;
    win_data(w).TimeStart = (ss - 1) / fs;
    win_data(w).TimeEnd   =  se      / fs;
end

%% Initialise decision state
decisions = struct(...
    'Decision',        repmat({'all'}, 1, nWins), ...
    'RemoveChannels',  repmat({labels},  1, nWins), ...
    'RemoveSampStart', num2cell([win_data.SampStart]), ...
    'RemoveSampEnd',   num2cell([win_data.SampEnd]));

%% Build figure
fig = figure('Name', sprintf('elec_choose_artf — Subject %s', num2str(ID)), ...
    'NumberTitle', 'off', ...
    'Position', [60 60 1280 720], ...
    'CloseRequestFcn', @on_close, ...
    'WindowButtonDownFcn', @on_click);

ax = axes(fig, 'Position', [0.04 0.10 0.62 0.84]);

PX = 0.68;
PW = 0.30;

h_info = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [PX 0.88 PW 0.10], ...
    'HorizontalAlignment', 'left', 'FontSize', 10);

uicontrol(fig, 'Style', 'text', 'String', 'Rejection decision:', ...
    'Units', 'normalized', 'Position', [PX 0.81 PW 0.05], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);

bg = uibuttongroup(fig, 'Units', 'normalized', ...
    'Position', [PX 0.66 PW 0.15], ...
    'BorderType', 'none', ...
    'SelectionChangedFcn', @decision_changed);
h_rb(1) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Keep  (no rejection)', ...
    'Units', 'normalized', 'Position', [0 0.66 1 0.33], 'FontSize', 10);
h_rb(2) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Remove — all channels', ...
    'Units', 'normalized', 'Position', [0 0.33 1 0.33], 'FontSize', 10);
h_rb(3) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Remove — custom selection', ...
    'Units', 'normalized', 'Position', [0 0.00 1 0.33], 'FontSize', 10);

h_chan_lbl = uicontrol(fig, 'Style', 'text', ...
    'String', 'Channels to remove (ctrl-click):', ...
    'Units', 'normalized', 'Position', [PX 0.60 PW 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9, 'Visible', 'off');
h_chanlist = uicontrol(fig, 'Style', 'listbox', ...
    'Units', 'normalized', 'Position', [PX 0.42 PW 0.18], ...
    'String', labels, 'Max', nChans, 'Min', 0, ...
    'FontSize', 8, 'Visible', 'off', ...
    'Callback', @chanlist_changed);

uicontrol(fig, 'Style', 'text', 'String', 'Removal window (s):', ...
    'Units', 'normalized', 'Position', [PX 0.35 PW 0.04], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);

uicontrol(fig, 'Style', 'text', 'String', 'Start:', ...
    'Units', 'normalized', 'Position', [PX 0.30 0.06 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9);
h_tstart = uicontrol(fig, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [PX+0.07 0.30 0.09 0.04], ...
    'FontSize', 9, 'Callback', @time_changed);

uicontrol(fig, 'Style', 'text', 'String', 'End:', ...
    'Units', 'normalized', 'Position', [PX+0.17 0.30 0.05 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9);
h_tend = uicontrol(fig, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [PX+0.23 0.30 0.09 0.04], ...
    'FontSize', 9, 'Callback', @time_changed);

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset to epoch', ...
    'Units', 'normalized', 'Position', [PX 0.25 0.14 0.04], ...
    'FontSize', 9, 'Callback', @reset_window);

uicontrol(fig, 'Style', 'text', 'String', 'Vertical scale:', ...
    'Units', 'normalized', 'Position', [PX 0.18 0.13 0.04], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);
h_scale_lbl = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [PX+0.14 0.18 0.09 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 10, ...
    'String', sprintf('±%g µV', chan_range));
uicontrol(fig, 'Style', 'pushbutton', 'String', '−', ...
    'Units', 'normalized', 'Position', [PX 0.13 0.08 0.04], ...
    'FontSize', 13, 'FontWeight', 'bold', 'TooltipString', 'Zoom out (more range)', ...
    'Callback', @scale_down);
uicontrol(fig, 'Style', 'pushbutton', 'String', '+', ...
    'Units', 'normalized', 'Position', [PX+0.09 0.13 0.08 0.04], ...
    'FontSize', 13, 'FontWeight', 'bold', 'TooltipString', 'Zoom in (less range)', ...
    'Callback', @scale_up);

uicontrol(fig, 'Style', 'pushbutton', 'String', '< Prev', ...
    'Units', 'normalized', 'Position', [PX 0.03 0.08 0.05], ...
    'FontSize', 10, 'Callback', @go_prev);
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Next >', ...
    'Units', 'normalized', 'Position', [PX+0.09 0.03 0.08 0.05], ...
    'FontSize', 10, 'Callback', @go_next);
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [PX+0.19 0.03 0.10 0.05], ...
    'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.6 0.9 0.6], ...
    'Callback', @go_done);

%% First render, then block
fig.UserData = struct('cur', 1);
render_window(1);
uiwait(fig);

%% Collect output
artif_info = build_output();
if isvalid(fig), close(fig); end

% =========================================================================
%  Nested functions
% =========================================================================

    function render_window(w)
        fig.UserData.cur = w;

        wd = win_data(w);
        dc = decisions(w);

        ctx  = round(context_sec * fs);
        c_s1 = max(1, wd.SampStart - ctx);
        c_s2 = min(nSamps, wd.SampEnd + ctx);
        t_vec = (c_s1 : c_s2) / fs;
        seg   = data(:, c_s1:c_s2);

        % NaN-safe linear detrend: previously-rejected samples are NaN,
        % and MATLAB's detrend would propagate a single NaN across the whole
        % channel. Detrend each channel over its finite samples only and
        % leave NaN samples as gaps (they render as breaks in the line).
        for ch = 1:nChans
            y    = seg(ch, :);
            good = ~isnan(y);
            if nnz(good) > 1
                pfit = polyfit(t_vec(good), y(good), 1);
                seg(ch, good) = y(good) - polyval(pfit, t_vec(good));
            end
        end

        h_highlight  = [];
        h_chan_tooltip = [];
        cla(ax); hold(ax, 'on');

        for ch = nChans:-1:1
            offset = (nChans - ch) * chan_scale;
            plot(ax, t_vec, seg(ch,:) + offset, ...
                'Color', chan_colors(ch,:), 'LineWidth', 0.8, ...
                'UserData', ch);
        end

        y_lo = -chan_range;
        y_hi = (nChans - 1) * chan_scale + chan_range;

        art_t1 = (wd.SampStart - 1) / fs;
        art_t2 =  wd.SampEnd       / fs;
        patch(ax, [art_t1 art_t2 art_t2 art_t1], [y_lo y_lo y_hi y_hi], ...
            [1 0.75 0.75], 'FaceAlpha', 0.30, 'EdgeColor', [0.8 0 0], ...
            'LineWidth', 1.5, 'HandleVisibility', 'off');

        rm_s1 = dc.RemoveSampStart;
        rm_s2 = dc.RemoveSampEnd;
        if ~isnan(rm_s1) && (rm_s1 ~= wd.SampStart || rm_s2 ~= wd.SampEnd)
            rm_t1 = (rm_s1 - 1) / fs;
            rm_t2 =  rm_s2      / fs;
            patch(ax, [rm_t1 rm_t2 rm_t2 rm_t1], [y_lo y_lo y_hi y_hi], ...
                [0.75 0.75 1], 'FaceAlpha', 0.30, 'EdgeColor', [0 0 0.8], ...
                'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        set(ax, ...
            'YTick',      (0 : nChans-1) * chan_scale, ...
            'YTickLabel', labels(nChans:-1:1), ...
            'FontSize',   7, ...
            'TickLabelInterpreter', 'none');
        xlabel(ax, 'Time (s)');
        title(ax, sprintf('[%d / %d]  (%.3f – %.3f s)', ...
            w, nWins, wd.TimeStart, wd.TimeEnd), ...
            'Interpreter', 'none', 'FontSize', 10);
        xlim(ax, [t_vec(1) t_vec(end)]);
        ylim(ax, [y_lo y_hi]);

        h_scale_lbl.String = sprintf('±%.4g µV', chan_range);

        h_info.String = sprintf('Window %d / %d\n%.3f – %.3f s', ...
            w, nWins, wd.TimeStart, wd.TimeEnd);

        dec_keys = {'keep','all','custom'};
        sel      = find(strcmp(dec_keys, dc.Decision));
        if isempty(sel), sel = 1; end
        bg.SelectedObject = h_rb(sel);
        set_chanlist_visible(strcmp(dc.Decision, 'custom'));

        if strcmp(dc.Decision, 'custom') && ~isempty(dc.RemoveChannels)
            h_chanlist.Value = find(ismember(labels, dc.RemoveChannels));
        else
            h_chanlist.Value = [];
        end

        h_tstart.String = sprintf('%.4f', (rm_s1 - 1) / fs);
        h_tend.String   = sprintf('%.4f',  rm_s2       / fs);
    end

    function set_chanlist_visible(tf)
        v = onoff(tf);
        h_chan_lbl.Visible = v;
        h_chanlist.Visible = v;
    end

    function s = onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    function go_prev(~,~)
        w = fig.UserData.cur;
        if w > 1, render_window(w - 1); end
    end

    function go_next(~,~)
        w = fig.UserData.cur;
        if w < nWins, render_window(w + 1); end
    end

    function go_done(~,~)
        uiresume(fig);
    end

    function on_close(~,~)
        uiresume(fig);
        delete(fig);
    end

    function decision_changed(~, evt)
        w        = fig.UserData.cur;
        dec_keys = {'keep','all','custom'};
        sel      = find(h_rb == evt.NewValue);
        decisions(w).Decision = dec_keys{sel};

        switch dec_keys{sel}
            case 'keep'
                decisions(w).RemoveChannels = {};
            case 'all'
                decisions(w).RemoveChannels = labels;
            case 'custom'
                % keep whatever was already selected
        end
        render_window(w);
    end

    function chanlist_changed(~,~)
        w = fig.UserData.cur;
        sel = h_chanlist.Value;
        if isempty(sel)
            decisions(w).RemoveChannels = {};
        else
            decisions(w).RemoveChannels = labels(sel);
        end
    end

    function time_changed(~,~)
        w  = fig.UserData.cur;
        t1 = str2double(h_tstart.String);
        t2 = str2double(h_tend.String);
        if isnan(t1) || isnan(t2) || t1 >= t2, return; end
        decisions(w).RemoveSampStart = max(1,      round(t1 * fs) + 1);
        decisions(w).RemoveSampEnd   = min(nSamps, round(t2 * fs));
        render_window(w);
    end

    function reset_window(~,~)
        w  = fig.UserData.cur;
        wd = win_data(w);
        decisions(w).RemoveSampStart = wd.SampStart;
        decisions(w).RemoveSampEnd   = wd.SampEnd;
        render_window(w);
    end

    function scale_up(~,~)
        chan_range = chan_range / 1.5;
        chan_scale = 2 * chan_range;
        h_scale_lbl.String = sprintf('±%.4g µV', chan_range);
        render_window(fig.UserData.cur);
    end

    function scale_down(~,~)
        chan_range = chan_range * 1.5;
        chan_scale = 2 * chan_range;
        h_scale_lbl.String = sprintf('±%.4g µV', chan_range);
        render_window(fig.UserData.cur);
    end

    % ---- Line click: highlight nearest channel and show label ----
    function on_click(~,~)
        % Accept clicks on the axes background OR on any line inside it
        obj = fig.CurrentObject;
        if ~(strcmp(obj.Type, 'axes') || (strcmp(obj.Type, 'line') && ancestor(obj, 'axes') == ax))
            return;
        end
        cp = ax.CurrentPoint;
        click_y = cp(1,2);

        % Find channel whose baseline is closest to the click y-position
        baselines = (nChans-1:-1:0) * chan_scale;   % ch=1 at top → offset=(nChans-1)*chan_scale
        [~, ch] = min(abs(baselines - click_y));

        % Remove previous highlight and tooltip
        if ~isempty(h_highlight) && isvalid(h_highlight)
            delete(h_highlight);
        end
        if ~isempty(h_chan_tooltip) && isvalid(h_chan_tooltip)
            delete(h_chan_tooltip);
        end

        % Draw a bold white+color overlay for the selected channel
        lines_in_ax = findobj(ax, 'Type', 'line');
        target = [];
        for k = 1:numel(lines_in_ax)
            if isequal(lines_in_ax(k).UserData, ch)
                target = lines_in_ax(k);
                break;
            end
        end
        if isempty(target), return; end

        offset = (nChans - ch) * chan_scale;
        % White halo behind, then colored line on top
        plot(ax, target.XData, target.YData, 'w', 'LineWidth', 3.5, ...
            'HandleVisibility', 'off', 'PickableParts', 'none');
        h_highlight = plot(ax, target.XData, target.YData, ...
            'Color', chan_colors(ch,:), 'LineWidth', 2.5, ...
            'HandleVisibility', 'off', 'PickableParts', 'none');

        % Label at the right edge of the axes
        h_chan_tooltip = text(ax, ax.XLim(2), offset, ...
            sprintf('  %s', labels{ch}), ...
            'FontSize', 9, 'FontWeight', 'bold', ...
            'Color', chan_colors(ch,:), ...
            'VerticalAlignment', 'middle', ...
            'HorizontalAlignment', 'left', ...
            'Clipping', 'off', ...
            'PickableParts', 'none');
    end

    function T = build_output()
        SampStart       = [win_data.SampStart]';
        SampEnd         = [win_data.SampEnd]';
        TimeStart       = [win_data.TimeStart]';
        TimeEnd         = [win_data.TimeEnd]';
        Decision        = {decisions.Decision}';
        RemoveChannels  = {decisions.RemoveChannels}';
        RemoveSampStart = cell(nWins, 1);
        RemoveSampEnd   = cell(nWins, 1);
        DataBefore      = cell(nWins, 1);
        DataArtifact    = cell(nWins, 1);
        DataAfter       = cell(nWins, 1);
        TimeBefore      = cell(nWins, 1);
        TimeArtifact    = cell(nWins, 1);
        TimeAfter       = cell(nWins, 1);

        ctx2 = round(2 * fs);   % 2-second context in samples

        for w = 1:nWins
            if strcmp(decisions(w).Decision, 'keep')
                RemoveSampStart{w} = [];
                RemoveSampEnd{w}   = [];
                DataBefore{w}      = [];
                DataArtifact{w}    = [];
                DataAfter{w}       = [];
                TimeBefore{w}      = [];
                TimeArtifact{w}    = [];
                TimeAfter{w}       = [];
            else
                rs1 = decisions(w).RemoveSampStart;
                rs2 = decisions(w).RemoveSampEnd;
                RemoveSampStart{w} = rs1;
                RemoveSampEnd{w}   = rs2;

                chan_idx = find(ismember(labels, decisions(w).RemoveChannels));

                b_s1 = max(1, rs1 - ctx2);
                b_s2 = rs1 - 1;
                if b_s2 >= b_s1
                    DataBefore{w} = data(chan_idx, b_s1:b_s2);
                    TimeBefore{w} = (b_s1:b_s2) / fs;
                else
                    DataBefore{w} = [];
                    TimeBefore{w} = [];
                end

                DataArtifact{w} = data(chan_idx, rs1:rs2);
                TimeArtifact{w} = (rs1:rs2) / fs;

                a_s1 = rs2 + 1;
                a_s2 = min(nSamps, rs2 + ctx2);
                if a_s2 >= a_s1
                    DataAfter{w} = data(chan_idx, a_s1:a_s2);
                    TimeAfter{w} = (a_s1:a_s2) / fs;
                else
                    DataAfter{w} = [];
                    TimeAfter{w} = [];
                end
            end
        end

        T = table(SampStart, SampEnd, TimeStart, TimeEnd, ...
            Decision, RemoveChannels, RemoveSampStart, RemoveSampEnd, ...
            DataBefore, TimeBefore, DataArtifact, TimeArtifact, DataAfter, TimeAfter);
    end

end
