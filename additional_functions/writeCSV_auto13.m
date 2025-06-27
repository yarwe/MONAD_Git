function [] = writeCSV_auto(env, ID, cfg, Zcfg, pEEG)
% Updated function to calculate and add Zremove(%) column

% Define the log file name
log_filename = 'log.csv';

% Extract experiment and ID information
exp_value = env.exp;
ID_value = ID;

% Store filter information
filters_info = sprintf('HP:%.1fHz, DFT:[%.1fHz, %.1fHz]', ...
                       cfg.hpfreq, env.data.linenoise, env.data.linenoise * 2);

% Store Z-cutoff value
Zcutoff_value = Zcfg.artfctdef.zvalue.cutoff;

% Determine detrend status
if isfield(cfg, 'detrend') && strcmp(cfg.detrend, 'yes')
    detrend_value = 'yes';
else
    detrend_value = 'no';
end

% Determine reref status
if isfield(cfg, 'reref') && strcmp(cfg.reref, 'yes')
    reref_value = 'yes';
else
    reref_value = 'no';
end

% Calculate the percentage of data removed
artifact_samples = Zcfg.artfctdef.zvalue.artifact;  % List of artifact intervals
total_removed_samples = 0;

% Sum the removed samples for each artifact
for i = 1:size(artifact_samples, 1)
    total_removed_samples = total_removed_samples + (artifact_samples(i, 2) - artifact_samples(i, 1) + 1);
end

% Total number of samples in pEEG (across all trials)
total_samples = sum(cellfun(@(x) size(x, 2), pEEG.trial));

% Calculate the percentage of data removed
Zremove_percentage = (total_removed_samples / total_samples) * 100;
Zremove_percentage = round(Zremove_percentage, 2);

% Create a table with the new columns
log_table = cell2table({env.exp, ID, filters_info, detrend_value, reref_value, Zcutoff_value, Zremove_percentage}, ...
                       'VariableNames', {'exp', 'ID', 'filters', 'detrend', 'reref', 'Zcutoff', 'Zremove(%)'});

% Check if the log file already exists
if isfile(log_filename)
    % Read the existing log file
    existing_log = readtable(log_filename);
    
    % Ensure the 'ID' column is treated as a string for comparison
    existing_log.ID = string(existing_log.ID);
    ID = string(ID);
    
    % Check if the current ID already exists in the log
    id_exists = any(existing_log.ID == ID);
    
    if id_exists
        % If the ID exists, update the row for that ID
        existing_log_row_idx = existing_log.ID == ID;
        existing_log.filters{existing_log_row_idx} = filters_info;  % Corrected assignment
        existing_log.detrend{existing_log_row_idx} = detrend_value;  % Corrected assignment
        existing_log.reref{existing_log_row_idx} = reref_value;      % Corrected assignment
        existing_log.Zcutoff(existing_log_row_idx) = Zcutoff_value;  % Corrected assignment
        existing_log.Zremove(existing_log_row_idx) = Zremove_percentage;  % Update Zremove(%)
        
        % Write the updated table back to the CSV file
        writetable(existing_log, log_filename);
    else
        % If the ID doesn't exist, append a new row
        writetable(log_table, log_filename, 'WriteMode', 'append');
    end
else
    % If the file doesn't exist, create a new file with headers
    writetable(log_table, log_filename);
end

disp('Log file updated successfully.');
end
