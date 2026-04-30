function csv_init(env, ID)
    if ~isfield(env, 'dat_ay')
        logFile = 'R:\Yarden\MONAD_log.csv';
    else
        logFile = [env.dat_ay ':\Yarden\MONAD_log.csv'];
    end
    
    if ~isfile(logFile)
        % If log.csv does not exist, create it with the initial structure.
        headers = {'exp', 'ID'};
        data = {env.exp, ID};
        writecell([headers; data], logFile);
    else
        % If log.csv exists, retrieve the current content.
        dataTable = readtable(logFile, 'TextType', 'string');
        
        % Check if the 'ID' already exists.
        if any(dataTable.ID == ID) & any(dataTable.exp == env.exp) 
                rerun = input('Data already cleaned. Add rerun to csv log file? Press 1 for yes, 0 to no. ');
                    if ~rerun
                        warning('ID "%s" already exists in the log file.', ID);
                        return;
                    end
        end
        
        % Add a new row with placeholders for other columns.
        newRow = array2table(repmat("--", 1, width(dataTable)), 'VariableNames', dataTable.Properties.VariableNames);
        newRow.exp = env.exp;
        newRow.ID = ID;
        
        % Append the new row.
        dataTable = [dataTable; newRow];
        
        % Save the updated table.
        writetable(dataTable, logFile);
    end
end

