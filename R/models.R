# ==============================================================================
# R/models.R
# ==============================================================================

# Resolve conflicts for this script
select  <- dplyr::select
filter  <- dplyr::filter
combine <- randomForest::combine

# 1. Train/Test Split (80/20, stratified)
set.seed(42)
trainIndex <- createDataPartition(data$Personal.Loan, p = 0.8, list = FALSE)
train_data <- data[trainIndex, ]
test_data  <- data[-trainIndex, ]

cat("\nTrain set size:", nrow(train_data), "\n")
cat("Test set size:", nrow(test_data), "\n")
cat("Train positive rate:", round(mean(train_data$Personal.Loan == "Yes"), 3), "\n")
cat("Test positive rate:", round(mean(test_data$Personal.Loan == "Yes"), 3), "\n")

# 2. Cross-Validation Setup
# 10-fold repeated CV with shared folds across all models
set.seed(42)
cv_folds <- createMultiFolds(train_data$Personal.Loan, k = 10, times = 3)

cv_control <- trainControl(
  method = "repeatedcv",
  number = 10,
  repeats = 3,
  index = cv_folds,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final"
)

# 3. Model 0: Single Decision Tree (interpretable baseline)
cat("\nTraining Decision Tree...\n")
tree_grid <- expand.grid(cp = seq(0.001, 0.05, length.out = 20))
model_tree <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "rpart",
  trControl = cv_control,
  tuneGrid = tree_grid,
  metric = "ROC"
)

# Save tree plot for the report
png("plots/decision_tree.png", width = 900, height = 600)
rpart.plot::rpart.plot(model_tree$finalModel,
                       main = "Decision Tree: Personal Loan Acceptance",
                       extra = 101, roundint = FALSE,
                       yes.text = "Yes", no.text = "No",
                       box.palette = "BuRd")
dev.off()

# 4. Model 1: Logistic Regression (Baseline)
cat("\nTraining Logistic Regression...\n")
model_log <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "glm",
  family = "binomial",
  trControl = cv_control,
  metric = "ROC"
)

# 5. Model 2: Linear Discriminant Analysis
cat("Training LDA...\n")
model_lda <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "lda",
  trControl = cv_control,
  metric = "ROC"
)

# 6. Model 3: Elastic Net
cat("Training Elastic Net...\n")
enet_grid <- expand.grid(
  alpha = c(0, 0.5, 1),
  lambda = 10^seq(-4, -1, length.out = 20)
)
model_lasso <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "glmnet",
  family = "binomial",
  trControl = cv_control,
  tuneGrid = enet_grid,
  metric = "ROC"
)
cat("Best alpha:", model_lasso$bestTune$alpha,
    " Best lambda:", model_lasso$bestTune$lambda, "\n")

# 7. Model 4: Random Forest
cat("Tuning Random Forest...\n")
rf_grid <- expand.grid(mtry = c(2, 3, 4, 5, 6, 8))
model_rf <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "rf",
  trControl = cv_control,
  tuneGrid = rf_grid,
  metric = "ROC",
  ntree = 500
)

# OOB error rate
cat("RF OOB error rate:", round(model_rf$finalModel$err.rate[500, "OOB"] * 100, 2), "%\n")

# 8. Model 5: SVM (Radial Kernel)
cat("Tuning SVM...\n")
svm_grid <- expand.grid(
  sigma = c(0.01, 0.05, 0.1),
  C = c(0.1, 1, 10)
)
model_svm <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "svmRadial",
  trControl = cv_control,
  tuneGrid = svm_grid,
  metric = "ROC",
  preProcess = c("center", "scale")
)

# 9. Model 6: GBM
cat("Tuning GBM...\n")
gbm_grid <- expand.grid(
  n.trees = c(100, 300, 500),
  interaction.depth = c(1, 3, 5),
  shrinkage = 0.1,
  n.minobsinnode = 10
)
model_gbm <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "gbm",
  trControl = cv_control,
  tuneGrid = gbm_grid,
  metric = "ROC",
  verbose = FALSE
)

# 10. Model 7: Neural Network (nnet)
cat("Tuning Neural Network...\n")
nn_grid <- expand.grid(
  size = c(5, 10, 20),
  decay = c(0.001, 0.01, 0.1)
)
model_nn <- train(
  Personal.Loan ~ .,
  data = train_data,
  method = "nnet",
  trControl = cv_control,
  tuneGrid = nn_grid,
  metric = "ROC",
  preProcess = c("center", "scale"),
  trace = FALSE,
  maxit = 300
)

# 11. Compare CV results
cv_results <- resamples(list(
  Tree         = model_tree,
  Logistic     = model_log,
  LDA          = model_lda,
  ElasticNet   = model_lasso,
  RandomForest = model_rf,
  SVM          = model_svm,
  GBM          = model_gbm,
  NeuralNet    = model_nn
))

cat("\nCross-validation summary:\n")
print(summary(cv_results))

# CV comparison dotplot
cv_summary <- summary(cv_results)
cv_plot_data <- data.frame()

for (metric in c("ROC", "Sens", "Spec")) {
  stats <- cv_summary$statistics[[metric]]
  for (model in rownames(stats)) {
    cv_plot_data <- rbind(cv_plot_data, data.frame(
      Model  = model,
      Metric = metric,
      Median = stats[model, "Median"],
      Q1     = stats[model, "1st Qu."],
      Q3     = stats[model, "3rd Qu."]
    ))
  }
}

cv_plot_data$Metric <- factor(cv_plot_data$Metric,
                              levels = c("ROC", "Sens", "Spec"))

# Pad axes so error bars aren't clipped
cv_plot_data <- cv_plot_data %>%
  group_by(Metric) %>%
  mutate(pad = (max(Q3) - min(Q1)) * 0.15) %>%
  ungroup()

p_cv <- ggplot(cv_plot_data, aes(x = Median, y = reorder(Model, Median))) +
  geom_point(size = 2.5) +
  geom_errorbar(aes(xmin = Q1, xmax = Q3), orientation = "y", width = 0.3) +
  facet_wrap(~ Metric, scales = "free_x") +
  scale_x_continuous(expand = expansion(mult = 0.15)) +
  labs(title = "Model Comparison (Cross-Validation)",
       x = NULL, y = NULL) +
  theme_bw() +
  theme(
    plot.title        = element_text(hjust = 0.5, size = 13),
    panel.border      = element_rect(colour = "black", fill = NA, linewidth = 1.2),
    panel.grid.major  = element_line(colour = "grey85", linewidth = 0.4),
    panel.grid.minor  = element_blank(),
    strip.background  = element_rect(colour = "black", fill = "grey90", linewidth = 1.2),
    strip.text        = element_text(face = "bold", size = 11),
    panel.spacing     = unit(0.8, "lines"),
    axis.ticks        = element_line(colour = "black")
  )
ggsave("plots/cv_comparison.png", plot = p_cv, width = 10, height = 5)
