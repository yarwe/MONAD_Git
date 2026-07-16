function artif_info = detect_arti(ID, EEG, max_var_win_info, varargin)
% DETECT_ARTI  Interactive artifact review of high-variance epochs.
%
% For each unique high-variance window in max_var_win_info, displays a
% stacked-channel plot with ±context_sec of context. Flagged channels are
% drawn as bold black lines; all others are grey. Navigation buttons step
% through windows. Per-window controls let you decide whether to reject the
% epoch for all channels, flagged channels only, a custom channel set, or
% not at all. The removal time window can be adjusted manually.
%
% Usage:
%   artif_info = detect_arti(ID, EEG, max_var_win_info)
%   artif_info = detect_arti(ID, EEG, max_var_win_info, 'context_sec', 5)
%
% Required inputs:
%   ID               - subject identifier (used in title)
%   EEG              - FieldTrip structure (fields: label, trial, fsample)
%   max_var_win_info - table from plot_var_all_chans with columns:
%                        Channel, Rank, WinIdx, SampStart, SampEnd,
%                        TimeStart, TimeEnd
%
% Optional name-value pairs:
%   'context_sec' - seconds of context shown before/after each window (default 10)
%   'chan_range'  - half-range in µV displayed per channel row (default 5).
%                   Each channel baseline is spaced 2*chan_range apart, so the
%                   visible window per channel is [–chan_range, +chan_range] µV.
%   'chan_scale'  - override: full spacing in µV between channel baselines.
%                   If set, takes precedence over chan_range.
%   'fs'          - sampling frequency in Hz (default: EEG.fsample)
%
% Output:
%   artif_info - table, one row per unique flagged window, columns:
%                  WinIdx          window index in the original recording
%                  SampStart       first sample of the flagged epoch
%                  SampEnd         last  sample of the flagged epoch
%                  TimeStart       start time (s)
%                  TimeEnd         end   time (s)
%                  FlaggedChannels cell array of channel names that drove the flag
%                  Decision        'keep' | 'all' | 'flagged' | 'custom'
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
    chan_scale = 2 * chan_range;   % spacing = full range per channel row
end

%% Group table rows into unique windows (by SampStart)
[unique_starts, ~, ~] = unique(max_var_win_info.SampStart, 'stable');
nWins = numel(unique_starts);

win_data(nWins) = struct('SampStart',[],'SampEnd',[],'TimeStart',[],...
    'TimeEnd',[],'WinIdx',[],'FlaggedChannels',[]);
for w = 1:nWins
    mask = max_var_win_info.SampStart == unique_starts(w);
    rows = max_var_win_info(mask, :);
    win_data(w).SampStart       = rows.SampStart(1);
    win_data(w).SampEnd         = rows.SampEnd(1);
    win_data(w).TimeStart       = rows.TimeStart(1);
    win_data(w).TimeEnd         = rows.TimeEnd(1);
    win_data(w).WinIdx          = rows.WinIdx(1);
    win_data(w).FlaggedChannels = unique(rows.Channel);
end

%% Initialise decision state (one entry per unique window)
decisions = struct(...
    'Decision',        repmat({'keep'}, 1, nWins), ...
    'RemoveChannels',  repmat({{}},     1, nWins), ...
    'RemoveSampStart', num2cell([win_data.SampStart]), ...
    'RemoveSampEnd',   num2cell([win_data.SampEnd]));

%% Build figure
fig = figure('Name', sprintf('detect_arti — Subject %s', num2str(ID)), ...
    'NumberTitle', 'off', ...
    'Position', [60 60 1280 720], ...
    'CloseRequestFcn', @on_close);

ax = axes(fig, 'Position', [0.04 0.10 0.62 0.84]);

% ---- Right-panel controls ----
PX = 0.68;   % panel left edge (normalized)
PW = 0.30;   % panel width

% Window info
h_info = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [PX 0.88 PW 0.10], ...
    'HorizontalAlignment', 'left', 'FontSize', 10);

% Decision group label
uicontrol(fig, 'Style', 'text', 'String', 'Rejection decision:', ...
    'Units', 'normalized', 'Position', [PX 0.81 PW 0.05], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);

% Radio buttons
bg = uibuttongroup(fig, 'Units', 'normalized', ...
    'Position', [PX 0.61 PW 0.20], ...
    'BorderType', 'none', ...
    'SelectionChangedFcn', @decision_changed);
h_rb(1) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Keep  (no rejection)', ...
    'Units', 'normalized', 'Position', [0 0.75 1 0.25], 'FontSize', 10);
h_rb(2) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Remove — all channels', ...
    'Units', 'normalized', 'Position', [0 0.50 1 0.25], 'FontSize', 10);
h_rb(3) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Remove — flagged channels only', ...
    'Units', 'normalized', 'Position', [0 0.25 1 0.25], 'FontSize', 10);
h_rb(4) = uicontrol(bg, 'Style', 'radiobutton', ...
    'String', 'Remove — custom selection', ...
    'Units', 'normalized', 'Position', [0 0.00 1 0.25], 'FontSize', 10);

% Channel listbox (custom mode)
h_chan_lbl = uicontrol(fig, 'Style', 'text', ...
    'String', 'Channels to remove (ctrl-click):', ...
    'Units', 'normalized', 'Position', [PX 0.55 PW 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9, 'Visible', 'off');
h_chanlist = uicontrol(fig, 'Style', 'listbox', ...
    'Units', 'normalized', 'Position', [PX 0.37 PW 0.18], ...
    'String', labels, 'Max', nChans, 'Min', 0, ...
    'FontSize', 8, 'Visible', 'off', ...
    'Callback', @chanlist_changed);

% Removal window adjustment
uicontrol(fig, 'Style', 'text', 'String', 'Removal window (s):', ...
    'Units', 'normalized', 'Position', [PX 0.30 PW 0.04], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);

uicontrol(fig, 'Style', 'text', 'String', 'Start:', ...
    'Units', 'normalized', 'Position', [PX 0.25 0.06 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9);
h_tstart = uicontrol(fig, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [PX+0.07 0.25 0.09 0.04], ...
    'FontSize', 9, 'Callback', @time_changed);

uicontrol(fig, 'Style', 'text', 'String', 'End:', ...
    'Units', 'normalized', 'Position', [PX+0.17 0.25 0.05 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 9);
h_tend = uicontrol(fig, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [PX+0.23 0.25 0.09 0.04], ...
    'FontSize', 9, 'Callback', @time_changed);

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset to epoch', ...
    'Units', 'normalized', 'Position', [PX 0.20 0.14 0.04], ...
    'FontSize', 9, 'Callback', @reset_window);

% Vertical scale controls
uicontrol(fig, 'Style', 'text', 'String', 'Vertical scale:', ...
    'Units', 'normalized', 'Position', [PX 0.13 0.13 0.04], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', 'FontSize', 10);
h_scale_lbl = uicontrol(fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [PX+0.14 0.13 0.09 0.04], ...
    'HorizontalAlignment', 'left', 'FontSize', 10, ...
    'String', sprintf('±%g µV', chan_range));
uicontrol(fig, 'Style', 'pushbutton', 'String', '−', ...
    'Units', 'normalized', 'Position', [PX 0.08 0.08 0.04], ...
    'FontSize', 13, 'FontWeight', 'bold', 'TooltipString', 'Zoom out (more range)', ...
    'Callback', @scale_down);
uicontrol(fig, 'Style', 'pushbutton', 'String', '+', ...
    'Units', 'normalized', 'Position', [PX+0.09 0.08 0.08 0.04], ...
    'FontSize', 13, 'FontWeight', 'bold', 'TooltipString', 'Zoom in (less range)', ...
    'Callback', @scale_up);

% Navigation
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
%  Nested functions  (share workspace with outer function)
% =========================================================================

    function render_window(w)
        fig.UserData.cur = w;

        wd = win_data(w);
        dc = decisions(w);

        % Context samples
        ctx  = round(context_sec * fs);
        c_s1 = max(1, wd.SampStart - ctx);
        c_s2 = min(nSamps, wd.SampEnd + ctx);
        t_vec = (c_s1 : c_s2) / fs;
        seg   = data(:, c_s1:c_s2);

        % Demean and detrend each channel so baselines are flat
        seg = detrend(seg', 'linear')';   % time along rows → transpose, detrend, back

        flag_idx = find(ismember(labels, wd.FlaggedChannels));

        % -- Stacked plot --
        cla(ax); hold(ax, 'on');

        for ch = nChans:-1:1
            offset = (nChans - ch) * chan_scale;
            if ismember(ch, flag_idx)
                plot(ax, t_vec, seg(ch,:) + offset, 'k', 'LineWidth', 2);
            else
                plot(ax, t_vec, seg(ch,:) + offset, ...
                    'Color', [0.55 0.55 0.55], 'LineWidth', 0.5);
            end
        end

        % y-limits: exactly ±chan_range around the top and bottom channel baselines
        y_lo = -chan_range;
        y_hi = (nChans - 1) * chan_scale + chan_range;

        % Shaded artifact epoch (red)
        art_t1 = (wd.SampStart - 1) / fs;
        art_t2 =  wd.SampEnd       / fs;
        patch(ax, [art_t1 art_t2 art_t2 art_t1], [y_lo y_lo y_hi y_hi], ...
            [1 0.75 0.75], 'FaceAlpha', 0.30, 'EdgeColor', [0.8 0 0], ...
            'LineWidth', 1.5, 'HandleVisibility', 'off');

        % Shaded removal window (blue), only if it differs from the epoch
        rm_s1 = dc.RemoveSampStart;
        rm_s2 = dc.RemoveSampEnd;
        if ~isnan(rm_s1) && (rm_s1 ~= wd.SampStart || rm_s2 ~= wd.SampEnd)
            rm_t1 = (rm_s1 - 1) / fs;
            rm_t2 =  rm_s2      / fs;
            patch(ax, [rm_t1 rm_t2 rm_t2 rm_t1], [y_lo y_lo y_hi y_hi], ...
                [0.75 0.75 1], 'FaceAlpha', 0.30, 'EdgeColor', [0 0 0.8], ...
                'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        % Y-ticks = channel names (top of stack = channel 1)
        set(ax, ...
            'YTick',      (0 : nChans-1) * chan_scale, ...
            'YTickLabel', labels(nChans:-1:1), ...
            'FontSize',   7, ...
            'TickLabelInterpreter', 'none');
        xlabel(ax, 'Time (s)');
        title(ax, sprintf('[%d / %d]  Win #%d  (%.3f – %.3f s)  |  Flagged: %s', ...
            w, nWins, wd.WinIdx, wd.TimeStart, wd.TimeEnd, ...
            strjoin(wd.FlaggedChannels, ', ')), ...
            'Interpreter', 'none', 'FontSize', 10);
        xlim(ax, [t_vec(1) t_vec(end)]);
        ylim(ax, [y_lo y_hi]);

        h_scale_lbl.String = sprintf('±%.4g µV', chan_range);

        % -- Info text --
        h_info.String = sprintf( ...
            'Window %d / %d\nWin #%d\n%.3f – %.3f s\nFlagged: %s', ...
            w, nWins, wd.WinIdx, wd.TimeStart, wd.TimeEnd, ...
            strjoin(wd.FlaggedChannels, ', '));

        % -- Radio button --
        dec_keys = {'keep','all','flagged','custom'};
        sel      = find(strcmp(dec_keys, dc.Decision));
        if isempty(sel), sel = 1; end
        bg.SelectedObject = h_rb(sel);
        set_chanlist_visible(strcmp(dc.Decision, 'custom'));

        % -- Listbox selection --
        if strcmp(dc.Decision, 'custom') && ~isempty(dc.RemoveChannels)
            h_chanlist.Value = find(ismember(labels, dc.RemoveChannels));
        else
            h_chanlist.Value = [];
        end

        % -- Time edits --
        h_tstart.String = sprintf('%.4f', (rm_s1 - 1) / fs);
        h_tend.String   = sprintf('%.4f',  rm_s2       / fs);
    end

    % ---- Visibility helper ----
    function set_chanlist_visible(tf)
        v = onoff(tf);
        h_chan_lbl.Visible = v;
        h_chanlist.Visible = v;
    end

    function s = onoff(tf)
        if tf, s = 'on'; else, s = 'off'; end
    end

    % ---- Navigation ----
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

    % ---- Decision radio ----
    function decision_changed(~, evt)
        w        = fig.UserData.cur;
        wd       = win_data(w);
        dec_keys = {'keep','all','flagged','custom'};
        sel      = find(h_rb == evt.NewValue);
        decisions(w).Decision = dec_keys{sel};

        switch dec_keys{sel}
            case 'keep'
                decisions(w).RemoveChannels = {};
            case 'all'
                decisions(w).RemoveChannels = labels;
            case 'flagged'
                decisions(w).RemoveChannels = wd.FlaggedChannels;
            case 'custom'
                % Seed with flagged channels as a sensible default
                if isempty(decisions(w).RemoveChannels)
                    decisions(w).RemoveChannels = wd.FlaggedChannels;
                end
        end
        render_window(w);
    end

    % ---- Custom channel listbox ----
    function chanlist_changed(~,~)
        w = fig.UserData.cur;
        sel = h_chanlist.Value;
        if isempty(sel)
            decisions(w).RemoveChannels = {};
        else
            decisions(w).RemoveChannels = labels(sel);
        end
    end

    % ---- Time window edits ----
    function time_changed(~,~)
        w  = fig.UserData.cur;
        t1 = str2double(h_tstart.String);
        t2 = str2double(h_tend.String);
        if isnan(t1) || isnan(t2) || t1 >= t2, return; end
        decisions(w).RemoveSampStart = max(1,       round(t1 * fs) + 1);
        decisions(w).RemoveSampEnd   = min(nSamps,  round(t2 * fs));
        render_window(w);
    end

    function reset_window(~,~)
        w = fig.UserData.cur;
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

    % ---- Build output table ----
    function T = build_output()
        WinIdx          = arrayfun(@(w) win_data(w).WinIdx,    1:nWins)';
        SampStart       = arrayfun(@(w) win_data(w).SampStart, 1:nWins)';
        SampEnd         = arrayfun(@(w) win_data(w).SampEnd,   1:nWins)';
        TimeStart       = arrayfun(@(w) win_data(w).TimeStart, 1:nWins)';
        TimeEnd         = arrayfun(@(w) win_data(w).TimeEnd,   1:nWins)';
        FlaggedChannels = {win_data.FlaggedChannels}';
        Decision        = {decisions.Decision}';
        RemoveChannels  = {decisions.RemoveChannels}';
        RemoveSampStart = cellfun(@(x) x, {decisions.RemoveSampStart})';
        RemoveSampEnd   = cellfun(@(x) x, {decisions.RemoveSampEnd})';
        T = table(WinIdx, SampStart, SampEnd, TimeStart, TimeEnd, ...
            FlaggedChannels, Decision, RemoveChannels, ...
            RemoveSampStart, RemoveSampEnd);
    end

end
