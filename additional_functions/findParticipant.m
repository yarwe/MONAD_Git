function idx = findParticipant(tbl, id)
%FINDPARTICIPANT Row index of participant ID, ignoring leading zeros.
    norm = @(s) regexprep(strtrim(s), '^0+(?=.)', '');
    idx  = find(strcmp(norm(tbl.ID), norm(id)));
    if isempty(idx)
        warning('ID ''%s'' not found in table.', id);
    elseif numel(idx) > 1
        warning('ID ''%s'' matches %d rows.', id, numel(idx));
    end
end