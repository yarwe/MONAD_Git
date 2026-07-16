function [fig, vEEG_bef,vEEG2] = comp_var_bef_aft(dat_bef,dat_aft,nEEG, legend_strings)
% Compares the channel variance before and after pre-processing procedure.
% both dat_bef,dat_aft are fieldtrip strcutures with necessary fields of
% trial and label. nEEG could be the number of EEG channels or a matrix of
% specific channels.

if length(nEEG)==1
    chans_var=1:nEEG;
else
    chans_var=sort(nEEG);
end

vEEG_bef=var(dat_bef.trial{1}(chans_var,:),0,2,"omitnan");
vEEG2 = var(dat_aft.trial{1}(chans_var,:),0,2,"omitnan");
fig=figure;
plot(vEEG_bef,'k');
hold on;
plot(vEEG2,'red');
set(gca,'FontSize',12,'XTick',1:length(chans_var),'XTickLabel',dat_aft.label(chans_var),...
    'XTickLabelRotation',90);
ylabel('Channel variance (\muV^2)');
legend(legend_strings)


end