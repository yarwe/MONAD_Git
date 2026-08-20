function log_tbl = repack_fooof(src_root, dst_root, varargin)
%REPACK_FOOOF  Copy *_fooof.mat to a new disk, dropping FieldTrip's cfg.
%
%   log_tbl = REPACK_FOOOF(src_root, dst_root)
%
% prepare_for_fooof.m saves the whole FieldTrip struct with '-nocompression',
% and ~88% of every file is `cfg` - FieldTrip's provenance chain, where
% cfg.previous nests recursively and drags copies of earlier configs along.
% A 2.3 GB file carries ~285 MB of actual data (64 ch x 548352 samples).
% run_fooof_analysis only ever touches d.label, d.trial{1} and d.fsample.
%
% This function rewrites each file keeping the data fields and dropping cfg,
% which turns ~110 GB into ~15 GB and lets the analysis run off a local SSD.
%
% Two things make it safe to run against a disk with bad sectors:
%
%   1. It reads the wanted fields straight out of the v7.3 (HDF5) container
%      and never touches the cfg subtree, so it moves ~1/8 of the bytes and
%      skips most of the disk surface where damage can hide. A file whose
%      bad sectors fall inside cfg repacks fine, even though `load` on it
%      fails. Files that are not v7.3 (older saves are plain v7) fall back
%      to a normal `load`.
%   2. Every file is wrapped in try/catch and written to a .part file that is
%      only renamed into place once it is complete, so an I/O error or a
%      crash leaves no half-written output. Re-running skips what is already
%      there, so an interrupted pass just continues.
%
% Nothing is ever written to or deleted from src_root.
%
% Name/value options:
%   'Fields'    fields to keep (default: everything except cfg)
%   'Single'    true to store trial/time as single, halving size again
%               (default false - EEG in uV does not need 15 digits, but the
%               default leaves numerics untouched)
%   'Overwrite' true to redo files that already exist in dst_root
%               (default false)
%
% Both a flat src_root and one split into group subfolders (NT/ASD) work; the
% subfolder layout is mirrored in dst_root, which is what group_files() in
% run_fooof_analysis expects to find.
%
% Writes repack_log.csv next to the output and returns it as a table.
%
% Example:
%   repack_fooof('D:\MONAD_Git\Data\OSF\simple\FOOOF', ...
%                'C:\Users\yarde\Documents\MONAD_Git\Data\OSF\simple\FOOOF')
%
% See also PREPARE_FOR_FOOOF, RUN_FOOOF_ANALYSIS.

opt = parse_opts(varargin);

if ~isfolder(dst_root), mkdir(dst_root); end

if isfile(src_root)
    % A single file, e.g. to redo one subject after regenerating it. It lands
    % directly in dst_root, so point dst_root at the right group subfolder.
    files    = {src_root};
    src_root = fileparts(src_root);
else
    assert(isfolder(src_root), 'Source not found: %s', src_root);
    files = list_fooof(src_root);
end
if isempty(files)
    error('No *_fooof.mat found under %s', src_root);
end
fprintf('repack_fooof: %d file(s) under %s\n', numel(files), src_root);
fprintf('              -> %s\n\n', dst_root);

n      = numel(files);
name   = cell(n,1);   group = cell(n,1);   status = cell(n,1);
src_mb = zeros(n,1);  dst_mb = zeros(n,1); secs = zeros(n,1);
route  = cell(n,1);   msg = cell(n,1);

for k = 1:n
    src = files{k};
    [rel, base] = split_rel(src, src_root);
    name{k}  = [base '.mat'];
    group{k} = rel;
    if isempty(rel), out_dir = dst_root; else, out_dir = fullfile(dst_root, rel); end
    if ~isfolder(out_dir), mkdir(out_dir); end
    dst = fullfile(out_dir, [base '.mat']);

    s = dir(src);  src_mb(k) = s.bytes / 2^20;
    route{k} = '';  msg{k} = '';

    fprintf('[%2d/%2d] %-22s %7.0f MB  ', k, n, name{k}, src_mb(k));

    if isfile(dst) && ~opt.Overwrite
        d = dir(dst);  dst_mb(k) = d.bytes / 2^20;
        status{k} = 'skipped';  route{k} = 'exists';
        fprintf('already there (%.0f MB), skipping\n', dst_mb(k));
        continue;
    end

    t0  = tic;
    tmp = [dst '.part'];
    try
        [data_repaired, route{k}] = read_fooof(src, opt.Fields); %#ok<ASGLU>
        if opt.Single, data_repaired = to_single(data_repaired); end
        save(tmp, 'data_repaired', '-v7.3');
        clear data_repaired;
        check_written(tmp);
        if isfile(dst), delete(dst); end
        movefile(tmp, dst);

        d = dir(dst);  dst_mb(k) = d.bytes / 2^20;  secs(k) = toc(t0);
        status{k} = 'repacked';
        fprintf('-> %6.0f MB  (%4.1fx smaller, %s, %.0f s)\n', ...
            dst_mb(k), src_mb(k)/max(dst_mb(k), eps), route{k}, secs(k));
    catch ME
        secs(k)   = toc(t0);
        status{k} = 'FAILED';
        msg{k}    = one_line(ME.message);
        if isfile(tmp), delete(tmp); end
        fprintf('** FAILED after %.0f s: %s\n', secs(k), msg{k});
    end
end

log_tbl = table(name, group, status, route, src_mb, dst_mb, secs, msg, ...
    'VariableNames', {'file','group','status','route', ...
                      'src_MB','dst_MB','seconds','message'});
log_file = fullfile(dst_root, 'repack_log.csv');
writetable(log_tbl, log_file);

ok   = strcmp(status, 'repacked');
skip = strcmp(status, 'skipped');
bad  = strcmp(status, 'FAILED');
fprintf('\n---- repack_fooof summary ----------------------------------\n');
fprintf('  repacked %d   skipped %d   FAILED %d\n', sum(ok), sum(skip), sum(bad));
fprintf('  read %.1f GB  ->  wrote %.1f GB', ...
    sum(src_mb(ok))/1024, sum(dst_mb(ok|skip))/1024);
if sum(dst_mb(ok)) > 0
    fprintf('   (%.1fx smaller)', sum(src_mb(ok))/sum(dst_mb(ok)));
end
fprintf('\n');
if any(bad)
    fprintf('  files needing regeneration through prepare_for_fooof.m:\n');
    for k = find(bad)'
        fprintf('    %-22s %s\n', name{k}, msg{k});
    end
end
fprintf('  log: %s\n', log_file);
fprintf('-----------------------------------------------------------\n');
end

% ------------------------------------------------------------------------
function [d, route] = read_fooof(file, keep)
% The FieldTrip struct from file, with cfg (and anything not in keep) left
% behind. Prefers a direct HDF5 read; falls back to load() for non-v7.3
% files, which have to be read whole.
try
    d     = read_v73_struct(file, keep);
    route = 'hdf5';
catch ME
    % Worth recording: falling back means reading ~8x more bytes off the
    % disk, including the cfg subtree where bad sectors may be hiding.
    route  = ['load (hdf5: ' one_line(ME.message) ')'];
    S      = load(file);
    fields = fieldnames(S);
    known  = intersect({'data_repaired', 'dat_after_ICA'}, fields, 'stable');
    if ~isempty(known)
        d = S.(known{1});
    elseif numel(fields) == 1
        d = S.(fields{1});
    else
        error('repack_fooof:ambiguous', ...
            'Cannot tell which variable holds the data (found: %s)', ...
            strjoin(fields', ', '));
    end
    if iscell(d), d = d{1}; end
    drop = setdiff(fieldnames(d), keep);
    d    = rmfield(d, drop);
end
if ~isfield(d, 'trial') || isempty(d.trial)
    error('repack_fooof:notrial', 'No trial data in %s', file);
end
end

% ------------------------------------------------------------------------
function d = read_v73_struct(file, keep)
% Read the one struct variable of a v7.3 MAT file, keeping only `keep`
% fields. Errors (so the caller can fall back) if the file is not HDF5.
if ~H5F.is_hdf5(file)
    error('repack_fooof:notv73', '%s is not a v7.3 MAT-file', file);
end
fid = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
closer = onCleanup(@() H5F.close(fid)); %#ok<NASGU>

vars = group_members(fid, '/');
vars = vars(~startsWith(vars, '#'));      % #refs#, #subsystem#
known = intersect({'data_repaired', 'dat_after_ICA'}, vars, 'stable');
if ~isempty(known)
    var = known{1};
elseif numel(vars) == 1
    var = vars{1};
else
    error('repack_fooof:ambiguous', ...
        'Cannot tell which variable holds the data (found: %s)', ...
        strjoin(vars', ', '));
end

names = group_members(fid, ['/' var]);
names = intersect(names, keep, 'stable');
d     = struct();
for i = 1:numel(names)
    d.(names{i}) = read_node(fid, ['/' var '/' names{i}]);
end
end

% ------------------------------------------------------------------------
function v = read_node(fid, path)
% One MATLAB value from an HDF5 group (struct) or dataset, using the
% MATLAB_class attribute that v7.3 MAT files stamp on every node.
oid = H5O.open(fid, path, 'H5P_DEFAULT');
info = H5O.get_info(oid);
H5O.close(oid);

if info.type == H5ML.get_constant_value('H5O_TYPE_GROUP')
    gid = H5G.open(fid, path);
    closer = onCleanup(@() H5G.close(gid)); %#ok<NASGU>
    v = struct();
    for nm = group_members(fid, path)'
        v.(nm{1}) = read_node(fid, [path '/' nm{1}]);
    end
    return;
end

did = H5D.open(fid, path);
closer = onCleanup(@() H5D.close(did)); %#ok<NASGU>
cls = matlab_class(did);

if attr_true(did, 'MATLAB_empty')
    dims = H5D.read(did);
    v    = zeros(double(dims(:))');
    if strcmp(cls, 'char'),  v = char(v);  end
    if strcmp(cls, 'cell'),  v = cell(size(v)); end
    return;
end

tid = H5D.get_type(did);
if H5T.get_class(tid) == H5ML.get_constant_value('H5T_REFERENCE')
    % Cell array: each element is an object reference into /#refs#.
    ref  = H5D.read(did, 'H5T_STD_REF_OBJ', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
    ncel = size(ref, 2);
    v    = cell(1, ncel);
    for i = 1:ncel
        rid = H5R.dereference(did, 'H5R_OBJECT', ref(:, i));
        v{i} = read_deref(rid);
        H5O.close(rid);
    end
    if strcmp(cls, 'cell') || isempty(cls)
        v = reshape(v, cell_shape(did, ncel));
    else
        v = v{1};
    end
    return;
end

raw = H5D.read(did);
v   = cast_matlab(raw, cls);
end

% ------------------------------------------------------------------------
function shp = cell_shape(did, ncel)
% Original MATLAB shape of a cell array stored as a reference dataset. HDF5
% holds the dimensions reversed, so a FieldTrip 64x1 .label is [1 64] on
% disk - forcing 1xN here would silently transpose every label list.
shp = [ncel 1];
try
    sid = H5D.get_space(did);
    [~, hdims] = H5S.get_simple_extent_dims(sid);
    H5S.close(sid);
    d = fliplr(double(hdims(:)'));
    if numel(d) == 1, d = [d 1]; end
    if prod(d) == ncel, shp = d; end
catch
end
end

% ------------------------------------------------------------------------
function v = read_deref(rid)
% Value behind an object reference (a plain dataset under /#refs#).
cls = matlab_class(rid);
if attr_true(rid, 'MATLAB_empty')
    dims = H5D.read(rid);
    v    = zeros(double(dims(:))');
    if strcmp(cls, 'char'), v = char(v); end
    return;
end
raw = H5D.read(rid);
v   = cast_matlab(raw, cls);
end

% ------------------------------------------------------------------------
function v = cast_matlab(raw, cls)
% Restore the MATLAB class a v7.3 MAT file recorded for a dataset. Numeric
% data comes back already in MATLAB's dimension order, so no transpose.
switch cls
    case 'char'
        v = char(raw);
        if size(v, 2) == 1 && size(v, 1) > 1, v = v'; end
    case 'logical'
        v = logical(raw);
    case {'', 'double'}
        v = double(raw);
    otherwise
        if isnumeric(raw) && ~strcmp(class(raw), cls) && ...
                ismember(cls, {'single','int8','uint8','int16','uint16', ...
                               'int32','uint32','int64','uint64'})
            v = cast(raw, cls);
        else
            v = raw;
        end
end
end

% ------------------------------------------------------------------------
function names = group_members(fid, path)
% Member names of an HDF5 group, without recursing into them (h5info walks
% the whole subtree, which on these files means the entire cfg chain).
gid = H5G.open(fid, path);
closer = onCleanup(@() H5G.close(gid)); %#ok<NASGU>
n     = H5G.get_info(gid).nlinks;
names = cell(n, 1);
for i = 1:n
    names{i} = H5L.get_name_by_idx(gid, '.', 'H5_INDEX_NAME', ...
        'H5_ITER_INC', i-1, 'H5P_DEFAULT');
end
end

% ------------------------------------------------------------------------
function c = matlab_class(oid)
raw = attr_value(oid, 'MATLAB_class');
c   = char(raw(:)');
end

% ------------------------------------------------------------------------
function tf = attr_true(oid, nm)
v  = attr_value(oid, nm);
tf = ~isempty(v) && any(v(:) ~= 0);
end

% ------------------------------------------------------------------------
function v = attr_value(oid, nm)
% Attribute nm of an HDF5 object, or [] when it has none. MATLAB's HDF5
% wrapper has no H5A.exists, so opening and catching is the check.
v = [];
try
    aid = H5A.open(oid, nm);
catch
    return;
end
try
    v = H5A.read(aid);
catch
end
H5A.close(aid);
end

% ------------------------------------------------------------------------
function d = to_single(d)
% Halve the numeric payload. Only the sample arrays are worth converting.
for f = {'trial', 'time'}
    if isfield(d, f{1}) && iscell(d.(f{1}))
        d.(f{1}) = cellfun(@single, d.(f{1}), 'UniformOutput', false);
    end
end
end

% ------------------------------------------------------------------------
function check_written(file)
% Confirm the output is a complete, openable MAT file before it is renamed
% into place: the HDF5 superblock records where the file should end, so a
% truncated write is caught here rather than weeks later.
s = dir(file);
assert(~isempty(s) && s.bytes > 0, 'repack_fooof:empty', ...
    'Wrote an empty file: %s', file);
fh = fopen(file, 'r');
fseek(fh, 512 + 40, 'bof');                 % v0 superblock: end-of-file addr
eof = fread(fh, 1, 'uint64=>double');
fclose(fh);
assert(eof == s.bytes, 'repack_fooof:truncated', ...
    'Output is truncated: header says %d bytes, file is %d', eof, s.bytes);
info = whos('-file', file);                 % errors if the container is bad
assert(any(strcmp({info.name}, 'data_repaired')), 'repack_fooof:novar', ...
    'data_repaired missing from %s', file);
end

% ------------------------------------------------------------------------
function files = list_fooof(root)
% Every *_fooof.mat directly in root or in one of its subfolders, so both a
% flat layout and the NT/ASD split work.
files = fullfile(root, {dir(fullfile(root, '*_fooof.mat')).name});
sub   = dir(root);
sub   = sub([sub.isdir] & ~ismember({sub.name}, {'.', '..'}));
for k = 1:numel(sub)
    p = fullfile(root, sub(k).name);
    files = [files, fullfile(p, {dir(fullfile(p, '*_fooof.mat')).name})]; %#ok<AGROW>
end
files = files(:);
end

% ------------------------------------------------------------------------
function [rel, base] = split_rel(file, root)
% Subfolder of root holding file ('' when file sits in root), and its name.
[p, base]  = fileparts(file);
rel = erase(p, root);
rel = regexprep(rel, '^[\\/]+|[\\/]+$', '');
end

% ------------------------------------------------------------------------
function s = one_line(s)
s = regexprep(s, '\s*\n\s*', ' | ');
s = strtrim(regexprep(s, '<[^>]*>', ''));
if numel(s) > 200, s = [s(1:200) '...']; end
end

% ------------------------------------------------------------------------
function opt = parse_opts(args)
opt = struct('Single', false, 'Overwrite', false, 'Fields', ...
    {{'label','trial','time','fsample','sampleinfo','elec','hdr','trialinfo','grad'}});
for k = 1:2:numel(args)
    nm = validatestring(args{k}, fieldnames(opt));
    opt.(nm) = args{k+1};
end
end
