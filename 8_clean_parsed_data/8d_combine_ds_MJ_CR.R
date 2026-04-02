library(here)
library(readr)
library(dplyr)
library(stringr)

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
        nr_charges = n(),
        nr_h1_max = sum(max_grade == "h1" & !is.na(max_grade)),
        nr_h2_max = sum(max_grade == "h2" & !is.na(max_grade)),
        nr_f1_max = sum(max_grade == "f1" & !is.na(max_grade)),
        nr_f2_max = sum(max_grade == "f2" & !is.na(max_grade)),
        nr_f3_max = sum(max_grade == "f3" & !is.na(max_grade)),
        nr_f_max = sum(max_grade == "f" & !is.na(max_grade)),
        nr_m1_max = sum(max_grade == "m1" & !is.na(max_grade)),
        nr_m2_max = sum(max_grade == "m2" & !is.na(max_grade)),
        nr_m3_max = sum(max_grade == "m3" & !is.na(max_grade)),
        nr_m_max = sum(max_grade == "m" & !is.na(max_grade)),
        nr_h1_min = sum(min_grade == "h1" & !is.na(min_grade)),
        nr_h2_min = sum(min_grade == "h2" & !is.na(min_grade)),
        nr_f1_min = sum(min_grade == "f1" & !is.na(min_grade)),
        nr_f2_min = sum(min_grade == "f2" & !is.na(min_grade)),
        nr_f3_min = sum(min_grade == "f3" & !is.na(min_grade)),
        nr_f_min = sum(min_grade == "f" & !is.na(min_grade)),
        nr_m1_min = sum(min_grade == "m1" & !is.na(min_grade)),
        nr_m2_min = sum(min_grade == "m2" & !is.na(min_grade)),
        nr_m3_min = sum(min_grade == "m3" & !is.na(min_grade)),
        nr_m_min = sum(min_grade == "m" & !is.na(min_grade)),
        nr_missing = sum(is.na(max_grade)),
        nr_summary = sum(str_detect(max_grade, "^s[1-5]*$") & !is.na(max_grade)),
        nr_other =
            sum(
                !(
                    max_grade %in%
                        c(
                            "h1", "h2", "f1", "f2", "f3", "f", "m1", "m2", "m3",
                            "m", "s1", "s2", "s3", "s4", "s5", "s"
                        )
                ) & !is.na(max_grade)
            )
    ) |>
    ungroup() |>
    mutate(
        nr_felonies_max = rowSums(across(matches("*nr_(h|f)[1-3]*_max"))),
        nr_felonies_min = rowSums(across(matches("*nr_(h|f)[1-3]*_min"))),
        nr_misd_max = rowSums(across(matches("*nr_m[1-3]*_max"))),
        nr_misd_min = rowSums(across(matches("*nr_m[1-3]*_min")))
    )

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
        across(matches("ogs_score"), function(col) {max(col, na.rm = T)}),
        nr_charges = n(),
        nr_h1_max = sum(max_grade == "h1" & !is.na(max_grade)),
        nr_h2_max = sum(max_grade == "h2" & !is.na(max_grade)),
        nr_f1_max = sum(max_grade == "f1" & !is.na(max_grade)),
        nr_f2_max = sum(max_grade == "f2" & !is.na(max_grade)),
        nr_f3_max = sum(max_grade == "f3" & !is.na(max_grade)),
        nr_f_max = sum(max_grade == "f" & !is.na(max_grade)),
        nr_m1_max = sum(max_grade == "m1" & !is.na(max_grade)),
        nr_m2_max = sum(max_grade == "m2" & !is.na(max_grade)),
        nr_m3_max = sum(max_grade == "m3" & !is.na(max_grade)),
        nr_m_max = sum(max_grade == "m" & !is.na(max_grade)),
        nr_h1_min = sum(min_grade == "h1" & !is.na(min_grade)),
        nr_h2_min = sum(min_grade == "h2" & !is.na(min_grade)),
        nr_f1_min = sum(min_grade == "f1" & !is.na(min_grade)),
        nr_f2_min = sum(min_grade == "f2" & !is.na(min_grade)),
        nr_f3_min = sum(min_grade == "f3" & !is.na(min_grade)),
        nr_f_min = sum(min_grade == "f" & !is.na(min_grade)),
        nr_m1_min = sum(min_grade == "m1" & !is.na(min_grade)),
        nr_m2_min = sum(min_grade == "m2" & !is.na(min_grade)),
        nr_m3_min = sum(min_grade == "m3" & !is.na(min_grade)),
        nr_m_min = sum(min_grade == "m" & !is.na(min_grade)),
        nr_missing = sum(is.na(max_grade)),
        nr_summary = sum(str_detect(max_grade, "^s[1-5]*$") & !is.na(max_grade)),
        nr_other =
            sum(
                !(
                    max_grade %in%
                        c(
                            "h1", "h2", "f1", "f2", "f3", "f", "m1", "m2", "m3",
                            "m", "s1", "s2", "s3", "s4", "s5", "s"
                        )
                ) & !is.na(max_grade)
            )
    ) |>
    ungroup() |>
    mutate(
        nr_felonies_max = rowSums(across(matches("*nr_(h|f)[1-3]*_max"))),
        nr_felonies_min = rowSums(across(matches("*nr_(h|f)[1-3]*_min"))),
        nr_misd_max = rowSums(across(matches("*nr_m[1-3]*_max"))),
        nr_misd_min = rowSums(across(matches("*nr_m[1-3]*_min"))),
        across(
            matches("ogs_score"), function(col) {if_else(col == -Inf, NA, col)}
        )
    )

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
