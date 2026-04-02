library(here)
library(lme4)
library(rlang) # lme4 needs this.
library(dplyr)
library(readr)
library(purrr)
library(tidyr)

dir <- here("output", "final_data")
data <- read_csv(file.path(dir, "final_ds_cs.csv"))

################################################################################
# Turn bail into a binary 0/1 variable.
################################################################################
data_clean <-
    data |>
    mutate(
        bail_decision_bin_nr =
            if_else(bail_decision_bin == "Effectively bail or detained", 1, 0)
    ) |>
    select(
        bail_decision_bin_nr, judge_assigned, main_defense, main_prosecutor,
        matches("dyad|triad")
    )

################################################################################
# Estimate models.
################################################################################
null_model_args <-
    list(
        judge = "(1 | judge_assigned)",
        defense = "(1 | main_defense)",
        prosecutor = "(1 | main_prosecutor)",
        judge_defense = "(1 | judge_assigned) + (1 | main_defense)",
        judge_prosecutor = "(1 | judge_assigned) + (1 | main_prosecutor)",
        defense_prosecutor = "(1 | main_defense) + (1 | main_prosecutor)",
        judge_defense_prosecutor = "(1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor)",
        judge_defense_dyad = "(1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad)",
        judge_prosecutor_dyad = "(1 | judge_assigned) + (1 | main_prosecutor) + (1 | judge_prosecutor_dyad)",
        defense_prosecutor_dyad = "(1 | main_defense) + (1 | main_prosecutor) + (1 | defense_prosecutor_dyad)",
        judge_defense_prosecutor_dyads =
            paste0(
                "(1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor)",
                "+ (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) + (1 | defense_prosecutor_dyad)"
            ),
        judge_defense_prosecutor_triad =
            paste0(
                "(1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor)",
                "+ (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) + (1 | defense_prosecutor_dyad) +",
                "(1 | judge_defense_prosecutor_triad)"
            )
    )

estimate_null_model <- function(grouping_var, df) {
    formula <- paste0("bail_decision_bin_nr~", grouping_var)
    model <- glmer(as.formula(formula), data = df, family = "binomial")
    return(model)
}

models <- map(null_model_args, estimate_null_model, df = data_clean)
saveRDS(models, here("output", "analysis", "model_output"))

################################################################################
# Calculate ICC.
################################################################################
calc_icc <- function(variance, total_variance) {
    sigma2 <- pi ^ 2 / 3
    variance / (sigma2 + total_variance)
}

icc <- function(model, model_name) {
    variances <- VarCorr(model)
    individual_variances <- map(variances, function(variance) {variance[[1]]})
    
    icc_values <-
        map(
            individual_variances,
            calc_icc,
            total_variance = sum(unlist(individual_variances))
        )
    
    icc_df <-
        tibble(
            icc = unname(unlist(icc_values)),
            actor = names(icc_values),
            model = model_name
        )
    
    return(icc_df)
}

icc_df <-
    pmap(list(models, names(models)), icc) |>
    bind_rows() |>
    pivot_wider(id_cols = "model", names_from = "actor", values_from = "icc")

write_csv(icc_df, file.path(dir, "icc_df.csv"))

# Investigate
# Profile Likelihood Confidence Intervals
# a <- confint(models$judge, method = "profile")
# a <- bootMer(mod)

# model_judge <-
#     glmer(
#         bail_decision_bin_nr ~ (1 | judge_assigned),
#         data = data_clean,
#         family = "binomial"
#     )
