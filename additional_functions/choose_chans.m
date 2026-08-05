function [chosen_chans, lab_chans] = choose_chans(env,what_do_w_chans,nEEG)
% Helps the user choose which channels to be **Something**, output is the
% relevant channel numbers.
fprintf(2, ['Provide Vector of channel numbers or cell of Channel labels to be %s.' ...
    '\n' 'For plotting: Default is 2 random channels; for Rejecting: Default is none. '], what_do_w_chans);
chosen_chans=input('');

if isempty(chosen_chans) && strcmpi(what_do_w_chans(1:4),'plot')
        nchans = nEEG;
        chosen_chans = randperm(nchans, 2);
elseif isempty(chosen_chans) && strcmpi(what_do_w_chans(1:3),'rej')
    chosen_chans = [];
end

printedLabelList = false;
while ~isnumeric(chosen_chans)
    [tf, idx] = ismember(lower(chosen_chans), lower(env.lay.label(1:nEEG)));
    missingLabels = chosen_chans(~tf);
    if isempty(missingLabels)
        chosen_chans = idx;   % convert labels to numeric channel indices
        break
    end

    warning('The following labels were not found in EEG.label: %s', ...
        strjoin(missingLabels, ', '));
    if ~printedLabelList
        fprintf(2, '\nAvailable EEG labels are:\n');
        fprintf(2, '%s\n', env.lay.label{:});
        printedLabelList = true;
    end

    fprintf(2, ['\nPlease provide an updated vector of channel numbers \n ' ...
        'or cell array of channel labels,\n or press Enter for all channels: ']);
    chosen_chans = input('');

    if isempty(chosen_chans) && strcmpi(what_do_w_chans(1:4),'plot')
        nchans = nEEG;
        chosen_chans = 1:nchans;
    elseif isempty(chosen_chans) && strcmpi(what_do_w_chans(1:3),'rej')
        chosen_chans = [];
    else
        chosen_chans =[];
    end
end
% Return the corresponding channel label(s) for the chosen channels
lab_chans = env.lay.label(chosen_chans);

end