function [Tdisp, Cout] = fooof_summary_table(roiLabels, GN, GA, opt)
% FOOOF_SUMMARY_TABLE  Build (and optionally save) a results summary table.
%
% Rows    = electrode clusters (ROIs).
% Columns = FOOOF estimates: aperiodic offset, aperiodic exponent, and for each
%           band its center freq, power, bandwidth.
% Each cell = direction of the effect, Cohen's d, p-value (Welch t-test),
%           significance, and the per-group N used (n = NT/ASD).
%
% INPUTS
%   roiLabels - 1 x R cellstr, one per ROI (row labels).
%   GN, GA    - 1 x R cell arrays of fooof_group results (NT and ASD per ROI).
%   opt       - struct with fields:
%       .name1, .name2 - group names (default 'NT','ASD')
%       .titleStr      - caption written as the first row of the file
%       .csvpath       - if non-empty, the table is written there (.csv or .xlsx)
%
% OUTPUTS
%   Tdisp - MATLAB table (sanitized column names) for console display.
%   Cout  - the full cell matrix that was written to file (title + header + body).
%
% See also: run_fooof, fooof_group, fooof_exclude

if nargin < 4, opt = struct(); end
n1 = getf(opt,'name1','NT'); n2 = getf(opt,'name2','ASD');
titleStr = getf(opt,'titleStr','FOOOF summary');
csvpath  = getf(opt,'csvpath','');

% ---- build the column list: aperiodic first, then per-band C F/PW/BW ----
bnames = GN{1}.band_names;
colName = {'aperiodic offset','aperiodic exponent'};
colGet  = {@(G) G.offset, @(G) G.exponent};
statmap = {'cf','center freq'; 'pw','power'; 'bw','bandwidth'};
for b = 1:numel(bnames)
    bn = bnames{b};
    for s = 1:size(statmap,1)
        st = statmap{s,1};
        colName{end+1} = sprintf('%s %s', bn, statmap{s,2}); %#ok<AGROW>
        colGet{end+1}  = @(G) G.peaks.(bn).(st);             %#ok<AGROW>
    end
end

nRow = numel(roiLabels); nCol = numel(colName);
C = cell(nRow, nCol);
for r = 1:nRow
    for c = 1:nCol
        C{r,c} = cell_stat(colGet{c}(GN{r}), colGet{c}(GA{r}), n1, n2);
    end
end

% ---- console table (sanitized variable names) ----
Tdisp = cell2table(C, 'RowNames', roiLabels, ...
    'VariableNames', matlab.lang.makeValidName(colName));
fprintf('\n%s\n', titleStr);
disp(Tdisp);

% ---- file output: title row, blank row, header, body ----
header = [{'Cluster \ Estimate'}, colName];
body   = [roiLabels(:), C];
Cout   = [ [{titleStr}, repmat({''},1,nCol)]; ...
           repmat({''},1,nCol+1); ...
           header; ...
           body ];
if ~isempty(csvpath)
    d = fileparts(csvpath); if ~isempty(d) && ~isfolder(d), mkdir(d); end
    writecell(Cout, csvpath);
    fprintf('Saved: %s\n', csvpath);
end
end

% ----------------------------- helpers -----------------------------------
function v = getf(s,f,d), if isfield(s,f)&&~isempty(s.(f)), v=s.(f); else, v=d; end; end

function s = cell_stat(x, y, n1, n2)
% Direction | Cohen's d | Welch p | significance | n=NT/ASD
x = x(isfinite(x)); y = y(isfinite(y)); nx = numel(x); ny = numel(y);
if nx < 2 || ny < 2, s = sprintf('n/a | n=%d/%d', nx, ny); return; end
mx = mean(x); my = mean(y);
sp = sqrt(((nx-1)*var(x)+(ny-1)*var(y))/(nx+ny-2));
d  = abs(mx-my)/sp;
t  = (mx-my)/sqrt(var(x)/nx+var(y)/ny);
df = (var(x)/nx+var(y)/ny)^2/((var(x)/nx)^2/(nx-1)+(var(y)/ny)^2/(ny-1));
if exist('tcdf','file'), p = 2*(1-tcdf(abs(t),df)); else, p = NaN; end
if mx >= my, dir = sprintf('%s>%s', n1, n2); else, dir = sprintf('%s>%s', n2, n1); end
if     p < 0.001, sg = '***';
elseif p < 0.01,  sg = '**';
elseif p < 0.05,  sg = '*';
else,             sg = 'ns';
end
s = sprintf('%s | d=%.2f | p=%.3f | %s | n=%d/%d', dir, d, p, sg, nx, ny);
end
