xlsfile = 'C:\Users\yarde\Downloads\Cap_coords_all.xls';

C = readcell(xlsfile, 'Sheet', '64-chan');

% BioSemi file: electrode table starts at row 35 and ends at row 98
labels = C(35:98, 1);
theta  = cell2mat(C(35:98, 11));   % sph_theta
phi    = cell2mat(C(35:98, 13));   % sph_phi

% Clean labels to match usual FieldTrip/BioSemi names
labels = string(labels);
labels = replace(labels, " (T3)", "");
labels = replace(labels, " (T4)", "");
labels = replace(labels, " (inion)", "");
labels(labels == "Afz") = "AFz";

% Convert BioSemi geographic coordinates to 2-D layout coordinates
headrad = 0.50;
r = headrad * (90 - phi) / 90;
th = deg2rad(theta);

x = -r .* sin(th);
y =  r .* cos(th);

lay = [];
lay.label  = cellstr(labels);
lay.pos    = [x y];
lay.width  = repmat(0.060, numel(labels), 1);
lay.height = repmat(0.045, numel(labels), 1);

% Add a more useful schematic outline
t = linspace(0, 2*pi, 200)';
head_radius = 0.52;

lay.outline = {
    [head_radius*cos(t), head_radius*sin(t)]                         % head
    [-0.06 0.52; 0 0.61; 0.06 0.52]                                  % nose
    [-0.52 -0.10; -0.58 -0.06; -0.58 0.08; -0.52 0.12; -0.52 -0.10]  % left ear
    [ 0.52 -0.10;  0.58 -0.06;  0.58 0.08;  0.52 0.12;  0.52 -0.10]  % right ear
};

lay.mask = {
    [head_radius*cos(t), head_radius*sin(t)]
};

cfg = [];
cfg.layout = lay;
ft_layoutplot(cfg);