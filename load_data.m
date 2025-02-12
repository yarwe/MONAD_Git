function [ftEEG] = load_data(env, filename)
% load data for each data-set
addpath('C:\Users\yoelgo\Documents\eeglab2024.2\');
eeglab;
if     strcmp(env.exp, 'OSF_simple')
    EEG          = pop_biosig(filename);
    ftEEG        = biosig2ft(EEG);

elseif strcmp(env.exp, 'OSF_complex')
    EEG          = pop_biosig(filename);
    ftEEG        = biosig2ft(EEG);
    
end
end

