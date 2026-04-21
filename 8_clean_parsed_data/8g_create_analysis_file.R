library(here)
library(dplyr)
library(readr)
library(stringr)
library(lubridate)
dir <- here("output", "final_data")

################################################################################
# Read in data.
################################################################################
data <- read_csv(file.path(dir, "final_ds_cs.csv"))
missing_data <- read_csv(file.path(dir, "final_ds_cs_missing.csv"))

################################################################################
# Get data ready for analysis.
################################################################################
data_clean <-
    data |>
    select(
        bail_decision_bin, matches("date"), matches("county"), judge_assigned,
        main_defense, main_prosecutor, defense_team, prosecutor_team,
        any_private, nr_charges, sex, race_collapsed, dob, matches("dyad"),
        matches("triad"), matches("^nr_"), main_defense_private_or_public,
        counsel, defender_requested, application_provided
    ) |>
    mutate(
        bail_decision_bin_nr = if_else(bail_decision_bin == "Effectively bail or detained", 1, 0),
        year = as.character(year(mdy(issue_date))),
        county = if_else(!is.na(county_new), tolower(county_new), county),
        mult_defense = if_else(str_detect(defense_team, "_"), 1, 0),
        mult_prosecutor = if_else(str_detect(prosecutor_team, "_"), 1, 0),
        main_defense_private = if_else(main_defense_private_or_public == "private", 1, 0),
        age = as.numeric(year) - year(ymd(dob)),
        highest_charge_max =
            case_when(
                nr_h1_max > 0 ~ "h1",
                nr_h2_max > 0 ~ "h2",
                nr_f1_max > 0 ~ "f1",
                nr_f2_max > 0 ~ "f2",
                nr_f3_max > 0 ~ "f3",
                nr_f_max > 0 ~ "f",
                nr_m1_max > 0 ~ "m1",
                nr_m2_max > 0 ~ "m2",
                nr_m3_max > 0 ~ "m3",
                nr_m_max > 0 ~ "m",
                nr_summary > 0 ~ "s"
            ),
        highest_charge_min =
            case_when(
                nr_h1_min > 0 ~ "h1",
                nr_h2_min > 0 ~ "h2",
                nr_f1_min > 0 ~ "f1",
                nr_f2_min > 0 ~ "f2",
                nr_f3_min > 0 ~ "f3",
                nr_f_min > 0 ~ "f",
                nr_m1_min > 0 ~ "m1",
                nr_m2_min > 0 ~ "m2",
                nr_m3_min > 0 ~ "m3",
                nr_m_min > 0 ~ "m",
                nr_summary > 0 ~ "s"
            )
    ) |>
    select(
        -bail_decision_bin, -matches("date"), -county_new, -dob,
        -matches("nr_(f|m|h|o|s)"), -main_defense_private_or_public
    )

missing_data_clean <-
    missing_data |>
    select(
        bail_decision_bin, matches("date"), matches("county"), judge_assigned,
        main_defense, main_prosecutor, defense_team, prosecutor_team,
        any_private, nr_charges, sex, race_collapsed, dob, matches("dyad"),
        matches("triad"), matches("^nr_"), main_defense_private_or_public,
        counsel, defender_requested, application_provided
    ) |>
    mutate(
        bail_decision_bin_nr = if_else(bail_decision_bin == "Effectively bail or detained", 1, 0),
        year = as.character(year(mdy(issue_date))),
        county = if_else(!is.na(county_new), tolower(county_new), county),
        mult_defense = if_else(str_detect(defense_team, "_"), 1, 0),
        mult_prosecutor = if_else(str_detect(prosecutor_team, "_"), 1, 0),
        main_defense_private = if_else(main_defense_private_or_public == "private", 1, 0),
        age = as.numeric(year) - year(ymd(dob)),
        highest_charge_max =
            case_when(
                nr_h1_max > 0 ~ "h1",
                nr_h2_max > 0 ~ "h2",
                nr_f1_max > 0 ~ "f1",
                nr_f2_max > 0 ~ "f2",
                nr_f3_max > 0 ~ "f3",
                nr_f_max > 0 ~ "f",
                nr_m1_max > 0 ~ "m1",
                nr_m2_max > 0 ~ "m2",
                nr_m3_max > 0 ~ "m3",
                nr_m_max > 0 ~ "m",
                nr_summary > 0 ~ "s"
            ),
        highest_charge_min =
            case_when(
                nr_h1_min > 0 ~ "h1",
                nr_h2_min > 0 ~ "h2",
                nr_f1_min > 0 ~ "f1",
                nr_f2_min > 0 ~ "f2",
                nr_f3_min > 0 ~ "f3",
                nr_f_min > 0 ~ "f",
                nr_m1_min > 0 ~ "m1",
                nr_m2_min > 0 ~ "m2",
                nr_m3_min > 0 ~ "m3",
                nr_m_min > 0 ~ "m",
                nr_summary > 0 ~ "s"
            )
    ) |>
    select(
        -bail_decision_bin, -matches("date"), -county_new, -defense_team,
        -prosecutor_team, -dob, -matches("nr_(f|m|h|o|s)")
    )

################################################################################
# Drop individuals who are too young and add them to missing.
# Drop cases where the defense attorney and prosecutor are same person.
# Drop cases where defense attorney's private/public status was unknown.
################################################################################
missing <-
    data_clean |>
    filter(age < 14 | main_defense == main_prosecutor | is.na(main_defense_private)) |>
    select(-matches("dyad|triad|team"))

data_clean_final <-
    data_clean |>
    filter(age >= 14, main_defense != main_prosecutor, !is.na(main_defense_private))

missing_data_clean_final <- missing_data_clean |> bind_rows(missing)

write_csv(data_clean_final, file.path(dir, "final_analysis_file.csv"))
write_csv(missing_data_clean_final, file.path(dir, "final_analysis_file_missings.csv"))
