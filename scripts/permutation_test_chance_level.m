%% PERMUTATION TEST - EMPIRICAL CHANCE LEVEL (supplementary analysis)
% Goal: estimate the empirical chance level for our CSP+LDA classifier by
% randomly shuffling the T1/T2 trial labels many times, retraining and
% re-cross-validating the SAME pipeline on each shuffle, and looking at
% the resulting distribution of "accuracies" a classifier gets when there
% is, by construction, no real relationship between the EEG and the label
% (the labels are random noise). This distribution is the empirical
% chance level - a more rigorous baseline than assuming a flat 50%,
% because it reflects this exact sample size, class balance, and 5-fold
% cross-validation structure.
%
% Not part of the main pipeline - this is a one-off supplementary check
% for the report. Run in its own fresh MATLAB session (BCILAB).

clear; clc; close all;

project_dir = fileparts(fileparts(mfilename('fullpath')));
bcilab_dir  = fullfile(project_dir, 'BCILAB-devel');
data_file   = fullfile(project_dir, 'data_preprocessed', 'S014_L_vs_R_hand_preprocessed.set');
result_out  = fullfile(project_dir, 'data_epoched', 'permutation_test_results.mat');

n_permutations = 20;   % number of random label shuffles to test
rng(42);                % fixed random seed, so this is reproducible if re-run

%% ---- 1. Start BCILAB once (not once per permutation - saves a lot of time) ----
cd(bcilab_dir);
bcilab('autocompile', false);
cd(project_dir);

%% ---- 2. Load the data once ----
% exp_eval() forces BCILAB's lazy-loaded "expression" object into a plain
% EEG struct we can directly read/modify (io_loadset alone returns a
% lazy expression, not a struct with a usable .event field yet).
EEG = exp_eval(io_loadset(data_file));

myapproach = {'CSP', 'SignalProcessing', {'Resampling', 'off'}};

%% ---- 3. Find the T1/T2 events so we can shuffle just their labels ----
event_types = {EEG.event.type};
target_idx  = find(strcmp(event_types, 'T1') | strcmp(event_types, 'T2'));
original_labels = event_types(target_idx);   % the real T1/T2 sequence, 45 labels

fprintf('Found %d target trials (T1/T2) to shuffle.\n', numel(target_idx));

%% ---- 4. Run the permutation test ----
permuted_accuracies = zeros(n_permutations, 1);

for p = 1:n_permutations
    % shuffle the 45 labels randomly among themselves (same 22 T1 / 23 T2
    % counts, just reassigned to random trials - this destroys any real
    % relationship between the EEG and the condition label)
    shuffled_labels = original_labels(randperm(numel(original_labels)));

    EEG_shuffled = EEG;
    for k = 1:numel(target_idx)
        EEG_shuffled.event(target_idx(k)).type = shuffled_labels{k};
    end

    [loss, ~, ~] = bci_train('Data', EEG_shuffled, ...
        'Approach', myapproach, ...
        'TargetMarkers', {'T1', 'T2'});

    permuted_accuracies(p) = 1 - loss;
    fprintf('Permutation %d/%d: accuracy = %.1f%%\n', p, n_permutations, permuted_accuracies(p) * 100);
end

%% ---- 5. Summarize the empirical chance-level distribution ----
empirical_mean = mean(permuted_accuracies);
empirical_std  = std(permuted_accuracies);
empirical_95th = prctile(permuted_accuracies, 95);

fprintf('\n=== Empirical chance level (from %d label-shuffled permutations) ===\n', n_permutations);
fprintf('Mean:   %.1f%%\n', empirical_mean * 100);
fprintf('Std:    %.1f%%\n', empirical_std * 100);
fprintf('95th percentile: %.1f%%\n', empirical_95th * 100);

real_accuracy = 0.622;   % our actual model's accuracy (62.2%), from the real (non-shuffled) run
n_exceeding = sum(permuted_accuracies >= real_accuracy);
fprintf('\nOur real model''s accuracy (62.2%%) exceeded %d/%d shuffles (%.1f%% of the null distribution).\n', ...
    n_exceeding, n_permutations, (n_exceeding/n_permutations)*100);

save(result_out, 'permuted_accuracies', 'empirical_mean', 'empirical_std', 'empirical_95th', 'real_accuracy');
fprintf('\nResults saved to: %s\n', result_out);
