library(here)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(lubridate)

################################################################################
# Read in codebook and clean it.
################################################################################
calc_prs_score <- function(col, fn) {
    if(any(is.na(as.numeric(col)))) {
        if(length(unique(col)) > 1) {print(unique(col))}
        unique(col)
    } else {
        if(fn == "mean") {
            as.character(mean(as.numeric(col), na.rm = T))
        } else if(fn == "max") {
            as.character(max(as.numeric(col), na.rm = T))
        } else if(fn == "min") {
            as.character(min(as.numeric(col), na.rm = T))
        }
    }
}

codebook <-
    read_xlsx(here("output", "pdf_parse_list", "ogs_and_prs_codebook.xlsx")) |>
    mutate(
        Statute =
            case_when(
                str_detect(Description, "Aggravated harassment") ~ "2703.1",
                str_detect(Description, "Use or operate") ~ "5103.1",
                str_detect(Description, "^Sexual assault$") ~ "3124.1",
                str_detect(Description, "False reports of") ~ "4906.1",
                str_detect(Description, "Habitual") ~ "6503.1",
                T ~ Statute,
            )
    )

codebook_charge_id <-
    codebook |>
    mutate(
        Code =
            str_replace_all(
                trimws(Code),
                "\\s+Pa\\.C\\.S\\.\\s+|\\s+P\\.S\\.\\s*",
                ""
            ),
        Code = str_replace_all(Code, "§", "_"),
        Code = str_replace_all(Code, "\\s+", ""),
        Statute = str_replace(Statute, "\\(", "_"),
        Statute = str_replace_all(Statute, "\\(", ""),
        Statute = str_replace_all(Statute, "\\)", ""),
        charge_id = paste0(Code, "_", Statute),
        charge_id = str_replace_all(charge_id, "_+", "_"),
        `Statutory Class` = str_replace_all(tolower(`Statutory Class`), "-", ""),
        `Statutory Class` =
            case_when(
                `Statutory Class` == "murder of 1st degree" ~ "h1",
                `Statutory Class` == "murder of 2nd degree" ~ "h2",
                T ~ `Statutory Class`
            )
    )

codebook_cleaned <-
    codebook_charge_id |>
    # None of our recorded charges involve eco-terrorism.
    # Would be hard to clean, so we drop them for now.
    filter(!str_detect(Description, "Ecoterrorism")) |>
    # For charges w/ the same id + class, calculate the mean, min, and max OGS.
    group_by(charge_id, `Statutory Class`) |>
    summarise(
        mean_prs_score = calc_prs_score(`Prior Record Score Points`, "mean"),
        max_prs_score = calc_prs_score(`Prior Record Score Points`, "max"),
        min_prs_score = calc_prs_score(`Prior Record Score Points`, "min")
    ) |>
    mutate(omni_ogs_score = mean_prs_score) |>
    ungroup()

################################################################################
# Read in flattened json cs file, cleaned ds data frames, and codebook.
################################################################################
flattened_json_cs_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_cs_mj.rds"))

ds_df <-
    read_csv(here("output", "final_data", "ds_final_df.csv")) |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "docket_nr"), too_many = "merge"
    ) |>
    select(-pdf_type)

ds_df_missing <-
    read_csv(here("output", "final_data", "ds_final_missing_df.csv")) |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "docket_nr"), too_many = "merge"
    ) |>
    select(-pdf_type)

################################################################################
# Read in demographic information.
################################################################################
demo_df <-
    flattened_json_cs_mj |>
    filter(is.na(L3)) |>
    pivot_wider(id_cols = "L1", names_from = "L2", values_from = "value") |>
    separate_wider_delim(
        L1, delim = "_", names = c("pdf_type", "docket_nr"), too_many = "merge"
    ) |>
    select(-pdf_type) |>
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
######################################################## Sample with no missing.
match_demo <-
    ds_df |>
    left_join(demo_df, demo_df, by = "docket_nr", suffix = c("_ds", "_cs")) |>
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
match_missing_demo <-
    ds_df_missing |>
    left_join(demo_df, by = "docket_nr", suffix = c("_ds", "_cs")) |>
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
# Create criminal history variables.
################################################################################
criminal_history_cases_df <-
    flattened_json_cs_mj |>
    filter(
        L3 %in% c("docket_number", "arrest_date", "disp_event_date", "last_action_date")
    ) |>
    pivot_wider(
        id_cols = c("L1", "L2"), names_from = "L3", values_from = "value"
    ) |>
    filter(!str_detect(docket_number, "nt|tr"))

criminal_history_charges_df <-
    flattened_json_cs_mj |>
    filter(str_detect(L3, "charge")) |>
    pivot_wider(
        id_cols = c("L1", "L2", "L3"), names_from = "L4", values_from = "value"
    ) |>
    mutate(
        charge = str_replace_all(trimws(statute), "\\s+", ""),
        charge_id = str_replace_all(charge, "§+", "_")
    )
