function stats = plot_fooof_periodic(GN, GA, bandname, chan_label)
% PLOT_FOOOF_PERIODIC  Compare one band's periodic parameters between groups:
% center frequency, aperiodic-adjusted power, and bandwidth (3 panels).
%
% GN, GA     - two fooof_group results (must contain the band in .peaks)
% bandname   - which band to plot, e.g. 'alpha' (a field of GN.peaks)
% chan_label - string shown as subtitle, e.g. 'Central (Cz,C1,C2,FCz,FC1,FC2)'
%
% See also: plot_fooof_aperiodic, fooof_group

if nargin < 4, chan_label = ''; end
if ~isfield(GN.peaks, bandname)
    error('plot_fooof_periodic:band','Band "%s" not found in the group results.', bandname);
end
b = GN.band_ranges.(bandname);

opt = struct();
opt.name1 = grpname(GN,'Group 1'); opt.name2 = grpname(GA,'Group 2');
opt.col1  = grpcol(GN,[0.15 0.60 0.20]); opt.col2 = grpcol(GA,[0.00 0.45 0.74]);
opt.titleStr = sprintf('%s periodic (%g-%g Hz):  %s (N=%d) vs %s (N=%d)', ...
    bandname, b(1), b(2), opt.name1, numel(GN.offset), opt.name2, numel(GA.offset));
opt.subtitleStr = chan_label;

dataN = {GN.peaks.(bandname).cf, GN.peaks.(bandname).pw, GN.peaks.(bandname).bw};
dataA = {GA.peaks.(bandname).cf, GA.peaks.(bandname).pw, GA.peaks.(bandname).bw};
ylabels = { sprintf('%s center freq (Hz)', bandname), ...
            sprintf('%s power (a.u.)', bandname), ...
            sprintf('%s bandwidth (Hz)', bandname) };

stats = fooof_compare_panels(dataN, dataA, ylabels, opt);
end

function n = grpname(G,d), n=G.group_name; if isempty(n), n=d; end; end
function c = grpcol(G,d), if isfield(G,'color')&&~isempty(G.color), c=G.color; else, c=d; end; end
