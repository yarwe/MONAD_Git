clc; clear all;
cd('C:\Users\yoelgo\Desktop\MONAD_Git')
env = setupEnviroment('OSF_simple');

%% Load single participant
ID          = env.data.ID{1};
filename    = [env.paths.raw ID env.data.prefix];
EEG         = load_data(env, filename);

clear ALLEEG ALLCOM ALLEEG CURRENTSTUDY CURRENTSET globalvars LASTCOM PLUGINLIST STUDY tmpEEG
%%
