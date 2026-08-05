function tf = isequal_with_nan(A, B)
    % Compare cell arrays that may contain NaN values
    if ~isequal(size(A), size(B))
        tf = false;
        return;
    end
    
    tf = true;
    for i = 1:numel(A)
        cellA = A{i};
        cellB = B{i};
        
        % Check if both empty or both non-empty
        if isempty(cellA) && isempty(cellB)
            continue;
        elseif isempty(cellA) || isempty(cellB) || ~isequal(size(cellA), size(cellB))
            tf = false;
            return;
        end
        
        % Compare matrices with NaN handling
        mask = ~isnan(cellA) & ~isnan(cellB);
        if ~all(all(cellA(mask) == cellB(mask)))
            tf = false;
            return;
        end
        
        % Check NaN positions match
        if ~isequal(isnan(cellA), isnan(cellB))
            tf = false;
            return;
        end
    end
end