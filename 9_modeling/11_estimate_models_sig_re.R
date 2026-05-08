library(here)
library(lme4)
library(readr)
library(dplyr)
library(rlang)
library(purrr)
library(stringr)
write_dir <- here("output", "analysis", "model_output")

################################################################################
# Read in data.
################################################################################
random_effects <- read_csv(here("output", "analysis", "model_output", "random_effects.csv"))
sig_rand_effects <- random_effects |> filter((ci_lower < 0 & ci_upper < 0) | (ci_lower > 0 & ci_upper > 0))

################################################################################
# Clean data.
################################################################################
data <-
    read_csv(here("output", "final_data", "final_analysis_file.csv")) |>
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

unique_judges <- paste(data$judge_assigned, collapse = "|")

################################################################################
# Find statistically significant actors.
################################################################################
prosecutor <-
    sig_rand_effects |>
    filter(group == "main_prosecutor") |>
    mutate(prosecutor_str = str_extract(actor, "[0-9]+")) |>
    count(prosecutor_str)

defense <-
    sig_rand_effects |>
    filter(group == "main_defense") |>
    mutate(defense_str = str_extract(actor, "[0-9]+")) |>
    count(defense_str)

judge <-
    sig_rand_effects |>
    filter(group == "judge_assigned") |>
    mutate(judge_str = str_extract(actor, unique_judges)) |>
    count(judge_str)

################################################################################
# Subset data for prosecutors.
################################################################################
sig_prosecutor <- data |> filter(main_prosecutor %in% prosecutor$prosecutor_str)

super_sig_prosecutor <-
    data |>
    filter(
        main_prosecutor %in%
            (prosecutor |> filter(n > 1) |> pull(prosecutor_str))
    )

sig_prosecutor_judge <-
    data |>
    filter(
        main_prosecutor %in% prosecutor$prosecutor_str,
        judge_assigned %in% judge$judge_str
    )

super_sig_prosecutor_judge <-
    data |>
    filter(
        main_prosecutor %in% (prosecutor |> filter(n > 1) |> pull(prosecutor_str)),
        judge_assigned %in% (judge |> filter(n > 1) |> pull(judge_str))
    )

################################################################################
# Subset data for defense.
################################################################################
sig_defense <- data |> filter(main_defense %in% defense$defense_str)

super_sig_defense <-
    data |>
    filter(main_defense %in% (defense |> filter(n > 1) |> pull(defense_str)))

sig_defense_judge <-
    data |>
    filter(
        main_defense %in% defense$defense_str,
        judge_assigned %in% judge$judge_str
    )

super_sig_defense_judge <-
    data |>
    filter(
        main_defense %in% (defense |> filter(n > 1) |> pull(defense_str)),
        judge_assigned %in% (judge |> filter(n > 1) |> pull(judge_str))
    )

################################################################################
# Subset data for defense + prosecutor.
################################################################################
sig_defense_prosecutor <-
    data |>
    filter(
        main_defense %in% defense$defense_str,
        main_prosecutor %in% prosecutor$prosecutor_str
    )

sig_defense_prosecutor_judge <-
    data |>
    filter(
        main_defense %in% defense$defense_str,
        main_prosecutor %in% prosecutor$prosecutor_str,
        judge_assigned %in% judge$judge_str
    )

super_sig_defense_prosecutor <-
    data |>
    filter(
        main_defense %in% (defense |> filter(n > 1) |> pull(defense_str)),
        main_prosecutor %in% (prosecutor |> filter(n > 1) |> pull(prosecutor_str))
    )

################################################################################
# Estimate null models.
################################################################################
defense_null_models <-
    map(
        list(
            "null_sig_defense" = sig_defense,
            "null_sig_super_defense" = super_sig_defense,
            "null_sig_defense_judge" = sig_defense_judge,
            "null_sig_super_defense_judge" = super_sig_defense_judge
        ),
        function(df) {
            glmer(
                bail_decision_bin_nr ~
                    (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad),
                data = df,
                family = "binomial",
                control = glmerControl(optCtrl = list(maxfun = 100000))
            )
        }
    )

saveRDS(defense_null_models, file.path(write_dir, "sig_defense_null_models.rds"))

prosecutor_null_models <-
    map(
        list(
            "null_sig_prosecutor" = sig_prosecutor,
            "null_sig_super_prosecutor" = super_sig_prosecutor,
            "null_sig_prosecutor_judge" = sig_prosecutor_judge,
            "null_sig_super_prosecutor_judge" = super_sig_prosecutor_judge
        ),
        function(df) {
            glmer(
                bail_decision_bin_nr ~
                    (1 | judge_assigned) + (1 | main_prosecutor) + (1 | judge_prosecutor_dyad),
                data = df,
                family = "binomial",
                control = glmerControl(optCtrl = list(maxfun = 100000))
            )
        }
    )

saveRDS(prosecutor_null_models, file.path(write_dir, "sig_prosecutor_null_models.rds"))

all_null_models <-
    map(
        list(
            "null_sig_defense_prosecutor" = sig_defense_prosecutor,
            "null_sig_super_defense_prosecutor" = super_sig_defense_prosecutor,
            "null_sig_defense_prosecutor_judge" = sig_defense_prosecutor_judge
        ),
        function(df) {
            glmer(
                bail_decision_bin_nr ~
                    (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +
                    (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) +
                    (1 | defense_prosecutor_dyad),
                data = df,
                family = "binomial",
                control = glmerControl(optCtrl = list(maxfun = 100000))
            )
        }
    )

saveRDS(all_null_models, file.path(write_dir, "sig_all_null_models.rds"))

################################################################################
# Estimate full models.
################################################################################
all_full_models_max <-
    map(
        list(
            "full_sig_defense_prosecutor" = sig_defense_prosecutor,
            "full_sig_super_defense_prosecutor" = super_sig_defense_prosecutor,
            "full_sig_defense_prosecutor_judge" = sig_defense_prosecutor_judge
        ),
        function(df) {
            glmer(
                bail_decision_bin_nr ~
                    sex + race_collapsed + main_defense_private + age_scaled +
                    I(age_scaled ^ 2) + highest_charge_max + year_cat + county +
                    (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +
                    (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) +
                    (1 | defense_prosecutor_dyad),
                data = df,
                family = "binomial",
                control = glmerControl(optCtrl = list(maxfun = 100000))
            )
        }
    )

saveRDS(all_full_models_max, file.path(write_dir, "sig_all_full_models_max.rds"))

all_full_models_min <-
    map(
        list(
            "full_sig_defense_prosecutor" = sig_defense_prosecutor,
            "full_sig_super_defense_prosecutor" = super_sig_defense_prosecutor,
            "full_sig_defense_prosecutor_judge" = sig_defense_prosecutor_judge
        ),
        function(df) {
            glmer(
                bail_decision_bin_nr ~
                    sex + race_collapsed + main_defense_private + age_scaled +
                    I(age_scaled ^ 2) + highest_charge_min + year_cat + county +
                    (1 | judge_assigned) + (1 | main_defense) + (1 | main_prosecutor) +
                    (1 | judge_defense_dyad) + (1 | judge_prosecutor_dyad) +
                    (1 | defense_prosecutor_dyad),
                data = df,
                family = "binomial",
                control = glmerControl(optCtrl = list(maxfun = 100000))
            )
        }
    )

saveRDS(all_full_models_min, file.path(write_dir, "sig_all_full_models_min.rds"))
