library(here)
library(lme4)
library(rlang)
library(readr)
library(dplyr)
read_dir <- here("output", "final_data")
write_dir <- here("output", "analysis", "model_output")
charge_levels <- c("h1", "h2", "f1", "f2", "f3", "f", "m1", "m2", "m3", "m", "s")

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

################################################################################
# Estimate full model,
################################################################################
full_model_max <-
    glmer(
        bail_decision_bin_nr ~
            sex + race_collapsed + main_defense_private + age_scaled +
            I(age_scaled ^ 2) + highest_charge_max + year_cat + county +
            (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +
            (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) +
            (1 | defense_prosecutor_dyad),
        family = "binomial",
        data = data,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )

full_model_min <-
    glmer(
        bail_decision_bin_nr ~
            sex + race_collapsed + main_defense_private + age_scaled +
            I(age_scaled ^ 2) + highest_charge_min + year_cat + county +
            (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +
            (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) +
            (1 | defense_prosecutor_dyad),
        family = "binomial",
        data = data,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )

saveRDS(full_model_max, file.path(write_dir, "full_model_max.rds"))
saveRDS(full_model_min, file.path(write_dir, "full_model_min.rds"))
