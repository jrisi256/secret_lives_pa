library(here)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(dtplyr)
library(stringr)
library(lubridate)
dir <- here("output", "final_data")

################################################################################
# Read in flattened json file, cleaned DS tables, and cleaned criminal history.
################################################################################
flattened_json_cs_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_cs_mj.rds"))

flattened_json_ds_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds")) |>
    filter(L3 %in% c("issue_date", "file_date", "arrest_date", "disposition_date")) |>
    pivot_wider(id_cols = L1, names_from = "L3", values_from = "value") |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "county_new", "docket_id"), too_many = "merge"
    ) |>
    select(-pdf_type, -county_new) |>
    rename(arrest_date_ds = arrest_date) |>
    mutate(docket_id = str_replace_all(tolower(docket_id), "_", "-"))

ds_df <-
    read_csv(file.path(dir, "ds_final_df.csv")) |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "county_new", "docket_id"), too_many = "merge"
    ) |>
    select(-pdf_type, -county_new)

ds_df_missing <-
    read_csv(file.path(dir, "ds_final_missing_df.csv")) |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "county_new", "docket_id"), too_many = "merge"
    ) |>
    select(-pdf_type, -county_new)

criminal_history <-
    read_csv(file.path(dir, "cs_MJ_CR_criminal_history.csv")) |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "county_new", "docket_id"), too_many = "merge"
    ) |>
    select(-pdf_type, -county_new, -master_county)

################################################################################
# Read in demographic information.
################################################################################
demo_df <-
    flattened_json_cs_mj |>
    filter(is.na(L3)) |>
    pivot_wider(id_cols = "L1", names_from = "L2", values_from = "value") |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "county_new", "docket_id"), too_many = "merge"
    ) |>
    select(-pdf_type, county_new) |>
    mutate(
        sex = if_else(sex == "" | is.na(sex), "unreported/unknown", tolower(sex)),
        race = if_else(race == "" | is.na(race), "unknown/unreported", tolower(race)),
        eyes = if_else(eyes == "" | is.na(eyes), "Unknown", eyes),
        hair = if_else(hair == "" | is.na(hair), "Unknown or Completely Bald", hair),
        race_collapsed = case_when(
            race == "asian" ~ "Other",
            race == "asian/pacific islander" ~ "Other",
            race == "bi-racial" ~ "Other",
            race == "native american/alaskan native" ~ "Other",
            race == "native hawaiian/pacific islander" ~ "Other",
            T ~ race,
        ),
        dob = mdy(dob),
        ,
        hair_collapsed = case_when(
            hair %in% c("Blue", "Green", "Orange", "Pink", "Purple") ~ "Dyed Hair",
            hair == "Gray or Partially Gray" | hair == "White" ~ "Gray/White Hair",
            hair == "Sandy" ~ "Blond or Strawberry",
            T ~ hair
        ),
        eyes_collapsed = if_else(
            eyes %in% c("Gray", "Maroon", "Multicolored", "Pink"), "Other", eyes
        )
    )

################################################################################
# Check and see if demographic information matches docket sheets.
################################################################################
match_demo <-
    ds_df |>
    left_join(demo_df, by = "docket_id", suffix = c("_ds", "_cs")) |>
    mutate(
        sex =
            if_else(
                sex_ds != sex_cs & sex_cs != "unreported/unknown" & !is.na(sex_cs),
                "unreported/unknown",
                sex_ds
            ),
        race_collapsed =
            if_else(
                race_collapsed_ds != race_collapsed_cs & race_collapsed_cs != "unknown/unreported" & !is.na(race_collapsed_cs),
                "unknown/unreported",
                race_collapsed_ds
            ),
        dob = if_else(year(dob_ds) != year(dob_cs) & !is.na(dob_cs), NA, dob_ds),
        eyes = if_else(is.na(eyes), "Unknown", eyes),
        eyes_collapsed = if_else(is.na(eyes_collapsed), "Unknown", eyes_collapsed),
        hair = if_else(is.na(hair), "Unknown", hair),
        hair_collapsed = if_else(is.na(hair_collapsed), "Unknown", hair_collapsed)
    ) |>
    select(
        -race_ds, -race_cs, -race_collapsed_ds, -race_collapsed_cs, -sex_ds,
        -sex_cs, -dob_ds, -dob_cs
    )

missing <-
    match_demo |>
    filter(race_collapsed == "unknown/unreported" | is.na(dob) | sex == "unreported/unknown")

match_demo_clean <-
    match_demo |>
    filter(race_collapsed != "unknown/unreported", !is.na(dob), sex != "unreported/unknown")

#################################################### Sample with missing values.
match_demo_missing <-
    ds_df_missing |>
    left_join(demo_df, by = "docket_id", suffix = c("_ds", "_cs")) |>
    mutate(
        sex_cs = if_else(is.na(sex_cs), "unreported/unknown", sex_cs),
        race_cs = if_else(is.na(race_cs), "unknown/unreported", race_cs),
        sex =
            case_when(
                sex_ds == "unreported/unknown" & sex_cs == "unreported/unknown" ~ "unreported/unknown",
                sex_ds != "unreported/unknown" & sex_cs == "unreported/unknown" ~ sex_ds,
                sex_ds == "unreported/unknown" & sex_cs != "unreported/unknown" ~ sex_cs,
                sex_ds != sex_cs ~ "unreported/unknown",
                T ~ sex_ds
            ),
        race_collapsed =
            case_when(
                race_collapsed_ds == "unknown/unreported" & race_collapsed_cs == "unknown/unreported" ~ "unknown/unreported",
                race_collapsed_ds != "unknown/unreported" & race_collapsed_cs == "unknown/unreported" ~ race_collapsed_ds,
                race_collapsed_ds == "unknown/unreported" & race_collapsed_cs != "unknown/unreported" ~ race_collapsed_cs,
                race_collapsed_ds != race_collapsed_cs ~ "unknown/unreported",
                T ~ race_collapsed_ds
            ),
        dob =
            case_when(
                is.na(dob_ds) & is.na(dob_cs) ~ NA,
                !is.na(dob_ds) & is.na(dob_cs) ~ dob_ds,
                is.na(dob_ds) & !is.na(dob_cs) ~ dob_cs,
                year(dob_ds) != year(dob_cs) ~ NA,
                T ~ dob_ds
            ),
        eyes = if_else(is.na(eyes), "Unknown", eyes),
        eyes_collapsed = if_else(is.na(eyes_collapsed), "Unknown", eyes_collapsed),
        hair = if_else(is.na(hair), "Unknown", hair),
        hair_collapsed = if_else(is.na(hair_collapsed), "Unknown", hair_collapsed)
    ) |>
    bind_rows(missing) |>
    select(
        -race_ds, -race_cs, -race_collapsed_ds, -race_collapsed_cs, -sex_ds,
        -sex_cs, -dob_ds, -dob_cs
    )

################################################################################
# Clean criminal history and determine what is history vs. future.
################################################################################
# Cases with a criminal history (or future) but they have no charges.
no_charges_history <-
    criminal_history |>
    group_by(docket_id) |>
    filter(all(prior_nr_charges == 0)) |>
    summarise(across(matches("prior"), function(col) {sum(col)})) |>
    ungroup() |>
    mutate(any_missing = T)

# Cases with no criminal history.
no_criminal_history <-
    criminal_history |>
    group_by(docket_id) |>
    filter(n() == 1, master_docket_nr == docket_number, prior_nr_charges != 0) |>
    mutate(across(matches("prior"), function(col) {col = 0})) |>
    summarise(across(matches("prior"), function(col) {sum(col)})) |>
    ungroup() |>
    mutate(any_missing = T)

# Cases where the only criminal history are cases which happen in the future.
criminal_history_base <-
    criminal_history |>
    filter(master_docket_nr != docket_number, prior_nr_charges != 0) |>
    mutate(ch_year = str_extract(docket_number, "[0-9]{4}$"))

only_future_criminal_cases <-
    criminal_history_base |>
    mutate(across(matches("prior"), function(col) {col = 0})) |>
    group_by(docket_id) |>
    filter(all(ch_year > master_year)) |>
    summarise(across(matches("prior"), function(col) {sum(col)})) |>
    ungroup() |>
    mutate(any_missing = T)

# Clean criminal history dates.
criminal_history_dates <-
    criminal_history |>
    group_by(docket_number) |>
    summarise(
        across(
            matches("arrest_date|disp_event_date"),
            function (col) {
                valid_vals <- unique(na.omit(col))
                if(length(valid_vals) == 0) { 
                    NA 
                } else {
                    paste(valid_vals, collapse = ",")
                }
            }
        )
    ) |>
    ungroup() |>
    separate_wider_delim(
        arrest_date,
        delim = ",",
        names = c("arrest_date1", "arrest_date2"),
        too_few = "align_start"
    ) |>
    separate_wider_delim(
        disp_event_date,
        delim = ",",
        names = c("disp_event_date1", "disp_event_date2"),
        too_few = "align_start"
    ) |>
    full_join(
        flattened_json_ds_mj |> mutate(docket_id = str_replace_all(tolower(docket_id), "_", "-")),
        by = c("docket_number" = "docket_id")
    ) |>
    mutate(
        across(matches("date"), function(col) {mdy(col)}),
        arrest_date =
            case_when(
                is.na(arrest_date_ds) & !is.na(arrest_date1) & is.na(arrest_date2) ~ arrest_date1,
                !is.na(arrest_date_ds) & is.na(arrest_date1) ~ arrest_date_ds,
                is.na(arrest_date_ds) & arrest_date1 != arrest_date2 ~ NA,
                arrest_date_ds == arrest_date1 ~ arrest_date_ds,
                arrest_date_ds == arrest_date2 ~ arrest_date_ds,
                is.na(arrest_date_ds) & is.na(arrest_date1) ~ NA,
                arrest_date_ds != arrest_date1 ~ NA
            ),
        disp_date =
            case_when(
                is.na(disposition_date) & !is.na(disp_event_date1) & is.na(disp_event_date2) ~ disp_event_date1,
                !is.na(disposition_date) & is.na(disp_event_date1) ~ disposition_date,
                is.na(disposition_date) & disp_event_date1 != disp_event_date2 ~ NA,
                disposition_date == disp_event_date1 ~ disposition_date,
                disposition_date == disp_event_date2 ~ disposition_date,
                is.na(disposition_date) & is.na(disp_event_date1) ~ NA,
                disposition_date != disp_event_date1 ~ NA
            )
    ) |>
    select(
        -arrest_date_ds, -arrest_date1, -arrest_date2, -disposition_date,
        -disp_event_date1, -disp_event_date2, -disp_date
    )

compare_dates <- function(date_ch, date_master) {
    case_when(
        is.na(date_ch) | is.na(date_master) ~ "unknown",
        date_ch > date_master ~ "after",
        date_ch < date_master ~ "before",
        date_ch == date_master ~ "same"
    )
}

criminal_history_cleaned <-
    criminal_history_base |>
    filter(ch_year <= master_year) |>
    select(master_year, master_docket_nr, docket_number, ch_year, matches("prior")) |>
    rename(ch_docket_number = docket_number) |>
    left_join(
        criminal_history_dates, by = c("master_docket_nr" = "docket_number")
    ) |>
    left_join(
        criminal_history_dates,
        by = c("ch_docket_number" = "docket_number"),
        suffix = c("_master", "_ch")
    ) |>
    separate_wider_delim(
        ch_docket_number,
        delim = "-",
        names = c("court_type", "court_id_ch", "offense_type", "case_id_ch", "year"),
        cols_remove = F
    ) |>
    mutate(case_id_ch = as.numeric(case_id_ch)) |>
    select(-court_type, -offense_type, -year) |>
    separate_wider_delim(
        master_docket_nr,
        delim = "-",
        names = c("court_type", "court_id_master", "offense_type", "case_id_master", "year"),
        cols_remove = F
    ) |>
    mutate(case_id_master = as.numeric(case_id_master)) |>
    select(-court_type, -offense_type, -year) |>
    mutate(
        happened_after_case_year =
            case_when(
                ch_year < master_year ~ "before",
                ch_year > master_year ~ "after",
                ch_year == master_year ~ "unknown"
            ),
        happened_after_case_id =
            case_when(
                court_id_ch == court_id_master & ch_year == master_year & case_id_ch > case_id_master ~ "after",
                court_id_ch == court_id_master & ch_year == master_year & case_id_ch < case_id_master ~ "before",
                court_id_ch == court_id_master & ch_year == master_year & case_id_ch == case_id_master ~ "same",
                court_id_ch != court_id_master | ch_year != master_year ~ "unknown"
            ),
        happened_after_issue_date = compare_dates(issue_date_ch, issue_date_master),
        happened_after_file_date = compare_dates(file_date_ch, file_date_master),
        happened_after_arrest_date = compare_dates(arrest_date_ch, arrest_date_master),
        happened_after =
            case_when(
                happened_after_case_year == "after" | happened_after_case_id == "after" ~ "after",
                happened_after_case_year == "before" | happened_after_case_id == "before" ~ "before",
                happened_after_case_id == "same" ~ "same",
                happened_after_issue_date == "before" &
                    happened_after_file_date %in% c("before", "unknown", "same") &
                    happened_after_arrest_date %in% c("before", "unknown", "same") ~ "before",
                happened_after_file_date == "before" &
                    happened_after_issue_date %in% c("before", "unknown", "same") &
                    happened_after_arrest_date %in% c("before", "unknown", "same") ~ "before",
                happened_after_arrest_date == "before" &
                    happened_after_issue_date %in% c("before", "unknown", "same") &
                    happened_after_file_date %in% c("before", "unknown", "same") ~ "before",
                happened_after_issue_date == "after" &
                    happened_after_file_date %in% c("after", "unknown") &
                    happened_after_arrest_date %in% c("after", "unknown") ~ "after",
                happened_after_file_date == "after" &
                    happened_after_issue_date %in% c("after", "unknown") &
                    happened_after_arrest_date %in% c("after", "unknown") ~ "after",
                happened_after_arrest_date == "after" &
                    happened_after_issue_date %in% c("after", "unknown") &
                    happened_after_file_date %in% c("after", "unknown") ~ "after",
                happened_after_arrest_date == "unknown" &
                    happened_after_issue_date == "unknown" &
                    happened_after_file_date == "unknown" ~ "unknown",
                happened_after_issue_date %in% c("same", "unknown") &
                    happened_after_file_date %in% c("same", "unknown") &
                    happened_after_arrest_date %in% c("same", "unknown") ~ "same",
                happened_after_arrest_date == "before" ~ "before",
                happened_after_arrest_date == "same" ~ "same",
                happened_after_file_date == "after" & happened_after_issue_date == "after" ~ "after",
                happened_after_file_date == "before" & happened_after_issue_date %in% c("before", "same") ~ "before",
                happened_after_file_date %in% c("before", "same") & happened_after_issue_date == "before" ~ "before",
                happened_after_file_date == "same" & happened_after_issue_date == "same" ~ "same",
                happened_after_file_date != happened_after_issue_date ~ "unknown"
            )
    ) |>
    mutate(
        across(
            matches("prior"),
            function(col) {
                case_when(
                    happened_after == "after" ~ 0,
                    happened_after == "unknown" ~ NA_real_,
                    happened_after == "before" ~ col
                )
            }
        ),
        docket_id = str_replace_all(toupper(master_docket_nr), "-", "_")
    ) |>
    select(-master_docket_nr)

# Cases where all criminal history cases have unknown temporal status.
all_unknown <-
    criminal_history_cleaned |>
    group_by(docket_id) |>
    filter(all(happened_after == "unknown")) |>
    summarise(across(matches("prior"), function(col) {sum(col)})) |>
    ungroup() |>
    mutate(any_missing = T)

criminal_history_final <-
    criminal_history_cleaned |>
    group_by(docket_id) |>
    mutate(any_missing = any(happened_after == "unknown")) |>
    filter(happened_after != "unknown") |>
    summarise(
        across(matches("prior"), function(col) {sum(col, na.rm = T)}),
        any_missing = unique(any_missing)
    ) |>
    ungroup() |>
    bind_rows(
        no_charges_history, no_criminal_history, only_future_criminal_cases,
        all_unknown
    )

################################################################################
# Merge criminal history with docket sheets.
################################################################################
merged_ds_cs <-
    match_demo_clean |>
    left_join(criminal_history_final, by = "docket_id") |>
    mutate(
        across(
            matches("prior"),
            function(col) {if_else(is.na(any_missing), 0, col)}
        ),
        any_missing = if_else(is.na(any_missing), F, any_missing)
    )

missing_criminal_history <-
    merged_ds_cs |> 
    filter(
        is.na(prior_nr_charges) |
        (prior_nr_charges == prior_nr_missing + prior_nr_other & prior_nr_charges != 0)
    )

final_df <-
    merged_ds_cs |>
    filter(
        !is.na(prior_nr_charges) &
        (prior_nr_charges != prior_nr_missing + prior_nr_other | prior_nr_charges == 0)
    ) |>
    mutate(
        judge_prosecutuor_dyad = paste0(judge_assigned, "_", main_prosecutor),
        judge_defense_dyad = paste0(judge_assigned, "_", main_defense),
        defense_prosecutor_dyad = paste0(main_defense, "_", main_prosecutor),
        judge_defense_prosecutor_triad = paste0(judge_assigned, "_", main_defense, "_", main_prosecutor)
    )

merged_ds_cs_missing <-
    match_demo_missing |>
    left_join(criminal_history_final, by = "docket_id") |>
    mutate(
        across(
            matches("prior"),
            function(col) {if_else(is.na(any_missing), 0, col)}
        ),
        any_missing = if_else(is.na(any_missing), F, any_missing)
    ) |>
    bind_rows(missing_criminal_history)

write_csv(final_df, file.path(dir, "final_ds_cs.csv"))
write_csv(merged_ds_cs_missing, file.path(dir, "final_ds_cs_missing.csv"))
