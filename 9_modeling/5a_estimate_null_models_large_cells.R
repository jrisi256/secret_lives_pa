library(here)
library(lme4)
library(rlang)
library(readr)
library(purrr)
library(tidyr)
library(dplyr)

################################################################################
# Read in data.
################################################################################
read_dir <- here("output", "final_data")
defense_top90 <- read_csv(file.path(read_dir, "top90prcnt_cases_defense.csv"))
defense_top50 <- read_csv(file.path(read_dir, "top50prcnt_cases_defense.csv"))
prosecutor_top90 <- read_csv(file.path(read_dir, "top90prcnt_cases_prosecutor.csv"))
prosecutor_top50 <- read_csv(file.path(read_dir, "top50prcnt_cases_prosecutor.csv"))
triad_top50 <- read_csv(file.path(read_dir, "top50prcnt_cases_triads.csv"))

################################################################################
# Estimate models.
################################################################################
estimate_defense_model <- function(df) {
    formula <- "bail_decision_bin_nr ~ (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad)"
    model <- glmer(as.formula(formula), data = df, family = "binomial")
    return(model)
}

estimate_prosecutor_model <- function(df) {
    formula <- "bail_decision_bin_nr ~ (1 | judge_assigned) + (1 | main_prosecutor) + (1 | judge_prosecutor_dyad)"
    model <- glmer(as.formula(formula), data = df, family = "binomial")
    return(model)
}

estimate_triad_model <- function(df) {
    formula <-
        paste0(
            "bail_decision_bin_nr ~ (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +",
            "(1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) + (1 | defense_prosecutor_dyad)"
        )
    model <- glmer(as.formula(formula), data = df, family = "binomial")
    return(model)
}

defense_models <-
    map(
        list("defense_top90" = defense_top90, "defense_top50" = defense_top50),
        estimate_defense_model
    )

prosecutor_models <-
    map(
        list("prosecutor_top90" = prosecutor_top90, "prosecutor_top50" = prosecutor_top50),
        estimate_prosecutor_model
    )

triad_model <- estimate_triad_model(triad_top50)

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

all_models <- c(defense_models, prosecutor_models, "dyad_model" = triad_model)

icc_df <-
    pmap(list(all_models, names(all_models)), icc) |>
    bind_rows() |>
    pivot_wider(id_cols = "model", names_from = "actor", values_from = "icc")

write_dir <- here("output", "analysis", "model_output")
write_csv(icc_df, file.path(write_dir, "icc_df_large_cells.csv"))
