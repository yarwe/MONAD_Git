function stats = plot_fooof_aperiodic(GN, GA, chan_label)
% PLOT_FOOOF_APERIODIC  Compare the aperiodic parameters between groups:
% offset and exponent (2 panels), with units on the y-axes.
%
% Y-AXIS UNITS
%   Offset   : log10 power at 1 Hz. The spectrum is fit in log10 space, and
%              offset = L(f) at log10(f)=0. With EEG in microvolts the PSD is
%              in uV^2/Hz, so the offset is in log10(uV^2/Hz). (If the data were
%              in volts it would be log10(V^2/Hz) -- rescale the label to match.)
%   Exponent : dimensionless. It is the exponent chi of the 1/f^chi aperiodic
%              component, i.e. the negative slope of log10(power) vs log10(freq).
%
% GN, GA     - two fooof_group results
% chan_label - string shown as subtitle (channels included)
%
% See also: plot_fooof_periodic, fooof_group

if nargin < 3, chan_label = ''; end

opt = struct();
opt.name1 = grpname(GN,'Group 1'); opt.name2 = grpname(GA,'Group 2');
opt.col1  = grpcol(GN,[0.15 0.60 0.20]); opt.col2 = grpcol(GA,[0.00 0.45 0.74]);
opt.titleStr = sprintf('Aperiodic:  %s (N=%d) vs %s (N=%d)', ...
    opt.name1, numel(GN.offset), opt.name2, numel(GA.offset));
opt.subtitleStr = chan_label;

dataN = {GN.offset, GN.exponent};
dataA = {GA.offset, GA.exponent};
ylabels = {'offset (log_{10} \muV^2/Hz)', 'exponent'};

stats = fooof_compare_panels(dataN, dataA, ylabels, opt);
end

function n = grpname(G,d), n=G.group_name; if isempty(n), n=d; end; end
function c = grpcol(G,d), if isfield(G,'color')&&~isempty(G.color), c=G.color; else, c=d; end; end
