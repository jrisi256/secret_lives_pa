library(here)
library(lme4)
library(rlang)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)
library(flextable)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")

################################################################################
# Read in models.
################################################################################
all_full_max <- readRDS(file.path(read_dir, "sig_all_full_models_max.rds"))
all_full_min <- readRDS(file.path(read_dir, "sig_all_full_models_min.rds"))
all_null <- readRDS(file.path(read_dir, "sig_all_null_models.rds"))
defense_null <- readRDS(file.path(read_dir, "sig_defense_null_models.rds"))
prosecutor_null <- readRDS(file.path(read_dir, "sig_prosecutor_null_models.rds"))

################################################################################
# Calculate adjusted ICC values.
################################################################################
calc_icc_adjusted <- function(variance, total_variance) {
    sigma2 <- pi ^ 2 / 3
    variance / (sigma2 + total_variance)
}

my_icc_adjusted <- function(model, model_name) {
    variances <- VarCorr(model)
    individual_variances <- map(variances, function(variance) {variance[[1]]})
    
    icc_values <-
        map(
            individual_variances,
            calc_icc_adjusted,
            total_variance = sum(unlist(individual_variances))
        )
    
    icc_df <-
        tibble(
            estimate = unname(unlist(icc_values)),
            group = names(icc_values),
            term = "ICC - Unadjusted",
            model = model_name
        )
    
    return(icc_df)
}

null_models <- c(defense_null, prosecutor_null, all_null)

null_icc_tables <-
    pmap(list(null_models, names(null_models)), my_icc_adjusted) |>
    bind_rows()

################################################################################
# Calculate un-adjusted ICC values.
################################################################################
calc_icc_unadjusted <- function(variance, total_variance, fixed_variance) {
    sigma2 <- pi ^ 2 / 3
    variance / (sigma2 + total_variance + fixed_variance)
}

my_icc_unadjusted <- function(model, model_name) {
    variances <- VarCorr(model)
    individual_variances <- map(variances, function(variance) {variance[[1]]})
    fixed_var <- var(predict(model, re.form = NA))
    
    icc_values <-
        map(
            individual_variances,
            calc_icc_unadjusted,
            total_variance = sum(unlist(individual_variances)),
            fixed_variance = fixed_var
        )
    
    icc_df <-
        tibble(
            estimate = unname(unlist(icc_values)),
            group = names(icc_values),
            term = "ICC - Unadjusted",
            model = model_name
        )
    
    return(icc_df)
}

names(all_full_max) <- paste0(names(all_full_max), "_max")
names(all_full_min) <- paste0(names(all_full_min), "_min")

full_models <- c(all_full_max, all_full_min)

full_icc_tables <-
    pmap(list(full_models, names(full_models)), my_icc_unadjusted) |>
    bind_rows()

################################################################################
# Tidy up results.
################################################################################
tidy_icc_tables <-
    bind_rows(full_icc_tables, null_icc_tables) |>
    filter(!str_detect(model, "min")) |>
    pivot_wider(
        id_cols = "model", names_from = "group", values_from = "estimate"
    ) |>
    relocate(
        judge_assigned, main_defense, main_prosecutor, judge_defense_dyad,
        judge_prosecutor_dyad, .after = model
    ) |>
    rename(
        "Model" = "model",
        "Judge" = "judge_assigned",
        "Defense" = "main_defense",
        "Prosecutor" = "main_prosecutor",
        "Judge + Defense Dyad" = "judge_defense_dyad",
        "Judge + Prosecutor Dyad" = "judge_prosecutor_dyad",
        "Defense + Prosecutor Dyad" = "defense_prosecutor_dyad"
    ) |>
    mutate(
        across(
            where(is.numeric),
            function(col) {
                if_else(!is.na(col), sprintf("%.3f", signif(col, 3)), "-")
            }
        ),
        Model =
            case_when(
                Model == "null_sig_defense" ~ "Significant defense (1 model)",
                Model == "null_sig_super_defense" ~ "Significant defense (2 models)",
                Model == "null_sig_defense_judge" ~ "Significant defense + judge (1 model)",
                Model == "null_sig_super_defense_judge" ~ "Significant defense + judge (2 models)",
                Model == "null_sig_prosecutor" ~ "Significant prosecutor (1 model)",
                Model == "null_sig_super_prosecutor" ~ "Significant prosecutor (2 models)",
                Model == "null_sig_prosecutor_judge" ~ "Significant prosecutor + judge (1 model)",
                Model == "null_sig_super_prosecutor_judge" ~ "Significant prosecutor + judge (2 models)",
                Model == "null_sig_defense_prosecutor" ~ "Significant defense + prosecutor (1 model)",
                Model == "null_sig_super_defense_prosecutor" ~ "Significant defense + prosecutor (2 models)",
                Model == "null_sig_defense_prosecutor_judge" ~ "Significant defense + prosecutor + judge (1 model)",
                Model == "full_sig_defense_prosecutor_max" ~ "Full model - Significant defense + prosecutor (1 model)",
                Model == "full_sig_super_defense_prosecutor_max" ~ "Full model - Significant defense + prosecutor (2 models)",
                Model == "full_sig_defense_prosecutor_judge_max" ~ "Full model - Significant defense + prosecutor + judge (1 model)"
            ),
        Model =
            factor(
                Model,
                levels =
                    c(
                        "Significant defense (1 model)",
                        "Significant defense (2 models)",
                        "Significant defense + judge (1 model)",
                        "Significant defense + judge (2 models)",
                        "Significant prosecutor (1 model)",
                        "Significant prosecutor (2 models)",
                        "Significant prosecutor + judge (1 model)",
                        "Significant prosecutor + judge (2 models)",
                        "Significant defense + prosecutor (1 model)",
                        "Significant defense + prosecutor (2 models)",
                        "Significant defense + prosecutor + judge (1 model)",
                        "Full model - Significant defense + prosecutor (1 model)",
                        "Full model - Significant defense + prosecutor (2 models)",
                        "Full model - Significant defense + prosecutor + judge (1 model)"
                    )
            ),
        group =
            case_when(
                Model == "Significant defense (1 model)" ~ "Panel A: Defense + Judge (Null)",
                Model == "Significant prosecutor (1 model)" ~ "Panel B: Prosecutor + Judge (Null)",
                Model == "Significant defense + prosecutor (1 model)" ~ "Panel C: Defense + Prosecutor + Judge (Null)",
                Model == "Full model - Significant defense + prosecutor (1 model)" ~ "Panel D: Defense + Prosecutor + Judge (Full)",
            )
    ) |>
    arrange(Model) |>
    mutate(Model = str_replace_all(Model, "Full model - ", ""))

icc_flextable <-
    tidy_icc_tables |>
    as_grouped_data(groups = "group") |>
    filter(!is.na(Model) | !is.na(group)) |>
    as_flextable() |>
    compose(j = 1, i = ~ !is.na(group), value = as_paragraph(as_chunk(group))) |>
    bold(j = 1, i = ~ !is.na(group), bold = T, part = "body") |>
    width(j = c(1, 4, 6, 7), width = c(2.75, 0.9, 0.9, 0.9)) |>
    fontsize(size = 10, part = "all") |>
    set_table_properties(layout = "fixed")

save_as_docx(icc_flextable, path = file.path(write_dir, "sig_icc_table.docx"))
