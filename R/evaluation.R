# ==============================================================================
# R/evaluation.R
# ==============================================================================

# Resolve conflicts for this script
select <- dplyr::select
filter <- dplyr::filter
mutate <- dplyr::mutate

# 1. Evaluate all models on the held-out test set
models <- list(
  Tree         = model_tree,
  Logistic     = model_log,
  LDA          = model_lda,
  ElasticNet   = model_lasso,
  RandomForest = model_rf,
  SVM          = model_svm,
  GBM          = model_gbm,
  NeuralNet    = model_nn
)

results <- data.frame()

for (name in names(models)) {
  pred_class <- predict(models[[name]], test_data)
  pred_prob  <- predict(models[[name]], test_data, type = "prob")
  cm <- confusionMatrix(pred_class, test_data$Personal.Loan, positive = "Yes")
  roc_val <- roc(test_data$Personal.Loan, pred_prob$Yes,
                 levels = c("No", "Yes"), quiet = TRUE)

  results <- rbind(results, data.frame(
    Model       = name,
    AUC         = round(auc(roc_val), 4),
    Accuracy    = round(cm$overall["Accuracy"], 4),
    Sensitivity = round(cm$byClass["Sensitivity"], 4),
    Specificity = round(cm$byClass["Specificity"], 4),
    Precision   = round(cm$byClass["Pos Pred Value"], 4),
    F1          = round(cm$byClass["F1"], 4)
  ))
}

rownames(results) <- NULL
cat("\n========== Test Set Performance Comparison ==========\n")
print(results)

# 2. Select best model by AUC
best_name  <- results$Model[which.max(results$AUC)]
best_model <- models[[best_name]]
cat("\nBest model by AUC:", best_name, "\n")

# 3. Final model confusion matrix
final_pred_class <- predict(best_model, test_data)
final_pred_prob  <- predict(best_model, test_data, type = "prob")

conf_matrix <- confusionMatrix(final_pred_class, test_data$Personal.Loan,
                               positive = "Yes")
cat("\nFinal Model Confusion Matrix:\n")
print(conf_matrix)

# 4. ROC Curves for all models
colours <- c("#95a5a6", "#e74c3c", "#f39c12", "#3498db", "#2ecc71", "#9b59b6", "#e67e22", "#1abc9c")
roc_plot_data <- data.frame()

for (i in seq_along(models)) {
  name <- names(models)[i]
  pred_prob <- predict(models[[name]], test_data, type = "prob")
  roc_val <- roc(test_data$Personal.Loan, pred_prob$Yes,
                 levels = c("No", "Yes"), quiet = TRUE)
  roc_df <- data.frame(
    FPR   = 1 - roc_val$specificities,
    TPR   = roc_val$sensitivities,
    Model = paste0(name, " (AUC=", round(auc(roc_val), 3), ")")
  )
  roc_plot_data <- rbind(roc_plot_data, roc_df)
}

p_roc <- ggplot(roc_plot_data, aes(x = FPR, y = TPR, colour = Model)) +
  geom_line(linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  labs(title = "ROC Curves: All Models",
       x = "1 - Specificity", y = "Sensitivity") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  scale_colour_manual(values = setNames(colours, unique(roc_plot_data$Model)))
ggsave("plots/roc_curves.png", plot = p_roc, width = 7, height = 5)

# 5. Precision-Recall Curves
pr_data <- data.frame()

for (name in names(models)) {
  pred_prob <- predict(models[[name]], test_data, type = "prob")
  thrs <- sort(unique(c(0, pred_prob$Yes, 1)), decreasing = TRUE)

  for (t in thrs) {
    pred_t <- factor(ifelse(pred_prob$Yes >= t, "Yes", "No"),
                     levels = c("No", "Yes"))
    tp <- sum(pred_t == "Yes" & test_data$Personal.Loan == "Yes")
    fp <- sum(pred_t == "Yes" & test_data$Personal.Loan == "No")
    fn <- sum(pred_t == "No"  & test_data$Personal.Loan == "Yes")
    prec <- ifelse(tp + fp > 0, tp / (tp + fp), NA)
    rec  <- tp / (tp + fn)
    pr_data <- rbind(pr_data, data.frame(
      Model = name, Precision = prec, Recall = rec
    ))
  }
}

p_pr <- ggplot(pr_data %>% filter(!is.na(Precision)),
               aes(x = Recall, y = Precision, colour = Model)) +
  geom_line(linewidth = 0.8) +
  labs(title = "Precision-Recall Curves: All Models",
       x = "Recall (Sensitivity)", y = "Precision") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  scale_colour_manual(values = colours)
ggsave("plots/pr_curves.png", plot = p_pr, width = 7, height = 5)

# 6. Feature Importance (Random Forest)
cat("\nRandom Forest Variable Importance:\n")
rf_imp <- varImp(model_rf)
print(rf_imp)

imp_df <- data.frame(
  Variable   = rownames(rf_imp$importance),
  Importance = rf_imp$importance$Overall
)
imp_df <- imp_df[order(imp_df$Importance), ]
imp_df$Variable <- factor(imp_df$Variable, levels = imp_df$Variable)

p_imp <- ggplot(imp_df, aes(x = Variable, y = Importance)) +
  geom_col(fill = "#2c3e50") +
  coord_flip() +
  labs(title = "Random Forest: Variable Importance",
       x = NULL, y = "Importance")
ggsave("plots/feature_importance.png", plot = p_imp, width = 7, height = 5)

# 6b. Calibration Plot + Brier Score
cal_data <- data.frame(
  obs       = as.numeric(test_data$Personal.Loan == "Yes"),
  pred_prob = final_pred_prob$Yes
)

# Brier score
brier_score <- mean((cal_data$pred_prob - cal_data$obs)^2)
cat("Brier Score:", round(brier_score, 4), "\n")

# 10 equal-width bins; mid-range bins are sparse because RF
# probabilities cluster near 0 and 1
cal_data$bin <- cut(cal_data$pred_prob, breaks = seq(0, 1, by = 0.1),
                    include.lowest = TRUE, labels = FALSE)

cal_summary <- cal_data %>%
  group_by(bin) %>%
  summarise(
    mean_pred = mean(pred_prob),
    mean_obs  = mean(obs),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(n >= 3)

p_cal <- ggplot(cal_summary, aes(x = mean_pred, y = mean_obs)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey50") +
  geom_line(colour = "#2c3e50", linewidth = 0.5) +
  geom_point(aes(size = n), colour = "#2c3e50") +
  labs(title = paste("Calibration Plot:", best_name),
       x = "Mean Predicted Probability",
       y = "Observed Proportion",
       size = "Bin Count") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1))
ggsave("plots/calibration.png", plot = p_cal, width = 6, height = 5)

# 7. Threshold Analysis
cat("\n========== Threshold Analysis ==========\n")

thresholds <- seq(0.1, 0.9, by = 0.05)
threshold_results <- data.frame()

for (t in thresholds) {
  pred_t <- factor(ifelse(final_pred_prob$Yes >= t, "Yes", "No"),
                   levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred_t, test_data$Personal.Loan, positive = "Yes")

  threshold_results <- rbind(threshold_results, data.frame(
    Threshold   = t,
    Sensitivity = cm_t$byClass["Sensitivity"],
    Specificity = cm_t$byClass["Specificity"],
    Precision   = cm_t$byClass["Pos Pred Value"],
    F1          = cm_t$byClass["F1"]
  ))
}

rownames(threshold_results) <- NULL

threshold_long <- threshold_results %>%
  pivot_longer(cols = -Threshold, names_to = "Metric", values_to = "Value") %>%
  filter(!is.na(Value))

p_threshold <- ggplot(threshold_long,
                      aes(x = Threshold, y = Value, colour = Metric)) +
  geom_line(linewidth = 1) +
  labs(title = "Threshold Tuning: Sensitivity / Specificity Trade-off",
       x = "Classification Threshold", y = "Value") +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey50")
ggsave("plots/threshold_analysis.png", plot = p_threshold, width = 8, height = 5)

# 8. Cost-Benefit Analysis
# FN = £1000 (lost net interest on ~£10k loan, ~2.5% margin, 4yr)
# FP = £300  (compliance + marketing + ops)
FN_cost <- 1000
FP_cost <- 300

cost_results <- data.frame()

for (t in thresholds) {
  pred_t <- factor(ifelse(final_pred_prob$Yes >= t, "Yes", "No"),
                   levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred_t, test_data$Personal.Loan, positive = "Yes")
  fn <- cm_t$table["No", "Yes"]
  fp <- cm_t$table["Yes", "No"]
  total_cost <- fn * FN_cost + fp * FP_cost

  cost_results <- rbind(cost_results, data.frame(
    Threshold  = t,
    FN         = fn,
    FP         = fp,
    Total_Cost = total_cost
  ))
}

optimal_threshold <- cost_results$Threshold[which.min(cost_results$Total_Cost)]
cat("Optimal threshold (minimising cost):", optimal_threshold, "\n")
cat("Cost at default 0.5 :", cost_results$Total_Cost[cost_results$Threshold == 0.5], "\n")
cat("Cost at optimal     :", min(cost_results$Total_Cost), "\n")

p_cost <- ggplot(cost_results, aes(x = Threshold, y = Total_Cost)) +
  geom_line(colour = "#e74c3c", linewidth = 1) +
  geom_vline(xintercept = optimal_threshold,
             linetype = "dashed", colour = "#2ecc71") +
  geom_vline(xintercept = 0.5, linetype = "dotted", colour = "grey50") +
  annotate("text", x = optimal_threshold + 0.05,
           y = max(cost_results$Total_Cost) * 0.9,
           label = paste("Optimal =", optimal_threshold), colour = "#2ecc71") +
  labs(title = "Cost Analysis by Classification Threshold",
       x = "Classification Threshold", y = "Total Cost (\u00a3)")
ggsave("plots/cost_analysis.png", plot = p_cost, width = 7, height = 5)

# 9. Performance at optimal threshold vs default
cat("\n========== Performance at Optimal Threshold ==========\n")
pred_optimal <- factor(ifelse(final_pred_prob$Yes >= optimal_threshold, "Yes", "No"),
                       levels = c("No", "Yes"))
cm_optimal <- confusionMatrix(pred_optimal, test_data$Personal.Loan, positive = "Yes")

cat("Default threshold (0.5):\n")
cat("  Sensitivity:", conf_matrix$byClass["Sensitivity"], "\n")
cat("  Specificity:", conf_matrix$byClass["Specificity"], "\n")
cat("  F1:         ", conf_matrix$byClass["F1"], "\n")
cat("\nOptimal threshold (", optimal_threshold, "):\n", sep = "")
cat("  Sensitivity:", cm_optimal$byClass["Sensitivity"], "\n")
cat("  Specificity:", cm_optimal$byClass["Specificity"], "\n")
cat("  F1:         ", cm_optimal$byClass["F1"], "\n")

# 10. Learning Curve
cat("\n========== Learning Curve ==========\n")
set.seed(42)
train_fractions <- seq(0.1, 1.0, by = 0.1)
lc_results <- data.frame()

for (frac in train_fractions) {
  idx <- createDataPartition(train_data$Personal.Loan, p = frac, list = FALSE)
  sub_train <- train_data[idx, ]

  lc_control <- trainControl(
    method = "cv", number = 5,
    classProbs = TRUE,
    summaryFunction = twoClassSummary
  )

  lc_model <- train(
    Personal.Loan ~ ., data = sub_train,
    method = "rf", trControl = lc_control,
    tuneGrid = data.frame(mtry = model_rf$bestTune$mtry),
    metric = "ROC", ntree = 200
  )

  # CV performance (train estimate)
  cv_auc <- max(lc_model$results$ROC)

  # Test performance
  lc_prob <- predict(lc_model, test_data, type = "prob")
  lc_roc <- roc(test_data$Personal.Loan, lc_prob$Yes,
                levels = c("No", "Yes"), quiet = TRUE)

  lc_results <- rbind(lc_results, data.frame(
    TrainSize = nrow(sub_train),
    CV_AUC    = cv_auc,
    Test_AUC  = as.numeric(auc(lc_roc))
  ))
}

lc_long <- lc_results %>%
  pivot_longer(cols = c(CV_AUC, Test_AUC),
               names_to = "Set", values_to = "AUC") %>%
  mutate(Set = ifelse(Set == "CV_AUC", "CV (Train)", "Test"))

p_lc <- ggplot(lc_long, aes(x = TrainSize, y = AUC, colour = Set)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(title = "Learning Curve: Random Forest",
       x = "Training Set Size", y = "AUC", colour = "") +
  coord_cartesian(ylim = c(0.9, 1.0))
ggsave("plots/learning_curve.png", plot = p_lc, width = 7, height = 5)

cat("\n========== Evaluation Complete ==========\n")
