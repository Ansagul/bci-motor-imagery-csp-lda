%% step 2 - training the classifier (left vs right hand)
% trys to guess from the eeg if person was imagining left or right hand
% and checks how good that guess actually is
%
% input: the cleaned continuous file from step1 (not epoched, bcilab
% cuts it into trials by itself so we dont need to do that part)

clear; clc; close all;

%% 0. paths
% auto finds the project folder from where this script is, so it
% still works even if i move the whole folder somewhere else
projdir = fileparts(fileparts(mfilename('fullpath')));
bcilabdir  = fullfile(projdir, 'BCILAB-devel');
datafile   = fullfile(projdir, 'data_preprocessed', 'S014_L_vs_R_hand_preprocessed.set');
modelout   = fullfile(projdir, 'data_epoched', 'S014_LvR_CSP_model.mat');

%% 1. start bcilab

cd(bcilabdir);
bcilab('autocompile', false);

%% 2. load the data (bcilabs own loader)
eeg = io_loadset(datafile);

%% 3. pick the method - CSP + LDA
% CSP = common spatial patterns, its THE classic method for this kind
% of task. basically instead of using all 64 raw channels it makes a
% few new "fake channels" that are picked to make the power as
% different as possible between left vs right trials - which is
% exactly what changes during imagery (mu/beta erd thing)
%
% the built in "CSP" thing in bcilab does all this automatically:
%   - bandpass filters around 6-8-28-32 hz (covers mu+beta)
%   - cuts 0.5s to 3.5s after each cue (skip the first bit, stop
%     before the trial edge)
%   - does the csp filters + turns it into log-variance features
%   - classifies those feats with LDA (linear discriminant analysis)
%     which is basically the standard pairing for csp stuff
%
% turned resampling off cuz it needs the signal proc toolbox which
% we dont have, our data is already 160hz which is plenty 
myapproach = {'CSP', 'SignalProcessing', {'Resampling', 'off'}};

%% 4. train + test it
% bci_train does both training AND testing basically. trains on most
% trials, tests on the rest, repeats a bunch (cross validation), then
% avgs the error. using the default 5-fold "chronological" cv which
% splits trials by time order instead of randomly shuffling - safer
% for eeg since trials next to eachother arent totally independant
[loss, model, stats] = bci_train('Data', eeg, ...
    'Approach', myapproach, ...
    'TargetMarkers', {'T1', 'T2'});   % T1=left, T2=right

% loss = % of trials it got wrong
fprintf('\n=== Cross-validated accuracy: %.1f%% (chance level = 50%%) ===\n', (1 - loss) * 100);

%% 5. look at the results in more detail
disp('Per-fold stats (mcr_mu = avg error, mcr_std = how spread out across folds):');
disp(stats);

%% 6. save the model
% so we can reload it later without having to retrain everything again
save(modelout, 'model', 'loss', 'stats');
fprintf('Model saved to: %s\n', modelout);
