function csv_addCol(env, ID, colNames, colValues, dat_ay)
    if ~exist("dat_ay",'var')
        logFile = 'R:\Yarden\MONAD_log.csv';
    else
        logFile = [dat_ay ':\Yarden\MONAD_log.csv'];
    end
    
    if ~isfile(logFile)
        error('log.csv does not exist. Please initialize it using csv_init first.');
    end
    
    % Read the current log file.
    dataTable = readtable(logFile, 'TextType', 'string');
    
    % Check if the ID exists.
    rowIndex = find(dataTable.ID == ID & dataTable.exp == env.exp, 1);
    if isempty(rowIndex)
        error('ID "%s" not found in the log file. Please initialize it using csv_init first.', ID);
    end
    
    % Add or update the columns.
    for i = 1:length(colNames)
        colName = colNames{i};
        colValue = colValues{i};
        
        if ~ismember(colName, dataTable.Properties.VariableNames)
            % Add a new column with placeholders for all rows.
            dataTable.(colName) = repmat("--", height(dataTable), 1); % Initialize as strings.
        end
        
        % Convert numeric values to strings if necessary.
        if isnumeric(colValue)
            colValue = string(colValue);
        end
        
        % Update the value for the specified ID.
        dataTable.(colName)(rowIndex) = colValue; % Use direct indexing for string type.
    end
    
    % Save the updated table.
    writetable(dataTable, logFile);
end


