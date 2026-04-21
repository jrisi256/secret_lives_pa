library(here)
library(dplyr)
library(readr)
read_dir <- here("output", "final_data")

################################################################################
# Read in data.
################################################################################
data <- read_csv(file.path(read_dir, "final_analysis_file.csv"))
data_missing <-
    read_csv(file.path(read_dir, "final_analysis_file_missings.csv")) |>
    mutate(
        sex = if_else(is.na(sex), "unreported/unknown", sex),
        race_collapsed = if_else(is.na(race_collapsed), "unknown/unreported", race_collapsed)
    )

################################################################################
# Different missing data.
################################################################################
sex_not_missing <- data_missing |> filter(sex != "unreported/unknown") |> select(sex)
race_not_missing <- data_missing |> filter(race_collapsed != "unknown/unreported") |> select(race_collapsed)
private_not_missing <- data_missing |> filter(!is.na(main_defense_private)) |> select(main_defense_private)
year_not_missing <- data_missing |> filter(!is.na(year)) |> select(year)
age_not_missing <- data_missing |> filter(!is.na(age)) |> select(age)
charge_not_missing <- data_missing |> filter(!is.na(highest_charge_max)) |> select(matches("charge"))
county_not_missing <- data_missing |> filter(!is.na(county)) |> select(county)
bail_not_missing <- data_missing |> filter(!is.na(bail_decision_bin_nr)) |> select(bail_decision_bin_nr)

judge_defense <-
    data_missing |>
    filter(!is.na(judge_assigned), !is.na(main_defense)) |>
    mutate(judge_defense_dyad = paste0(judge_assigned, "_", main_defense))

judge_prosecutor <-
    data_missing |>
    filter(!is.na(judge_assigned), !is.na(main_prosecutor)) |>
    mutate(judge_prosecutuor_dyad = paste0(judge_assigned, "_", main_prosecutor))
