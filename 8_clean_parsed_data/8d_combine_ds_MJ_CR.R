library(here)
library(readr)
library(dplyr)

dir <- here("output", "final_data")

################################################################################
# Read in data.
################################################################################
bail <- read_csv(file.path(dir, "ds_MJ_CR_bail.csv"))
demo_judge <- read_csv(file.path(dir, "ds_MJ_CR_demo_judge.csv"))
lawyer <- read_csv(file.path(dir, "ds_MJ_CR_lawyer.csv"))
charges <-
    read_csv(
        file.path(dir, "ds_MJ_CR_charges.csv"),
        col_types =
            cols(
                mean_ogs_score = "c", max_ogs_score = "c", min_ogs_score = "c",
                omni_ogs_score = "c"
            )
    )

################################################################################
# Merge judge/demographic data with bail data.
################################################################################
merged_bail_judge <- left_join(bail, demo_judge, by = "L1")

################################################################################
# Clean judge information.
################################################################################
merged_no_missing_judges <-
    merged_bail_judge |>
    filter(
        !is.na(judge_assigned),
        !(
            judge_assigned %in%
                c(
                    "magisterial district judge dauphin county night court mdj 12-0-00",
                    "magisterial district judge dauphin county central court mdj 12-0-01",
                    "magisterial district judge central court mdj 24-0-00",
                    "magisterial district judge erie county central court mdj 06-0-01",
                    "magisterial district judge centre central court 49-0-00"
                )
        )
    )

merged_missing_judges <-
    merged_bail_judge |>
    filter(
        is.na(judge_assigned) |
        (
            judge_assigned %in%
                c(
                    "magisterial district judge dauphin county night court mdj 12-0-00",
                    "magisterial district judge dauphin county central court mdj 12-0-01",
                    "magisterial district judge central court mdj 24-0-00",
                    "magisterial district judge erie county central court mdj 06-0-01",
                    "magisterial district judge centre central court 49-0-00"
                )
        )
    ) |>
    pull(L1)

################################################################################
# Clean demographic information.
################################################################################
merged_no_missing_demo <-
    merged_no_missing_judges |>
    filter(
        sex != "unreported/unknown",
        !is.na(sex),
        race != "unknown/unreported",
        !is.na(race),
        !is.na(dob)
    )

merged_missing_demo <-
    merged_no_missing_judges |>
    filter(
        sex == "unreported/unknown" |
        is.na(sex) |
        race == "unknown/unreported" |
        is.na(race) |
        is.na(dob)
    ) |>
    pull(L1)

################################################################################
# Merge with lawyer data.
################################################################################
merged_lawyer <- left_join(merged_no_missing_demo, lawyer, by = "L1")

merged_lawyer_no_missing <-
    merged_lawyer |>
    filter(!is.na(main_prosecutor), !is.na(main_defense))

merged_lawyer_missing <-
    merged_lawyer |>
    filter(is.na(main_prosecutor) | is.na(main_defense)) |>
    pull(L1)

################################################################################
# Merge with charges and create final data table.
################################################################################
merged_charges <-
    merged_lawyer_no_missing |>
    left_join(charges, by = "L1") |>
    mutate(
        match = if_else(is.na(as.numeric(mean_ogs_score)), "no ogs score", match),
        across(matches("ogs_score"), function(col) {as.numeric(col)})
    )

merged_charges_no_missing <-
    merged_charges |>
    group_by(L1) |>
    filter(!all(match == "no ogs score")) |>
    ungroup()

merged_charges_missing <-
    merged_charges |>
    group_by(L1) |>
    filter(all(match == "no ogs score")) |>
    distinct(L1) |>
    pull(L1)

case_level_ogs_score <-
    merged_charges_no_missing |>
    group_by(L1) |>
    summarise(
        across(matches("ogs_score"), function(col) {max(col, na.rm = T)}),
        nr_charges = n()
    ) |>
    ungroup()

final_df <-
    merged_lawyer_no_missing |>
    inner_join(case_level_ogs_score, by = "L1")

write_csv(final_df, file.path(dir, "ds_final_df.csv"))

################################################################################
# Create corresponding table of missing values (on at least one column).
################################################################################
charges_summary <-
    charges |>
    mutate(across(matches("ogs_score"), function(col) {as.numeric(col)})) |>
    group_by(L1) |>
    summarise(
        nr_charges = n(),
        mean_ogs_score = max(mean_ogs_score),
        max_ogs_score = max(max_ogs_score),
        min_ogs_score = max(min_ogs_score),
        omni_ogs_score = max(omni_ogs_score)
    ) |>
    ungroup()

final_missing_df <-
    bail |>
    left_join(demo_judge, by = "L1") |>
    left_join(lawyer, by = "L1") |>
    left_join(charges_summary, by = "L1") |>
    filter(
        L1 %in%
            c(
                merged_charges_missing, merged_lawyer_missing,
                merged_missing_demo, merged_missing_judges
            )
    )

write_csv(final_missing_df, file.path(dir, "ds_final_missing_df.csv"))
