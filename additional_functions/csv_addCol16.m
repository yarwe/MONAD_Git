function csv_addCol16(env,logFile, ID, colNames, colValues)
% Addes coloums/rows to existing log csv file.
    if ~isfile(logFile)
        error('log.csv does not exist. Please initialize it using csv_init first.');
    end
    
    % Read the current log file.
    opts = detectImportOptions(logFile);
    opts = setvartype(opts, opts.VariableNames, 'string');
    if ismember('exp', opts.VariableNames)
        opts = setvartype(opts, 'exp', 'string');
    end
    dataTable = readtable(logFile, opts);

    
    % Check if the ID exists.
    id_no_lead_0=regexprep(string(ID), '^0+(?=\d)', '');
    rowIndex = find((strcmpi(dataTable.ID,string(ID)) | strcmpi(dataTable.ID,id_no_lead_0)) & dataTable.exp == env.exp, 1);
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
        dataTable.(colName)(rowIndex) = string(colValue); % Use direct indexing for string type.
    end
    
    % Save the updated table.
    writetable(dataTable, logFile);
end


