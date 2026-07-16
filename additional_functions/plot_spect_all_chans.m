function plot_spect_all_chans(subj_num,EEG,...
    num_chans_eeg,fs,sus_alias_subharm,f0,to_save,eeg_plots,before_or_aft)
% Plots spectrum of all channels, overlayed, with average in bold.

if ischar(subj_num)
    subj_str=subj_num;
else
    subj_str=num2str(subj_num);
end

if nargin<9
    before_or_aft='before pre-processing';
end

fig=figure('Name', 'Overlay All Channels', 'Color', 'w');
hold on;
all_sp_matrix_raw = [];

% Pre-calculate all PSDs to find the mean
for chan = 1:num_chans_eeg
    [sp_all, frq] = pwelch(EEG.trial{1}(chan,:), 2*fs, [], [], fs);
    all_sp_matrix_raw = cat(2,all_sp_matrix_raw,sp_all);
    
    % Plot individual channel in light gray or color
    ps_ind=plot(frq, sp_all, 'Color', [.7 .7 .7], 'LineWidth', 1,...
        'DisplayName', EEG.label{chan}); 

end
% Plot the mean across ALL channels in bold black
mean_psd_all = mean(all_sp_matrix_raw, 2);
hMean =plot(frq, mean_psd_all, 'k', 'LineWidth', 3);
% Formatting the overlay
set(gca, 'XScale', 'log', 'YScale', 'log', 'FontSize', 14);
xlabel('Frequency (Hz)');
ylabel('Power Spectrum');
title(sprintf('All %d Channels Overlay, %s', num_chans_eeg,before_or_aft));
subtitle(sprintf('Subject %s',subj_str))
grid on;
xlim([1 fs/2]);
% Add specific markers for the artifacts
if ~isempty(f0) && ~isnan(f0)
    hDBS =xline(f0, '--r');
    h_list = [ps_ind, hMean, hDBS];
    labels = {'Individual channels', ...
          'Mean (All Channels)', ...
          sprintf('DBS Stimulation (%dHz)', f0)};
else
    h_list = [ps_ind, hMean];
    labels = {'Individual channels', ...
          'Mean (All Channels)'};
end

if ~isempty(sus_alias_subharm)
    nsus= length(sus_alias_subharm); 
    if nsus > 0
        hAlias =xline(sus_alias_subharm, '--b');
        % Append to the legend lists
        h_list(end+1) = hAlias(1); % Take first handle if multiple exist
        labels{end+1} = 'Aliased / (Sub) Harmonics';
    end
    legend(h_list, labels, 'Location', 'southwest', 'FontSize', 10);
    hold off;
end

if to_save
    saveas(fig, [eeg_plots  'Subj_' subj_str '_power_allchans_before_pre.png']);
end


end