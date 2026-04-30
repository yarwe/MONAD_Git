dataDir = 'Z:\Yarden\NIMH data\Package_1235544-Tal Kenet MEG EEG biomarkers\eeg_sub_files01\'; % <--- Change this to your folder path
addpath('C:\Users\yarde\Documents\MATLAB\');
faddpath([matlab_path 'fieldtrip-20210614\']);

% Get a list of all .fif files in the folder
fileList = dir(fullfile(dataDir, '*.fif'));

% Check if any files were found
if isempty(fileList)
    fprintf('No .fif files found in the specified directory.\n');
    return;
end

fprintf('Processing %d files...\n', length(fileList));
fprintf('------------------------------------------\n');
fprintf('%-30s | %-15s\n', 'File Name', 'Sampling Rate (Hz)');
fprintf('------------------------------------------\n');

% Loop through each file
for i = 1:15
    fileName = fileList(i).name;
    fullPath = fullfile(dataDir, fileName);
    

    cfg = [];
    cfg.dataset = fullPath;
    ftEEG = ft_preprocessing(cfg);

    % Print the file name and the sampling rate (Fs)
    fprintf('%-30s | %-15.2f\n', fileName, ftEEG.fsample);
    fprintf("Recording lasted %d minutes",round((ftEEG.sampleinfo(end)/ftEEG.fsample)/60))

end

fprintf('------------------------------------------\n');