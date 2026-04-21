library(here)
library(lme4)
library(readr)
library(rlang)
library(dplyr)
library(tidyr)
library(purrr)
read_dir <- here("output", "final_data")
write_dir <- here("output", "analysis", "model_output")

################################################################################
# Read in data.
################################################################################
data <-
    read_csv(file.path(read_dir, "final_analysis_file.csv")) |>
    mutate(
        year_cat =
            case_when(
                year >= 2005 & year <= 2012 ~ "2005-2012",
                year >= 2013 & year <= 2016 ~ "2013-2016",
                year >= 2017 & year <= 2019 ~ "2017-2019",
                year >= 2020 & year <= 2023 ~ "2020-2023"
            ),
        year_cat = relevel(factor(year_cat), ref = "2020-2023"),
        year = relevel(factor(as.character(year)), ref = "2023"),
        county = relevel(factor(county), ref = "allegheny"),
        any_private = relevel(factor(any_private), ref = "FALSE"),
        sex = relevel(factor(sex), ref = "female"),
        race_collapsed = relevel(factor(race_collapsed), ref = "black"),
        mult_defense = relevel(factor(mult_defense), ref = "0"),
        mult_prosecutor = relevel(factor(mult_prosecutor), ref = "0"),
        highest_charge_max =
            case_when(
                highest_charge_max %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_max
            ),
        highest_charge_min =
            case_when(
                highest_charge_min %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_min
            ),
        highest_charge_max = relevel(factor(highest_charge_max), ref = "f1"),
        highest_charge_min = relevel(factor(highest_charge_min), ref = "f1"),
        age_scaled = (age - mean(age)) / sd(age),
        nr_charges_scaled = (nr_charges - mean(nr_charges)) / sd(nr_charges),
        mult_charges = if_else(nr_charges > 1, 1, 0),
        mult_charges = relevel(factor(as.character(mult_charges)), ref = "0"),
        main_defense_private = relevel(factor(as.character(main_defense_private)), ref = "0")
    )

data_private <- data |> filter(main_defense_private == 1)
data_counsel <- data |> filter(counsel == "no")
data_request <- data |> filter(defender_requested == "no")
data_app <- data |> filter(application_provided == "no")
data_all <- data |> filter(main_defense_private == 1 & counsel == "no" & defender_requested == "no" & application_provided == "no")

################################################################################
# Estimate full model on each data frame.
################################################################################
estimate_model_max <- function(df, model_name) {
    formula_str <-
        paste0(
            "bail_decision_bin_nr ~ ",
            "sex + race_collapsed + age_scaled + I(age_scaled ^ 2) + ",
            "highest_charge_max + year_cat + county + (1 | judge_assigned) + ",
            "(1 | main_defense) + (1 | main_prosecutor) + (1 | judge_defense_dyad) + ",
            "(1 | judge_prosecutor_dyad) + (1 | defense_prosecutor_dyad)"
        )
    
    if(!(model_name %in% c("private", "all"))) {
        formula_str <- paste0(formula_str, " + main_defense_private")
    }
    
    glmer(
        as.formula(formula_str),
        family = "binomial",
        data = df,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )
}

estimate_model_min <- function(df, model_name) {
    formula_str <-
        paste0(
            "bail_decision_bin_nr ~ ",
            "sex + race_collapsed + age_scaled + I(age_scaled ^ 2) + ",
            "highest_charge_min + year_cat + county + (1 | judge_assigned) + ",
            "(1 | main_defense) + (1 | main_prosecutor) + (1 | judge_defense_dyad) + ",
            "(1 | judge_prosecutor_dyad) + (1 | defense_prosecutor_dyad)"
        )
    
    if(!(model_name %in% c("private", "all"))) {
        formula_str <- paste0(formula_str, " + main_defense_private")
    }
    
    glmer(
        as.formula(formula_str),
        family = "binomial",
        data = df,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )
}

data_frames <-
    list(
        "private" = data_private, "app" = data_app, "counsel" = data_counsel,
        "request" = data_request, "all" = data_all
    )

models_max <- pmap(list(data_frames, names(data_frames)), estimate_model_max)
models_min <- pmap(list(data_frames, names(data_frames)), estimate_model_min)

saveRDS(models_max, file.path(write_dir, "private_models_max.rds"))
saveRDS(models_min, file.path(write_dir, "private_models_min.rds"))
