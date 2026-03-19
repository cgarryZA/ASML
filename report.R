############################################################
# MISCADA ASML: Classification Summative Coursework
# Personal Loan Acceptance Prediction
# Student Number: Z0160680
# Reproducible Coursework Script
############################################################

# Clear work space
rm(list = ls())

# Fix random seed for reproducibility
set.seed(42)

# Required packages
packages <- c(
  "tidyverse",
  "caret",
  "pROC",
  "glmnet",
  "randomForest",
  "e1071",
  "gbm",
  "MASS",
  "rpart.plot",
  "nnet",
  "ggplot2"
)

# Install missing packages automatically
installed <- packages %in% installed.packages()[,"Package"]

if (any(!installed)) {
  install.packages(packages[!installed])
}

# Load packages
lapply(packages, library, character.only = TRUE)

# Global ggplot theme
theme_set(theme_minimal())
theme_update(plot.title = element_text(hjust = 0.5))

############################################################
# Load Data
############################################################

data <- read.csv("data/bank_personal_loan.csv")

# Inspect structure
str(data)
summary(data)

############################################################
# Data Exploration
############################################################

source("R/data_exploration.R")

############################################################
# Model Training
############################################################

source("R/models.R")

############################################################
# Model Evaluation
############################################################

source("R/evaluation.R")

############################################################
# Save workspace so we can reload and re-run plots
# without re-training all models
#   load("workspace.RData")
#   source("R/evaluation.R")
############################################################

save.image("workspace.RData")
