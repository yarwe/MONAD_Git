function [logFile] = csv_init15(env, ID)
% Initiates the main csv log file
    csv_name_file = "MONAD_log.csv";
    if isfield(env.paths,'csv_log')
        logFile = fullfile(env.paths.csv_log, csv_name_file);
        if ~exist(env.paths.csv_log, 'dir')
            mkdir(env.paths.csv_log);
        end
    elseif ~isfield(env, 'dat_ay')
        logFile = fullfile('R:\Yarden\', csv_name_file);
    else
        logFile = fullfile(env.dat_ay, ':\Yarden\', csv_name_file);
    end
    
    if ~isfile(logFile)
        % If log.csv does not exist, create it with the initial structure.
        headers = {'exp', 'ID'};
        data = {env.exp, ID};
        writecell([headers; data], logFile);
    else
        % If log.csv exists, retrieve the current content.
        opts = detectImportOptions(logFile);
        opts = setvartype(opts, opts.VariableNames, 'string');   % force every column to text
        dataTable = readtable(logFile, opts);
        % dataTable = readtable(logFile, 'TextType', 'string');
        
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
        newRow.ID = string(ID);
        
        % Append the new row.
        dataTable = [dataTable; newRow];
        
        % Save the updated table.
        writetable(dataTable, logFile);
    end
end

