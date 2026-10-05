%% step 3 - confusion matrix + accuracy table + extra plots
% takes the classifier results from step 2 and turns them into a
% confusion matrix + accuracy table, plus a few more plots that are
% easier to explain than the ersp one
%
% run this AFTER:
%   1) step1 has been run once
%   2) step2 has been run once (its own separate matlab window)
% this file only needs eeglab + normal matlab stuff, no bcilab here
% so its fine to run in a regular session

clear; clc; close all;

%% 0. paths
% finds the folder on its own based on where this script is sitting
projdir = fileparts(fileparts(mfilename('fullpath')));
eeglabdir  = fullfile(projdir, 'eeglab2026.1.0');
predir     = fullfile(projdir, 'data_preprocessed');
modelfile  = fullfile(projdir, 'data_epoched', 'S014_LvR_CSP_model.mat');
figdir     = fullfile(projdir, 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end

addpath(eeglabdir);
eeglab nogui;


%% ===================== PART A - confusion matrix + acc table =====================
% turns the cv results from step2 into a confusion matrix (what the
% model guessed vs what it actually was) + a table you can just put
% in the report/slides
%
% doesnt retrain anything, just reopens what step2 already saved

%% load the saved results
load(modelfile, 'stats');   % the stats struct step2 saved
nfolds = numel(stats.per_fold);
fprintf('Loaded results from %d cross-validation folds.\n', nfolds);

%% grab true label + guess for every trial
% bci_train tests each trial exactly once (its in exactly 1 of the 5
% folds test set) so if we grab all 5 folds together we get one
% true/guess pair per trial - 45 total, which is what we need for
% the confusion matrix
%
% bcilab keeps each folds guess as this weird 3 part cell thing:
%   pred{1} = 'disc' (just means its a classification not a number)
%   pred{2} = Nx2 matrix, confidence for each class per trial
%   pred{3} = [1;2] which column = which class
% so the actual guess = whichever column has the higher number

truelbls = [];        % real label for every trial
predlbls = [];   % model guess for every trial

for f = 1:nfolds
    tl = stats.per_fold(f).targ;          % real labels (1=left, 2=right)
    conf     = stats.per_fold(f).pred{2};       % confidence per class
    classord           = stats.per_fold(f).pred{3};       % which col = which class

    [~, winidx] = max(conf, [], 2);        % highest confidence column
    pl = classord(winidx);   % turn into an actual class label

    truelbls      = [truelbls;      tl]; %#ok<AGROW>
    predlbls = [predlbls;  pl]; %#ok<AGROW>
end

fprintf('Collected predictions for %d trials in total.\n', numel(truelbls));

%% turn 1/2 into actual words
% 1 and 2 dont mean anything on their own so relabel em
classnames = {'Left hand (T1)', 'Right hand (T2)'};
truenamed      = categorical(truelbls,      [1 2], classnames);
prednamed = categorical(predlbls,  [1 2], classnames);

%% make the confusion matrix
% confusionmat is a normal matlab fn (stats toolbox), just counts
% how many trials fall into each true/guess combo
cm = confusionmat(truenamed, prednamed);

disp('Confusion matrix (rows = true condition, columns = predicted condition):');
disp(array2table(cm, 'VariableNames', {'Pred_Left','Pred_Right'}, ...
    'RowNames', {'True_Left','True_Right'}));

%% plot it + save
% confusionchart also shows row/col percentages automatically which
% is nice for the slides
figure('Visible', 'off', 'Position', [100 100 500 450], 'Color', 'w');
confusionchart(truenamed, prednamed, ...
    'Title', 'Left vs. Right Hand Motor Imagery - Confusion Matrix', ...
    'RowSummary', 'row-normalized', ...     % recall per class
    'ColumnSummary', 'column-normalized');  % precision per class
saveas(gcf, fullfile(figdir, 'confusion_matrix.png'));

%% basic accuracy numbers
% overall acc = % of trials it got right
ncorrect = sum(truelbls == predlbls);
ntotal   = numel(truelbls);
acc = ncorrect / ntotal;
fprintf('\nOverall accuracy: %d / %d trials correct = %.1f%%\n', ...
    ncorrect, ntotal, acc * 100);

% recall = of the ones that were REALLY this class, how many did we catch
% precision = of the ones we GUESSED this class, how many were actually right
recL     = cm(1,1) / sum(cm(1,:));
recR    = cm(2,2) / sum(cm(2,:));
precL  = cm(1,1) / sum(cm(:,1));
precR = cm(2,2) / sum(cm(:,2));

%% put it all in a table
cond = {'Left hand (T1)'; 'Right hand (T2)'; 'OVERALL'};
rec    = [recL;    recR;    NaN];
prec = [precL; precR; NaN];
accCol  = [NaN;            NaN;             acc];

scorestbl = table(cond, rec, prec, accCol);
disp('Accuracy scores table:');
disp(scorestbl);

writetable(scorestbl, fullfile(figdir, 'accuracy_scores_table.csv'));

fprintf('\nPart A done.\n');


%% ===================== PART B - extra plots =====================
% couple more simple plots to help explain the results, nothing new
% being calculated here, just looking at the same stuff differently

%% PLOT - raw vs cleaned signal, same channel same time window
% simplest way to actually show that step1 did something. plotting
% the same 15sec of the same channel before/after cleaning

eegraw   = pop_loadset('filename', 'S014_L_vs_R_hand.set', 'filepath', projdir);
eegclean = pop_loadset('filename', 'S014_L_vs_R_hand_preprocessed.set', 'filepath', predir);

% FP1 = frontal electrode near the eyes, best spot to see blinks
fp1i = find(strcmpi({eegraw.chanlocs.labels}, 'FP1'));

% first 15 sec of the recording
winsamp = 1 : round(15 * eegraw.srate);
tsec  = eegraw.times(winsamp) / 1000;   % ms -> sec

rawsnip    = eegraw.data(fp1i, winsamp);
cleansnip  = eegclean.data(fp1i, winsamp);

figure('Visible', 'off', 'Position', [100 100 900 500], 'Color', 'w');

subplot(2, 1, 1);
plot(tsec, rawsnip, 'k');
title('BEFORE preprocessing (raw signal, channel FP1)');
xlabel('Time (s)'); ylabel('Amplitude (\muV)');
grid on;

subplot(2, 1, 2);
plot(tsec, cleansnip, 'b');
title('AFTER preprocessing (filtered, ASR-corrected, ICA-cleaned, channel FP1)');
xlabel('Time (s)'); ylabel('Amplitude (\muV)');
grid on;

sgtitle('Effect of Preprocessing on the Raw EEG Signal');
saveas(gcf, fullfile(figdir, 'raw_vs_cleaned_signal.png'));

%% PLOT - trials per condition (class balance)
% accuracy is misleading if one class has way more trials than the
% other, this just checks that ours are close to even (they are)

eegep = pop_epoch(eegclean, {'T1', 'T2'}, [-1 4], 'newname', 'S014_epoched');
eegep = pop_rmbase(eegep, [-1000 0]);

eegL  = pop_selectevent(eegep, 'type', 'T1', 'deleteevents', 'off', 'deleteepochs', 'on');
eegR = pop_selectevent(eegep, 'type', 'T2', 'deleteevents', 'off', 'deleteepochs', 'on');

nL  = eegL.trials;
nR = eegR.trials;

figure('Visible', 'off', 'Position', [100 100 500 400], 'Color', 'w');
bar([nL, nR]);
set(gca, 'XTickLabel', {'Left hand (T1)', 'Right hand (T2)'});
ylabel('Number of trials');
title('Number of Trials per Condition');
grid on;
saveas(gcf, fullfile(figdir, 'class_balance.png'));

fprintf('Left-hand trials: %d, Right-hand trials: %d\n', nL, nR);

%% PLOT - accuracy per fold + vs chance
% one accuracy number can hide how consistent it actually was.
% showing all 5 folds separately + comparing to the 50% chance line
% (stats already loaded up in part A)

foldaccs  = 1 - [stats.per_fold.mcr];   % error -> accuracy per fold
accbar = 1 - stats.mcr;          % overall acc pooled across everything

figure('Visible', 'off', 'Position', [100 100 900 400], 'Color', 'w');

subplot(1, 2, 1);
bar(foldaccs * 100);
yline(50, '--r', 'Chance level');
set(gca, 'XTickLabel', {'Fold 1', 'Fold 2', 'Fold 3', 'Fold 4', 'Fold 5'});
ylabel('Accuracy (%)');
ylim([0 100]);
title('Accuracy per Cross-Validation Fold');
grid on;

subplot(1, 2, 2);
bar([accbar * 100, 50]);
set(gca, 'XTickLabel', {'Our Classifier', 'Chance Level'});
ylabel('Accuracy (%)');
ylim([0 100]);
title('Overall Accuracy vs. Chance');
grid on;

sgtitle('Classifier Performance Summary');
saveas(gcf, fullfile(figdir, 'accuracy_per_fold_and_overall.png'));

%% PLOT - power spectrum at c3/c4 left vs right
% the ersp plot from step1 is kinda hard to read so this is a
% simpler version - just power vs frequency, plain fft. shud see a
% dip around 8-12hz (mu) on the OPPOSITE side from the hand imagined

c3i = find(strcmpi({eegep.chanlocs.labels}, 'C3'));
c4i = find(strcmpi({eegep.chanlocs.labels}, 'C4'));

% just the imagery window, 0 to 4 sec after the cue
[~, t0i] = min(abs(eegep.times - 0));
[~, t4i] = min(abs(eegep.times - 4000));
nsamp = t4i - t0i + 1;

% freq of each fft bin (only need up to nyquist since eeg is real valued)
freqax = (0:nsamp-1) * (eegep.srate / nsamp);
keepf = freqax <= 40;   % only care about up to 40hz

% c3
segL3  = squeeze(eegL.data(c3i,  t0i:t4i, :));   % samples x trials
segR3 = squeeze(eegR.data(c3i, t0i:t4i, :));
pL3  = mean(abs(fft(segL3)).^2, 2);   % fft per trial then avg power
pR3 = mean(abs(fft(segR3)).^2, 2);

% c4
segL4  = squeeze(eegL.data(c4i,  t0i:t4i, :));
segR4 = squeeze(eegR.data(c4i, t0i:t4i, :));
pL4  = mean(abs(fft(segL4)).^2, 2);
pR4 = mean(abs(fft(segR4)).^2, 2);

figure('Visible', 'off', 'Position', [100 100 1000 450], 'Color', 'w');

subplot(1, 2, 1);
plot(freqax(keepf), pL3(keepf),  'b', 'LineWidth', 1.5); hold on;
plot(freqax(keepf), pR3(keepf), 'r', 'LineWidth', 1.5);
xline(8, ':k'); xline(12, ':k');   % mu band edges
xlabel('Frequency (Hz)'); ylabel('Power');
title('Channel C3 (left motor cortex)');
legend({'Left-hand imagery (T1)', 'Right-hand imagery (T2)'});
grid on;

subplot(1, 2, 2);
plot(freqax(keepf), pL4(keepf),  'b', 'LineWidth', 1.5); hold on;
plot(freqax(keepf), pR4(keepf), 'r', 'LineWidth', 1.5);
xline(8, ':k'); xline(12, ':k');
xlabel('Frequency (Hz)'); ylabel('Power');
title('Channel C4 (right motor cortex)');
legend({'Left-hand imagery (T1)', 'Right-hand imagery (T2)'});
grid on;

sgtitle('Power Spectrum during Imagery (dotted lines = mu-band 8-12 Hz)');
saveas(gcf, fullfile(figdir, 'psd_C3_C4_left_vs_right.png'));

fprintf('\nStep 3 complete. All figures saved to: %s\n', figdir);
