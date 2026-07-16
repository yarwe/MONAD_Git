function plot_spect_chans(EEG,fs,s,chosen_chans)
% Plots power spectrum of chosen channels - each channel in a different
% figure.
for chan=chosen_chans
    [ps_raw, frq] = pwelch(EEG.trial{1}(chan,:),2*fs,[],[],fs);
    figure; 
    plot(frq,ps_raw,'k');
    set(gca,'FontSize',14,'XScale','log','YScale','log');
    ylabel('Power spectrum');
    title(sprintf('Subject %d',s));
    subtitle(sprintf('Channel %s',EEG.label{chan}));
    xlim('tight')
end
end