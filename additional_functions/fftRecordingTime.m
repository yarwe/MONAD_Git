function [durTbl, summary] = fftRecordingTime(FFT_arr, winLen)
% FFTRECORDINGTIME  Actual analyzed EEG duration per subject from FFT_arr.
%
% For each participant, the FFT was computed only on the clean (NaN-free)
% windows that survived artifact rejection. This function recovers how much
% real data that corresponds to, using the bookkeeping fields stored on each
% FFT struct:
%
%     kept windows   = num_win - rem_win
%     duration (min) = (num_win - rem_win) * winLen / 60
%
% (e.g. subject with num_win=49, rem_win=26, winLen=5 -> 23*5/60 = 1.9167 min)
%
% INPUTS
%   FFT_arr : cell array (1 x nSubj) of FieldTrip freq structs. Only structs
%             that have BOTH .num_win and .rem_win fields are included; others
%             are skipped with a warning.
%   winLen  : (optional) window length in seconds. Default 5. NOTE: the window
%             length is not stored in FFT_arr (cfg.previous is cleared in
%             create_datArr21), so it is assumed here. If a 'length' field is
%             found in the cfg provenance it is used instead and reported.
%
% OUTPUTS
%   durTbl  : table (one row per included subject) with columns:
%               ID, num_win, rem_win, kept_win, minutes
%   summary : struct with fields n, winLen, min, max, mean, median, total
%             (durations in minutes; total is the summed analyzed time).
%
% The function also prints the min / max / mean analyzed duration.
%
% Example:
%   [durTbl, summary] = fftRecordingTime(FFT_arr);          % assume 5 s windows
%   [durTbl, summary] = fftRecordingTime(FFT_arr, 5);       % explicit

if nargin < 2 || isempty(winLen)
    winLen = 5;   % seconds (assumed; see note in header)
end

nSub = numel(FFT_arr);

% Preallocate collectors
IDs     = strings(nSub, 1);
numWin  = nan(nSub, 1);
remWin  = nan(nSub, 1);
keptWin = nan(nSub, 1);
minutes = nan(nSub, 1);
included = false(nSub, 1);

% Try to detect a recorded window length (best effort); warn if it disagrees
detectedLen = [];

for s = 1:nSub
    d = FFT_arr{s};

    % must have both bookkeeping fields
    if ~(isfield(d, 'num_win') && isfield(d, 'rem_win'))
        warning('fftRecordingTime:missingFields', ...
            'Subject %d is missing num_win/rem_win; skipping.', s);
        continue
    end

    nw   = d.num_win;
    rw   = d.rem_win;
    kept = nw - rw;

    IDs(s)     = getID(d, s);
    numWin(s)  = nw;
    remWin(s)  = rw;
    keptWin(s) = kept;
    minutes(s) = kept * winLen / 60;
    included(s) = true;

    % best-effort: look for a stored window length in this subject's cfg
    thisLen = findWinLen(d);
    if ~isempty(thisLen)
        if isempty(detectedLen); detectedLen = thisLen; end
    end
end

% Report if an actual window length was found in the data
if ~isempty(detectedLen) && detectedLen ~= winLen
    warning('fftRecordingTime:winLenMismatch', ...
        ['A window length of %g s was found in the data but %g s was used. ' ...
         'Re-run with winLen = %g for accurate durations.'], ...
        detectedLen, winLen, detectedLen);
elseif isempty(detectedLen)
    fprintf(['[fftRecordingTime] No window length stored in FFT_arr; ' ...
             'assuming winLen = %g s.\n'], winLen);
end

% Keep only included subjects
IDs     = IDs(included);
numWin  = numWin(included);
remWin  = remWin(included);
keptWin = keptWin(included);
minutes = minutes(included);

durTbl = table(IDs, numWin, remWin, keptWin, minutes, ...
    'VariableNames', {'ID', 'num_win', 'rem_win', 'kept_win', 'minutes'});

% Summary
summary = struct();
summary.n      = numel(minutes);
summary.winLen = winLen;
summary.min    = min(minutes);
summary.max    = max(minutes);
summary.mean   = mean(minutes);
summary.median = median(minutes);
summary.total  = sum(minutes);

% Print
fprintf('\nAnalyzed FFT duration across %d subjects (window = %g s):\n', ...
    summary.n, winLen);
fprintf('  range : %.4f - %.4f min\n', summary.min, summary.max);
fprintf('  mean  : %.4f min\n', summary.mean);
fprintf('  median: %.4f min\n', summary.median);
fprintf('  total : %.4f min\n\n', summary.total);
end

% ======================================================================= %
function id = getID(d, s)
% Return the participant ID as a string (handles cell-wrapped IDs).
if isfield(d, 'ID')
    id = d.ID;
    if iscell(id); id = id{1}; end
    id = string(id);
else
    id = "subj" + string(s);
end
end

% ======================================================================= %
function len = findWinLen(d)
% Best-effort search for a stored trial/window length (seconds) in the cfg
% provenance. Returns [] if not found. (In the current pipeline cfg.previous
% is cleared, so this typically returns [].)
len = [];
if ~isfield(d, 'cfg') || ~isstruct(d.cfg); return; end
len = searchLength(d.cfg, 0);
end

function len = searchLength(c, depth)
len = [];
if depth > 5 || ~isstruct(c); return; end
if isfield(c, 'length') && isscalar(c.length) && isnumeric(c.length)
    len = c.length; return;
end
if isfield(c, 'previous')
    prev = c.previous;
    if isstruct(prev)
        for k = 1:numel(prev)
            len = searchLength(prev(k), depth + 1);
            if ~isempty(len); return; end
        end
    elseif iscell(prev)
        for k = 1:numel(prev)
            len = searchLength(prev{k}, depth + 1);
            if ~isempty(len); return; end
        end
    end
end
end
