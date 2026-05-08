library(here)
library(lme4)
library(rlang)
library(tidyr)
library(dplyr)
library(purrr)
library(flextable)
library(broom.mixed)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")

################################################################################
# Load data.
################################################################################
null_defense <- readRDS(file.path(read_dir, "null_defense_model_missing.rds"))
null_prosecutor <- readRDS(file.path(read_dir, "null_prosecutor_model_missing.rds"))
null_defense_top50prcnt <- readRDS(file.path(read_dir, "null_defense_model_missing_top50prcnt.rds"))
full_defense_max <- readRDS(file.path(read_dir, "full_defense_model_missing_max.rds"))
full_defense_min <- readRDS(file.path(read_dir, "full_defense_model_missing_min.rds"))

################################################################################
# Calculate ICC for null models.
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
            icc = unname(unlist(icc_values)),
            actor = names(icc_values),
            model = model_name
        )
    
    return(icc_df)
}

null_icc_df <-
    pmap(
        list(
            list(null_defense, null_defense_top50prcnt, null_prosecutor),
            list(
                "Judge + Defense only (prosecutor missing)",
                "Judge + Defense only - Top 50% of cases (prosecutor missing)",
                "Judge + Prosecutor only (defense missing)"
            )
        ),
        my_icc_adjusted
    ) |>
    bind_rows() |>
    pivot_wider(id_cols = "model", names_from = "actor", values_from = "icc") |>
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
        "Judge + Prosecutor Dyad" = "judge_prosecutor_dyad"
    ) |>
    mutate(
        across(where(is.numeric), function(col) {as.character(signif(col, 4))}),
        across(everything(), function(col) {if_else(is.na(col), "-", col)})
    )

null_icc_flextable <-
    null_icc_df |>
    flextable() |>
    width(j = c(1, 2, 3, 4, 5, 6), width = c(1.25, 1.25, 1.25, 1.25, 1.25, 1.25)) |>
    set_table_properties(layout = "fixed")

save_as_docx(
    null_icc_flextable,
    path = file.path(write_dir, "missing_null_icc_table.docx")
)

################################################################################
# Calculate ICC for full models.
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

icc_values_max <- my_icc_unadjusted(full_defense_max, "Judge + Defense Model (Max)_Estimate")
icc_values_min <- my_icc_unadjusted(full_defense_min, "Judge + Defense Model (Min)_Estimate")

tidy_results_max <-
    tidy(full_defense_max) |>
    mutate(model = "Judge + Defense Model (Max)_Estimate") |>
    bind_rows(icc_values_max)

tidy_results_min <-
    tidy(full_defense_min) |>
    mutate(model = "Judge + Defense Model (Min)_Estimate") |>
    bind_rows(icc_values_min)

tidy_results <-
    bind_rows(tidy_results_max, tidy_results_min) |>
    rename(actor = group) |>
    mutate(
        group = if_else(is.na(actor), "Fixed effects", "Random effects"),
        significance =
            case_when(
                p.value > 0.1 | is.na(p.value) ~ "",
                p.value <= 0.1 & p.value > 0.05 ~ "+",
                p.value <= 0.05 & p.value > 0.01 ~ "*",
                p.value <= 0.01 & p.value > 0.001 ~ "**",
                p.value <= 0.001 ~ "***",
            ),
        term =
            case_when(
                term == "(Intercept)" ~ "Intercept",
                term == "sexmale" ~ "Male",
                term == "race_collapsedOther" ~ "Race - Other",
                term == "race_collapsedwhite" ~ "Race - White",
                term == "main_defense_private1" ~ "Private Defense",
                term == "age_scaled" ~ "Age (Standardized)",
                term == "I(age_scaled^2)" ~ "Age Squared (Standardized)",
                term %in% c("highest_charge_maxf", "highest_charge_minf") ~ "Felony (General)",
                term %in% c("highest_charge_maxf2", "highest_charge_minf2") ~ "2nd degree felony",
                term %in% c("highest_charge_maxf3", "highest_charge_minf3") ~ "3rd degree felony",
                term %in% c("highest_charge_maxm", "highest_charge_minm") ~ "Misdemeanor (General)",
                term %in% c("highest_charge_maxm1", "highest_charge_minm1") ~ "1st degree Misdemeanor",
                term %in% c("highest_charge_maxm2", "highest_charge_minm2") ~ "2nd degree Misdemeanor",
                term %in% c("highest_charge_maxm3", "highest_charge_minm3") ~ "3rd degree Misdemeanor",
                term %in% c("highest_charge_maxs", "highest_charge_mins") ~ "Summary offense",
                term == "year_cat2005-2012" ~ "2005 - 2012",
                term == "year_cat2013-2016" ~ "2013 - 2016",
                term == "year_cat2017-2019" ~ "2017 - 2019",
                term == "countyblair" ~ "Blair County",
                term == "countycentre" ~ "Centre County",
                term == "countydauphin" ~ "Dauphin County",
                term == "countyerie" ~ "Erie County",
                term == "countymontgomery" ~ "Montgomery County",
                term == "sd__(Intercept)" ~ "Std. Dev.",
                T ~ term
            ),
        actor =
            case_when(
                actor == "judge_defense_dyad" ~ "Judge + Defense",
                actor == "main_defense" ~ "Defense",
                actor == "judge_assigned" ~ "Judge"
            ),
        actor =
            factor(
                actor,
                levels = c("Judge", "Defense", "Prosecutor", "Judge + Defense")
            ),
        actor_display = if_else(term == "Std. Dev.", actor, NA),
        estimate =
            paste0(sprintf("%.3f", signif(estimate, 3)), significance),
        group =
            case_when(
                group == "Fixed effects" ~ group,
                group == "Random effects" & actor == "Judge" & term == "Std. Dev." ~ "Random effects",
                T ~ NA
            )
    ) |>
    select(-effect, -p.value, -std.error, -statistic, -significance) |>
    pivot_wider(
        id_cols = c("group", "actor", "actor_display", "term"),
        names_from = "model",
        values_from = "estimate"
    ) |>
    arrange(group, actor) |>
    select(-actor)

model_flextable <-
    tidy_results |>
    as_grouped_data(groups = c("group", "actor_display")) |>
    filter(!is.na(term) | !is.na(group) | !is.na(actor_display)) |>
    as_flextable() |>
    separate_header() |>
    compose(j = 1, i = ~ !is.na(group), value = as_paragraph(as_chunk(group))) |>
    bold(j = 1, i = ~ !is.na(group), bold = T, part = "body") |>
    compose(j = 1, i = ~ !is.na(actor_display), value = as_paragraph(as_chunk(actor_display))) |>
    padding(j = 1, i = ~ !is.na(actor_display), padding.left = 20, part = "body") |>
    italic(j = 1, i = ~ !is.na(actor_display), italic = TRUE, part = "body") |>
    padding(j = 1, i = ~ !is.na(term), padding.left = 40, part = "body") |>
    fontsize(size = 8, part = "all") |>
    width(j = c(1, 2, 3), width = c(2.5, 1, 1)) |>
    set_table_properties(layout = "fixed")

save_as_docx(
    model_flextable,
    path = file.path(write_dir, "missing_full_model_judge_defense_noPros.docx")
)
