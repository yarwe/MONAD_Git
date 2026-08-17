function [fig, vEEG_bef,vEEG2] = comp_var_bef_aft(dat_bef,dat_aft,nEEG, legend_strings)
% Compares the channel variance before and after pre-processing procedure.
% both dat_bef,dat_aft are fieldtrip strcutures with necessary fields of
% trial and label. nEEG can be:
%   - a scalar          -> channels 1:nEEG (same indices in both datasets)
%   - a numeric vector  -> those channel indices (same indices in both)
%   - a cell of NAMES   -> channel names looked up SEPARATELY in each dataset
%                          (robust when dat_bef and dat_aft have different
%                          channel orders, e.g. after interpolation drops EOG).

if iscell(nEEG)
    % Look up each requested channel by name, independently per dataset, so a
    % differing channel order between dat_bef and dat_aft is handled correctly.
    names = nEEG(:);
    chans_bef = zeros(numel(names),1);
    chans_aft = zeros(numel(names),1);
    for i = 1:numel(names)
        b = find(strcmp(dat_bef.label, names{i}), 1);
        a = find(strcmp(dat_aft.label, names{i}), 1);
        if isempty(b) || isempty(a)
            error('comp_var_bef_aft:missingChan', ...
                'Channel "%s" not found in both datasets.', names{i});
        end
        chans_bef(i) = b; chans_aft(i) = a;
    end
    xlabels = names;
elseif length(nEEG)==1
    chans_bef = (1:nEEG)'; chans_aft = chans_bef;
    xlabels = dat_aft.label(chans_aft);
else
    chans_bef = sort(nEEG(:)); chans_aft = chans_bef;
    xlabels = dat_aft.label(chans_aft);
end

vEEG_bef = var(dat_bef.trial{1}(chans_bef,:),0,2,"omitnan");
vEEG2    = var(dat_aft.trial{1}(chans_aft,:),0,2,"omitnan");
fig=figure;
% Markers ('-o') so a single channel is still visible (a lone point with no
% marker draws nothing).
plot(vEEG_bef,'k-o','MarkerFaceColor','k');
hold on;
plot(vEEG2,'r-o','MarkerFaceColor','r');
set(gca,'FontSize',12,'XTick',1:numel(xlabels),'XTickLabel',xlabels,...
    'XTickLabelRotation',90);
xlim([0.5, numel(xlabels)+0.5]);
ylabel('Channel variance (\muV^2)');
legend(legend_strings)


end