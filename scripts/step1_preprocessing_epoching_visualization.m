%% step 1 - cleaning the data + making plots
% does the cleaning, cuts into trials, makes the erp/ersp/topo plots
% left vs right hand imagery, subject S014
%
% only uses eeglab, should run fine on its own
%
% NOTE: step 2 (the bcilab part) needs to run in a NEW matlab window
% bcilab messes with the path so cant run it right after this one
% order: step1 -> close matlab -> step2 -> close matlab -> step3

clear; clc; close all;

% figures out the folder by itself so i dont have to change the path
% every time i move the folder around
projdir  = fileparts(fileparts(mfilename('fullpath')));
eeglabdir   = fullfile(projdir, 'eeglab2026.1.0');
predir      = fullfile(projdir, 'data_preprocessed');
epdir    = fullfile(projdir, 'data_epoched');
figdir      = fullfile(projdir, 'figures');

% file that has the electrode positions, comes with eeglab
montagefile = fullfile(eeglabdir, 'plugins', 'dipfit', 'standard_BESA', ...
                         'standard-10-5-cap385.elp');

if ~exist(predir, 'dir');   mkdir(predir);   end
if ~exist(epdir, 'dir'); mkdir(epdir); end
if ~exist(figdir, 'dir');   mkdir(figdir);   end

%% 1. start eeglab
addpath(eeglabdir);
eeglab nogui;   % nogui so it doesnt pop up a window


%% ===================== PART A - CLEANING =====================
% take the raw file and clean it up BEFORE cutting into trials
% cleaning works better on the long continuous file apparently

%% load the raw file
eeg = pop_loadset('filename', 'S014_L_vs_R_hand.set', 'filepath', projdir);
eeg = eeg_checkset(eeg);   % just a sanity check eeglab does

fprintf('Loaded raw data: %d channels, %.0f seconds, %.0f Hz\n', ...
    eeg.nbchan, eeg.xmax, eeg.srate);

%% electrode positions
% need this for later steps (asr, ica, topoplots) so it knows where
% each electrode actually is on the head
eeg = pop_chanedit(eeg, 'lookup', montagefile);
eeg = eeg_checkset(eeg);

%% filter the signal
% 1hz highpass gets rid of slow drift, pretty standard before ica
eeg = pop_eegfiltnew(eeg, 'locutoff', 1, 'hicutoff', []);   % highpass 1hz

% 40hz lowpass, our signal (mu/beta ~8-30hz) is way below this anyway
% so cutting above 40 shouldnt lose anything we care about
eeg = pop_eegfiltnew(eeg, 'locutoff', [], 'hicutoff', 40);  % lowpass 40hz
eeg = eeg_checkset(eeg);

%% fix bad channels / bursts (ASR)
% some electrodes are noisy the whole time, some parts of the signal
% just have random big spikes (person moved etc). ASR finds + fixes
% both of these automatically, its in the clean_rawdata plugin

chanlocs_bak = eeg;   % save the full 64ch layout so we can put back
                                 % any channels ASR deletes

eeg = clean_artifacts(eeg, ...
    'FlatlineCriterion', 5, ...    % flat/dead channel for >5s = reject
    'ChannelCriterion',  0.8, ...  % doesnt correlate w/ neighbours = reject
    'LineNoiseCriterion', 4, ...   % too noisy compared to other chans = reject
    'Highpass',          'off', ...% already did the highpass above
    'BurstCriterion',    20, ...   % how strict it is about weird bursts
    'WindowCriterion',   0.25, ... % drop tiny leftover bad windows
    'BurstRejection',    'off');   % fix bursts instead of deleting that time
eeg = eeg_checkset(eeg);

fprintf('Channels kept after cleaning: %d out of %d\n', ...
    eeg.nbchan, chanlocs_bak.nbchan);

%% put back any channels that got removed
% asr sometimes kills 1-2 channels, this fills them back in using
% the other good channels so we still have 64 chans at the end
eeg = pop_interp(eeg, chanlocs_bak.chanlocs, 'spherical');
eeg = eeg_checkset(eeg);

%% re-reference
% eeg voltage is always relative to smth, using the average of all
% channels is the normal safe choice
eeg = pop_reref(eeg, []);
eeg = eeg_checkset(eeg);

%% ICA
% blinks/muscle stuff look totally different math-wise than brain
% signal, so ica splits everything into components and we can just
% toss the bad ones. using extended infomax, its the eeglab default
eeg = pop_runica(eeg, 'icatype', 'runica', 'extended', 1);
eeg = eeg_checkset(eeg);

%% label the components (brain vs junk)
% iclabel guesses if each comp is brain/muscle/eye/etc automatically
% so we dont have to eyeball 60 component maps ourselves
eeg = pop_iclabel(eeg, 'default');

% only remove a comp if iclabel is 80%+ sure its eye or muscle
% being kinda strict here so we dont accidentally nuke real brain stuff
eeg = pop_icflag(eeg, [NaN NaN; 0.8 1; 0.8 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
%                     brain   muscle  eye   heart  line   chnoise other

badcomps = find(eeg.reject.gcompreject);   % which comps got flagged
fprintf('Removing %d artefact component(s): %s\n', numel(badcomps), mat2str(badcomps));

eeg = pop_subcomp(eeg, badcomps, 0);   % actually remove them
eeg = eeg_checkset(eeg);

%% save the cleaned continuous file
% still continuous here, NOT cut into trials yet, thats part B
% this is the "preprocessed dataset" they asked us to hand in
eeg.setname = 'S014_L_vs_R_hand_preprocessed';
pop_saveset(eeg, 'filename', 'S014_L_vs_R_hand_preprocessed.set', 'filepath', predir);

fprintf('\nPart A done. Preprocessed data saved to: %s\n', ...
    fullfile(predir, 'S014_L_vs_R_hand_preprocessed.set'));


%% ===================== PART B - EPOCHING + PLOTS =====================
% cut the cleaned signal into trials around the left/right cues then
% see if the 2 conditions actually look diff from each other
%
% T0 = rest, T1 = imagine LEFT fist, T2 = imagine RIGHT fist
% each imagery bit is about 4 sec long

%% cut into trials
% -1 to 0s = baseline (before cue), 0 to 4s = the actual imagery part
eeg_ep = pop_epoch(eeg, {'T1', 'T2'}, [-1 4], 'newname', 'S014_epoched');

% baseline correction - subtracts the avg of the -1 to 0s bit from
% the rest of the trial so trials are comparable to eachother
eeg_ep = pop_rmbase(eeg_ep, [-1000 0]);
eeg_ep = eeg_checkset(eeg_ep);

fprintf('Total trials after epoching: %d\n', eeg_ep.trials);

%% split into the 2 conditions
eeg_L  = pop_selectevent(eeg_ep, 'type', 'T1', 'deleteevents', 'off', 'deleteepochs', 'on');
eeg_R = pop_selectevent(eeg_ep, 'type', 'T2', 'deleteevents', 'off', 'deleteepochs', 'on');

fprintf('Left-hand imagery (T1) trials:  %d\n', eeg_L.trials);
fprintf('Right-hand imagery (T2) trials: %d\n', eeg_R.trials);

%% save the epoched file
% not actually required for the assignment but nice to keep for later
eeg_ep.setname = 'S014_L_vs_R_hand_epoched';
pop_saveset(eeg_ep, 'filename', 'S014_L_vs_R_hand_epoched.set', 'filepath', epdir);

%% find C3 and C4 channel numbers
% C3 = left motor cortex, C4 = right motor cortex. brain is crossed
% over so RIGHT hand imagery shud lower power at C3 and vice versa
c3i = find(strcmpi({eeg_ep.chanlocs.labels}, 'C3'));
c4i = find(strcmpi({eeg_ep.chanlocs.labels}, 'C4'));

%% PLOT 1 - erp at c3/c4
% simplest comparison possible, avg all left trials, avg all right
% trials, plot both lines and see if they look diff

erpL3  = mean(eeg_L.data(c3i, :, :), 3);
erpR3 = mean(eeg_R.data(c3i, :, :), 3);
erpL4  = mean(eeg_L.data(c4i, :, :), 3);
erpR4 = mean(eeg_R.data(c4i, :, :), 3);

figure('Visible', 'off', 'Position', [100 100 1000 500], 'Color', 'w');

subplot(1, 2, 1);   % c3
plot(eeg_ep.times, erpL3,  'b', 'LineWidth', 1.5); hold on;
plot(eeg_ep.times, erpR3, 'r', 'LineWidth', 1.5);
xline(0, '--k');   % when the cue happened
xlabel('Time (ms)'); ylabel('Amplitude (\muV)');
title('Channel C3 (left motor cortex)');
legend({'Left-hand imagery (T1)', 'Right-hand imagery (T2)'}, 'Location', 'best');
grid on;

subplot(1, 2, 2);   % c4
plot(eeg_ep.times, erpL4,  'b', 'LineWidth', 1.5); hold on;
plot(eeg_ep.times, erpR4, 'r', 'LineWidth', 1.5);
xline(0, '--k');
xlabel('Time (ms)'); ylabel('Amplitude (\muV)');
title('Channel C4 (right motor cortex)');
legend({'Left-hand imagery (T1)', 'Right-hand imagery (T2)'}, 'Location', 'best');
grid on;

sgtitle('Grand-average EEG signal: Left vs. Right Hand Motor Imagery');
saveas(gcf, fullfile(figdir, 'erp_C3_C4_left_vs_right.png'));

%% PLOT 2 - ersp (time freq) at c3/c4
% raw waveform above is way too noisy to read anything from since
% motor imagery mostly changes the POWER not the shape of the wave
% newtimef does this for us (its built into eeglab)
% blue = power going down = "ERD" = usually happens during imagery
figure('Visible', 'off', 'Position', [100 100 1200 900], 'Color', 'w');

subplot(2, 2, 1);
newtimef(squeeze(eeg_L.data(c3i, :, :)), eeg_ep.pnts, ...
    [eeg_ep.times(1) eeg_ep.times(end)], eeg_ep.srate, [3 0.5], ...
    'baseline', [-1000 0], 'plotphase', 'off', 'freqs', [4 40], ...
    'title', 'Left-hand imagery (T1) @ C3');

subplot(2, 2, 2);
newtimef(squeeze(eeg_R.data(c3i, :, :)), eeg_ep.pnts, ...
    [eeg_ep.times(1) eeg_ep.times(end)], eeg_ep.srate, [3 0.5], ...
    'baseline', [-1000 0], 'plotphase', 'off', 'freqs', [4 40], ...
    'title', 'Right-hand imagery (T2) @ C3');

subplot(2, 2, 3);
newtimef(squeeze(eeg_L.data(c4i, :, :)), eeg_ep.pnts, ...
    [eeg_ep.times(1) eeg_ep.times(end)], eeg_ep.srate, [3 0.5], ...
    'baseline', [-1000 0], 'plotphase', 'off', 'freqs', [4 40], ...
    'title', 'Left-hand imagery (T1) @ C4');

subplot(2, 2, 4);
newtimef(squeeze(eeg_R.data(c4i, :, :)), eeg_ep.pnts, ...
    [eeg_ep.times(1) eeg_ep.times(end)], eeg_ep.srate, [3 0.5], ...
    'baseline', [-1000 0], 'plotphase', 'off', 'freqs', [4 40], ...
    'title', 'Right-hand imagery (T2) @ C4');

set(gcf, 'Color', 'w');   % newtimef keeps resetting bg to eeglab blue, force it white again
saveas(gcf, fullfile(figdir, 'ersp_C3_C4_left_vs_right.png'));

%% PLOT 3 - topo map of mu power
% shows mu power (8-12hz) across the WHOLE scalp, not just c3/c4
% reuse the filter fn to isolate mu band then just square + avg it
% to get a rough power number, simple but works fine
muband = [8 12];

% sample numbers for 0ms and 4000ms
[~, t0idx] = min(abs(eeg_ep.times - 0));
[~, t4idx] = min(abs(eeg_ep.times - 4000));

eeg_Lmu  = pop_eegfiltnew(eeg_L,  'locutoff', muband(1), 'hicutoff', muband(2));
eeg_Rmu = pop_eegfiltnew(eeg_R, 'locutoff', muband(1), 'hicutoff', muband(2));

% mean squared amplitude across time (0-4s) and trials, per channel
pwrL  = mean(mean(eeg_Lmu.data(:, t0idx:t4idx, :) .^ 2, 2), 3);
pwrR = mean(mean(eeg_Rmu.data(:, t0idx:t4idx, :) .^ 2, 2), 3);
pwrdiff = pwrL - pwrR;

figure('Visible', 'off', 'Position', [100 100 1200 400], 'Color', 'w');

subplot(1, 3, 1);
topoplot(pwrL, eeg_ep.chanlocs, 'electrodes', 'off');
title('Mu power (8-12 Hz): Left-hand imagery'); colorbar;

subplot(1, 3, 2);
topoplot(pwrR, eeg_ep.chanlocs, 'electrodes', 'off');
title('Mu power (8-12 Hz): Right-hand imagery'); colorbar;

subplot(1, 3, 3);
topoplot(pwrdiff, eeg_ep.chanlocs, 'electrodes', 'off');
title('Difference (Left minus Right)'); colorbar;

sgtitle('Scalp topography of mu-band power during imagery (0-4 s)');
set(gcf, 'Color', 'w');   % same bg fix as before
saveas(gcf, fullfile(figdir, 'topo_mu_power_left_vs_right.png'));

fprintf('\nStep 1 complete.\n');
fprintf('Preprocessed (continuous) dataset: %s\n', fullfile(predir, 'S014_L_vs_R_hand_preprocessed.set'));
fprintf('Epoched dataset: %s\n', fullfile(epdir, 'S014_L_vs_R_hand_epoched.set'));
fprintf('Figures saved to: %s\n', figdir);
fprintf('\nNext: close matlab, open new one, run step2_classify_bcilab.m\n');
