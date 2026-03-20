<p align="center">
  <img src="plots/decision_tree.png" width="700"/>
</p>

<h1 align="center">Personal Loan Acceptance Prediction</h1>

<p align="center">
  <em>MISCADA ASML Classification Summative — Durham University</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/R-4.4.2+-276DC3?logo=r&logoColor=white" alt="R"/>
  <img src="https://img.shields.io/badge/LaTeX-IEEEtran-008080?logo=latex&logoColor=white" alt="LaTeX"/>
  <img src="https://img.shields.io/badge/Models-8-orange" alt="Models"/>
  <img src="https://img.shields.io/badge/Best_AUC-0.998-brightgreen" alt="AUC"/>
  <img src="https://img.shields.io/badge/Seed-42-blueviolet" alt="Seed"/>
</p>

---

## Overview

Binary classification of personal loan acceptance using the Thera Bank dataset (5,000 customers, 9.6% positive rate). Eight models are trained, compared, and evaluated with a full cost-benefit threshold analysis.

## Results at a Glance

| | Random Forest | GBM | Neural Net | SVM | Decision Tree | Logistic | LDA | Elastic Net |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **AUC** | **0.998** | 0.996 | 0.983 | 0.976 | 0.977 | 0.942 | 0.940 | 0.943 |
| **Sensitivity** | **0.917** | 0.896 | 0.906 | 0.854 | 0.906 | 0.635 | 0.500 | 0.417 |
| **F1** | **0.951** | 0.910 | 0.936 | 0.896 | 0.906 | 0.722 | 0.600 | 0.552 |

> **Random Forest** wins with AUC = 0.998, and threshold tuning to 0.35 reduces misclassification cost by 25%.

## Repository Structure

```
ASML/
├── report.R                 # Master script — runs the full pipeline
├── R/
│   ├── data_exploration.R   # EDA, cleaning, visualisations
│   ├── models.R             # 8 model definitions + CV training
│   └── evaluation.R         # Test evaluation, plots, cost analysis
├── data/
│   └── bank_personal_loan.csv
├── plots/                   # All generated figures (13 plots)
├── ASML Report/
│   ├── main.tex             # LaTeX master document
│   ├── ExecutiveSummary.tex  # Part 1: non-technical summary
│   └── TechnicalSummary.tex # Part 2: full technical write-up
├── build.py                 # Local PDF compilation script
└── .github/workflows/
    └── build-report.yml     # CI: auto-compile PDF on push
```

## Quick Start

### Run the Analysis

```r
# From the project root in R/RStudio
source("report.R")
```

This will:
1. Install any missing packages automatically
2. Load and clean the dataset
3. Train all 8 models with 10-fold CV (x3 repeats)
4. Generate all 13 plots in `plots/`
5. Print test set metrics and cost analysis
6. Save `workspace.RData` for fast iteration

### Build the Report PDF

```bash
# Requires a LaTeX distribution (MiKTeX, TeX Live, or MacTeX)
python build.py --open
```

## Models

| # | Model | Method | Key Hyperparameters |
|---|-------|--------|-------------------|
| 1 | Decision Tree | `rpart` | `cp` ∈ [0.001, 0.05] |
| 2 | Logistic Regression | `glm` | — |
| 3 | LDA | `lda` | — |
| 4 | Elastic Net | `glmnet` | α ∈ {0, 0.5, 1}, λ ∈ [10⁻⁴, 10⁻¹] |
| 5 | Random Forest | `rf` | `mtry` ∈ {2,3,4,5,6,8}, 500 trees |
| 6 | SVM (RBF) | `svmRadial` | σ ∈ {0.01, 0.05, 0.1}, C ∈ {0.1, 1, 10} |
| 7 | GBM | `gbm` | trees ∈ {100,300,500}, depth ∈ {1,3,5} |
| 8 | Neural Network | `nnet` | size ∈ {5,10,20}, decay ∈ {0.001, 0.01, 0.1} |

## Key Plots

<details>
<summary><b>ROC Curves</b></summary>
<br>
<img src="plots/roc_curves.png" width="600"/>
</details>

<details>
<summary><b>Precision-Recall Curves</b></summary>
<br>
<img src="plots/pr_curves.png" width="600"/>
</details>

<details>
<summary><b>Cross-Validation Comparison</b></summary>
<br>
<img src="plots/cv_comparison.png" width="700"/>
</details>

<details>
<summary><b>Cost Analysis</b></summary>
<br>
<img src="plots/cost_analysis.png" width="600"/>
</details>

<details>
<summary><b>Feature Importance</b></summary>
<br>
<img src="plots/feature_importance.png" width="600"/>
</details>

<details>
<summary><b>Calibration</b></summary>
<br>
<img src="plots/calibration.png" width="600"/>
</details>

## Dependencies

All R packages are installed automatically when running `report.R`. For reference:

```
tidyverse, caret, pROC, glmnet, randomForest, e1071, gbm, MASS, rpart.plot, nnet, ggplot2
```

## Reproducibility

- Fixed seed: `set.seed(42)`
- Shared CV folds across all models via `createMultiFolds`
- Tested on R 4.4.2+

---

<p align="center">
  <sub>Durham University — MISCADA Applied Statistical Modelling and Machine Learning — 2025/26</sub>
</p>
