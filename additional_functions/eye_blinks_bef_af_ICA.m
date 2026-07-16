function eye_blinks_bef_af_ICA(subj_num,chans_blinks,thres_lowpass_eyeblink_detect,pre_eeg,post_eeg,fs,to_save,str_save, path_save, is_raw)
% Spec eyeblinks before and after ICA
%
% Handles NaN values in pre_eeg / post_eeg that arise when epochs of
% specific channels (or of all channels) were previously replaced with NaN
% during artifact rejection (cfg.artfctdef.reject = 'nan').
%
% The detection filters are filtfilt-based, so a single NaN propagates
% across the WHOLE output and turns the signal into all-NaN. To avoid this
% we process trial-by-trial and filter only the finite samples, leaving the
% rejected (NaN) samples as NaN.

for chan = 1:length(chans_blinks)
    str_chan = chans_blinks{chan};
    num_Fp_pre  = find(strcmp(pre_eeg.label,  str_chan));
    num_Fp_post = find(strcmp(post_eeg.label, str_chan));

    nTrials = numel(pre_eeg.trial);

    % Build the concatenated signals trial-by-trial so NaN segments stay
    % local instead of poisoning the entire filtered signal.
    fp_pre              = [];   % raw (optionally preprocessed) pre signal
    fp_for_detect       = [];   % low-passed pre signal, for detection
    cleanICA_dat_detect = [];   % low-passed post signal, for detection
    for t = 1:nTrials
        seg_pre  = pre_eeg.trial{t}(num_Fp_pre, :);
        seg_post = post_eeg.trial{t}(num_Fp_post, :);

        % Raw preprocessing (baseline, detrend, bandpass) on finite samples
        if nargin > 9 && is_raw
            seg_pre = nan_safe(seg_pre, @(x) ...
                ft_preproc_bandpassfilter( ...
                    ft_preproc_detrend( ...
                        ft_preproc_baselinecorrect(x)), fs, [1, 100]));
        end

        % Temporary low-passed version for detection ONLY
        if ~isempty(thres_lowpass_eyeblink_detect)
            seg_pre_det  = nan_safe(seg_pre,  @(x) ...
                ft_preproc_lowpassfilter(x, fs, thres_lowpass_eyeblink_detect));
            seg_post_det = nan_safe(seg_post, @(x) ...
                ft_preproc_lowpassfilter(x, fs, thres_lowpass_eyeblink_detect));
        else
            seg_pre_det  = seg_pre;
            seg_post_det = seg_post;
        end

        fp_pre              = [fp_pre,              seg_pre];      %#ok<AGROW>
        fp_for_detect       = [fp_for_detect,       seg_pre_det];  %#ok<AGROW>
        cleanICA_dat_detect = [cleanICA_dat_detect, seg_post_det]; %#ok<AGROW>
    end
    fp_pre        = fp_pre';          % keep original column orientation
    fp_for_detect = fp_for_detect';   % keep original column orientation

    % Now get the threshold from the smoothed signal.
    % quantile ignores NaN, so rejected samples are excluded automatically.
    eyeblink_thres = quantile(fp_for_detect, 0.997);
    if isnan(eyeblink_thres)
        warning('Channel %s has no finite samples for subject %d; skipping.', ...
            str_chan, subj_num);
        continue;
    end

    % Use the smoothed signal to find the peak indices.
    % For each triggered eyeblink, get the peak voltage within a 500 ms
    % window around the peak. NaN samples never exceed the threshold, so
    % they are not detected as eyeblinks.
    [eyeblink, eyeblink_idx] = get_triggered_eyeblinks(fp_for_detect, eyeblink_thres, fs);

    if isempty(eyeblink)
        warning('No eyeblinks detected for channel %s, subject %d; skipping.', ...
            str_chan, subj_num);
        continue;
    end

    % Get the post-ICA values at the indices that originally had eyeblinks.
    rmv_eyeblink = NaN(size(eyeblink));
    for n = 1:size(eyeblink,2)
        use_idx = ~isnan(eyeblink_idx(:,n));
        % Make sure the index doesn't exceed the clean data length
        valid_bounds = eyeblink_idx(:,n) <= length(cleanICA_dat_detect);
        % Combine both conditions
        final_idx = use_idx & valid_bounds;
        rmv_eyeblink(final_idx,n) = cleanICA_dat_detect(eyeblink_idx(final_idx,n));
    end

    % Plot
    dly = -ceil(0.25*fs):ceil(0.25*fs);
    fig = figure;
    plot(dly,eyeblink,'k');
    hold on;
    plot(dly,rmv_eyeblink,'r');
    set(gca,'FontSize',14);
    xlabel('Delay (ms)');
    ylabel('\muV');
    title(sprintf('%s eyeblinks, before and after ICA',str_chan));
    set(gcf, 'Renderer', 'painters');
    if to_save
        saveas(fig, [path_save  'Subj_' num2str(subj_num) sprintf(['_chan_%s' str_save '.png'],str_chan)]);
        pause(0.2);
    end

end
end

function out = nan_safe(sig, fn)
% Apply fn (a filtering/preprocessing op expecting a [chan x time] row) to
% the finite samples of sig only, leaving NaN samples as NaN so they do not
% propagate through filtfilt-based filters.
out   = nan(size(sig));
valid = ~isnan(sig);
if any(valid)
    out(valid) = fn(sig(valid));
end
end
