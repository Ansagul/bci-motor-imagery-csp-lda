# EEG Motor-Imagery Classification (Left vs. Right Hand)

MATLAB pipeline that preprocesses EEG, visualises ERP/ERSP/topographies, and classifies imagined left- vs. right-hand movement for one subject (S014) using **CSP + LDA** in BCILAB with 5-fold cross-validation. A permutation test estimates the empirical chance level.

The full write-up is in [`docs/bci-report.pdf`](docs/bci-report.pdf).

## Pipeline

| Step | Script | Toolbox | What it does |
|---|---|---|---|
| 1 | `scripts/step1_preprocessing_epoching_visualization.m` | EEGLAB | Cleans the continuous recording, epochs it, produces ERP / ERSP / topography plots. |
| 2 | `scripts/step2_classify_bcilab.m` | BCILAB | Trains CSP (mu/beta band) + LDA and cross-validates. |
| 3 | `scripts/step3_results_and_extraplots.m` | EEGLAB | Confusion matrix, accuracy table and extra plots from step 2. |
| – | `scripts/permutation_test_chance_level.m` | BCILAB | Shuffles trial labels (20 permutations, fixed seed) to estimate chance-level accuracy. |

Run step 2 and the permutation test in a **fresh MATLAB session**, since BCILAB changes the path. Order: step 1, restart MATLAB, step 2, restart, step 3.

## Setup

The scripts locate the project root as the parent of the `scripts/` folder. Place these next to it (they are git-ignored, not included here):

```
eeglab2026.1.0/          EEGLAB
BCILAB-devel/            BCILAB
S014_L_vs_R_hand.set     the raw EEG recording (+ .fdt)
```

Intermediate files go to `data_preprocessed/`, `data_epoched/` and `figures/`, which the scripts create.

## Data

Subject **S014** from the *EEG Motor Movement/Imagery Dataset* (64-channel EEG, 109 participants, recorded with the BCI2000 system; imagined left- vs. right-hand movement). The data is **not** included in this repository.

- Source: [NEMAR on004362](https://nemar.org/dataset/on004362) (OpenNeuro ds004362)
- Licence: CC0 (public domain)
- Citation: Schalk, G., McFarland, D. J., Hinterberger, T., Birbaumer, N., & Wolpaw, J. R. (2026). *EEG Motor Movement/Imagery Dataset* (v1.0.0) [Data set]. NEMAR. https://doi.org/10.82901/nemar.on004362
