library(here)
library(lme4)
library(rlang)
library(purrr)
library(dplyr)
library(tidyr)
library(flextable)
library(broom.mixed)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")

################################################################################
# Read in models.
################################################################################
private_models_max <- readRDS(file.path(read_dir, "private_models_max.rds"))
private_models_min <- readRDS(file.path(read_dir, "private_models_min.rds"))

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
            icc = unname(unlist(icc_values)),
            actor = names(icc_values),
            model = model_name
        )
    
    return(icc_df)
}

icc_table_max <-
    pmap(
        list(private_models_max, names(private_models_max)),
        my_icc_unadjusted
    ) |>
    bind_rows() |>
    pivot_wider(id_cols = "actor", names_from = "model", values_from = "icc")

icc_table_min <-
    pmap(
        list(private_models_min, names(private_models_min)),
        my_icc_unadjusted
    ) |>
    bind_rows() |>
    pivot_wider(id_cols = "actor", names_from = "model", values_from = "icc")

################################################################################
# Create flex table.
################################################################################
icc_table <-
    icc_table_max |>
    mutate(
        actor =
            case_when(
                actor == "defense_prosecutor_dyad" ~ "Defense + Prosecutor",
                actor == "judge_prosecutor_dyad" ~ "Judge + Prosecutor",
                actor == "judge_defense_dyad" ~ "Judge + Defense",
                actor == "main_prosecutor" ~ "Prosecutor",
                actor == "main_defense" ~ "Defense Attorney",
                actor == "judge_assigned" ~ "Judge"
            ),
        across(-actor, function(col) {signif(col, 3)}),
        actor =
            factor(
                actor,
                levels =
                    c(
                        "Judge", "Defense Attorney", "Prosecutor", "Judge + Defense",
                        "Judge + Prosecutor", "Defense + Prosecutor"
                    )
            )
    ) |>
    rename(
        Actor = actor,
        "Private defenders only" = private,
        "Application not provided for a public defender" = app,
        "Defendant not advised of their right to counsel" = counsel,
        "Defendant requested public defender" = request,
        "All conditions" = all
    ) |>
    arrange(Actor)

icc_flextable <-
    icc_table |>
    flextable() |>
    fontsize(size = 8, part = "all") |>
    width(c(1,2,3,4,5,6), c(0.75, 1, 1.75, 1.5, 1.5, 0.75)) |>
    set_table_properties(layout = "fixed")

save_as_docx(icc_flextable, path = file.path(write_dir, "private_icc_table.docx"))
