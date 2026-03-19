# ==============================================================================
# R/data_exploration.R
# ==============================================================================

# Resolve conflicts for this script
select <- dplyr::select
filter <- dplyr::filter

# 1. Missing value check
cat("\nMissing values per column:\n")
print(colSums(is.na(data)))

# 2. Column Name Alignment & Cleaning
data$Personal.Loan <- factor(
  ifelse(data$Personal.Loan == 1, "Yes", "No"),
  levels = c("No", "Yes")
)

data$Education <- as.factor(data$Education)
data$Securities.Account <- as.factor(data$Securities.Account)
data$CD.Account <- as.factor(data$CD.Account)
data$Online <- as.factor(data$Online)
data$CreditCard <- as.factor(data$CreditCard)

# Drop ZIP.Code (high cardinality, not predictive)
if ("ZIP.Code" %in% names(data)) {
  data <- data %>% select(-ZIP.Code)
}

# Fix negative Experience values (clamp to 0)
if (any(data$Experience < 0)) {
  cat("Fixing", sum(data$Experience < 0), "negative Experience values\n")
  data$Experience <- pmax(data$Experience, 0)
}

# 3. Class distribution summary
cat("\nClass distribution:\n")
print(table(data$Personal.Loan))
cat("\nClass proportions:\n")
print(prop.table(table(data$Personal.Loan)))

# 4. Class balance plot
p_balance <- ggplot(data, aes(x = Personal.Loan, fill = Personal.Loan)) +
  geom_bar() +
  geom_text(stat = "count", aes(label = after_stat(count)), vjust = -0.5) +
  labs(title = "Class Distribution of Personal Loan Acceptance",
       x = "Personal Loan", y = "Count") +
  scale_fill_manual(values = c("No" = "#3498db", "Yes" = "#e74c3c")) +
  theme(legend.position = "none")
ggsave("plots/class_balance.png", plot = p_balance, width = 6, height = 4)

# 5. Loan acceptance by education level
p_edu <- ggplot(data, aes(x = Education, fill = Personal.Loan)) +
  geom_bar(position = "dodge") +
  scale_x_discrete(labels = c("1" = "Undergrad", "2" = "Graduate",
                               "3" = "Professional")) +
  scale_fill_manual(values = c("No" = "#3498db", "Yes" = "#e74c3c")) +
  labs(title = "Loan Acceptance by Education Level",
       x = "Education Level", fill = "Accepted?")
ggsave("plots/education_vs_acceptance.png", plot = p_edu, width = 7, height = 4)

# 6. Income distribution by loan status
p_income <- ggplot(data, aes(x = Income, fill = Personal.Loan)) +
  geom_density(alpha = 0.6) +
  labs(title = "Income Distribution by Loan Acceptance",
       x = "Income (k$)", y = "Density", fill = "Loan") +
  scale_fill_manual(values = c("No" = "#3498db", "Yes" = "#e74c3c"))
ggsave("plots/income_distribution.png", plot = p_income, width = 7, height = 4)

# 7. Multicollinearity check on numeric predictors
numeric_cols <- data %>% select(where(is.numeric))
cor_matrix <- cor(numeric_cols)
cat("\nHigh correlations (|r| > 0.8):\n")
high_cor <- which(abs(cor_matrix) > 0.8 & upper.tri(cor_matrix), arr.ind = TRUE)
if (nrow(high_cor) > 0) {
  for (i in seq_len(nrow(high_cor))) {
    r <- cor_matrix[high_cor[i, 1], high_cor[i, 2]]
    cat("  ", rownames(cor_matrix)[high_cor[i, 1]], "&",
        colnames(cor_matrix)[high_cor[i, 2]], ":", round(r, 3), "\n")
  }
  cat("Note: Age & Experience are near-perfectly correlated.\n")
}

# 8. PCA biplot
pca_data <- data %>% select(where(is.numeric))
pca_fit <- prcomp(pca_data, center = TRUE, scale. = TRUE)

pca_df <- data.frame(
  PC1 = pca_fit$x[, 1],
  PC2 = pca_fit$x[, 2],
  Loan = data$Personal.Loan
)

pve <- summary(pca_fit)$importance[2, 1:2] * 100

p_pca <- ggplot(pca_df, aes(x = PC1, y = PC2, colour = Loan)) +
  geom_point(alpha = 0.4, size = 1) +
  scale_colour_manual(values = c("No" = "#3498db", "Yes" = "#e74c3c")) +
  labs(title = "PCA: First Two Principal Components",
       x = paste0("PC1 (", round(pve[1], 1), "% variance)"),
       y = paste0("PC2 (", round(pve[2], 1), "% variance)"),
       colour = "Loan")
ggsave("plots/pca_biplot.png", plot = p_pca, width = 7, height = 5)

print("Data exploration complete.")
