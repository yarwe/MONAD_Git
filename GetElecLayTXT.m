% Load the digitized electrode positions from your text file
addpath('C:\Users\yarde\My Drive\University\ELSC\Year 2\Ayelet\Data ASD\')
matlab_path='C:\Users\yarde\Documents\MATLAB\';
addpath(matlab_path)
addpath([matlab_path 'fieldtrip-20210614\']); ft_defaults;

filename = 'NDAR_EEG_digitizations.txt';
fileID = fopen(filename, 'r');

% Initialize arrays to store the parsed data
channel_num = [];
x = [];
y = [];
z = [];

% Skip the header lines
for i = 1:3
    fgetl(fileID);
end

% Read the file line by line
while ~feof(fileID)
    line = fgetl(fileID);
    if isempty(line)
        continue;
    end
    
    % Extract the channel number and coordinates using regexp
    tokens = regexp(line, 'EEG #(\d+) : \(([-\d\.]+), ([-\d\.]+), ([-\d\.]+)\) mm', 'tokens');
    
    if ~isempty(tokens)
        channel_num(end+1) = str2double(tokens{1}{1});
        x(end+1) = str2double(tokens{1}{2});
        y(end+1) = str2double(tokens{1}{3});
        z(end+1) = str2double(tokens{1}{4});
    end
end

fclose(fileID);

% Create an electrode structure
% Layout - at the moment- manually
elec.label = {'Fp1','Fpz','Fp2',...
    'AF7','AF3','AFz','AF4','AF8',...
    'F7','F5','F3','F1','Fz','F2','F4','F6','F8'...
    'FT9','FT7','FC5','FC3','FC1','FCz','FC2','FC4','FC6','FT8','FT10',...
    'T9','T7','C5','C3','C1','Cz','C2','C4','C6','T8','T10',...
    'TP9','TP7','CP5','CP3','CP1','CPz','CP2','CP4','CP6','TP8','TP10',...
    'P9','P7','P5','P3','P1','Pz','P2','P4','P6','P8','P10',...
    'PO7','PO3','POz','PO4','PO8',...
    'O1','Oz','O2',...
    'IZ'};
% elec.label = arrayfun(@(n) sprintf('EEG %d', n), channel_num, 'UniformOutput', false);
elec.pnt = [x', y', z'];


% Create a layout structure
cfg = [];
cfg.elec = elec;
cfg.rotate = [];
cfg.projection = 'polar'; % or 'orthographic'
layout = ft_prepare_layout(cfg);

% Plot the layout
cfg = [];
cfg.layout = layout;
ft_layoutplot(cfg);