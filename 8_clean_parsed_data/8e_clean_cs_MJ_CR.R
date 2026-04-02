library(here)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(dtplyr)
library(stringr)
dir <- here("output", "final_data")

################################################################################
# Read in flattened json cs file and cleaned ds data frames.
################################################################################
flattened_json_cs_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_cs_mj.rds"))

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
    )

# All d) grades are loitering.
# o and op grades are open containers.
# lid)s is public drunkenness.
# lid) is unlawful entry, disorderly conduct, littering and other things related to damaging or harmful behavior on public property.
# n is entry into a park after dark.
# lisd) is parking violation.
# lo is loitering.
criminal_history_charges_df <-
    flattened_json_cs_mj |>
    filter(str_detect(L3, "charge")) |>
    pivot_wider(
        id_cols = c("L1", "L2", "L3"), names_from = "L4", values_from = "value"
    ) |>
    mutate(
        charge = str_replace_all(trimws(statute), "\\s+", ""),
        charge_id = str_replace_all(charge, "§+", "_"),
        grade =
            case_when(
                grade %in% c("d)", "o", "op", "lid)s", "lid)", "n", ") s", ")s", "lisd)") ~ "s",
                grade == "p" & str_detect(description, "anhandling") ~ "s",
                grade == ")" & str_detect(description, "65 mph") ~ "s",
                grade %in% c("f-3", "id)f3", ") f3") ~ "f3",
                grade == "m2m2" ~ "m2",
                grade == "m-1" ~ "m1",
                grade == "lo" ~ "s",
                T ~ grade   
            )
    )

criminal_history_has_grade <-
    criminal_history_charges_df |>
    filter(str_detect(grade, "^(m|f|s|h)[1-8]{0,1}$")) |>
    mutate(match = "has_grade", max_grade = grade, min_grade = grade) |>
    select(-grade)

################################################################################
# Try and impute missing grades.
################################################################################
criminal_history_missing_grade <-
    criminal_history_charges_df |>
    filter(!str_detect(grade, "^(m|f|s|h)[1-8]{0,1}$"))

################ Read in and clean the code book. Summarize to the charge level.
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

raw_levels <- unique(codebook_charge_id$`Statutory Class`)

codebook_by_charge <-
    codebook_charge_id |>
    filter(
        !str_detect(Description, "Ecoterrorism"),
        # Mixed of strings and numbers for these offenses, drop the strings.
        !str_detect(Description, "Unlaw. contact") | `Statutory Class` == "f3",
        !is.na(`Offense Gravity Score`)
    ) |>
    mutate(
        `Statutory Class` =
            if_else(
                `Statutory Class` %in% c("f31", "f32"), "f3", `Statutory Class`
            ),
        # Order of non-misdemeanor, non-felony, non-homicides do no matter.
        `Statutory Class` =
            factor(
                `Statutory Class`,
                levels =
                    c(
                        str_extract(raw_levels, ".*905"),
                        str_extract(raw_levels, ".*1102.*"),
                        str_extract(raw_levels, ".*2710.*"),
                        "same as corresponding offense under 18 pa.c.s. chapter 30",
                        "m", "m3", "m2", "m1", "f", "f3", "f2", "f1", "h2", "h1"
                    ),
                ordered = T
            )
    ) |>
    group_by(charge_id) |>
    summarise(
        max_grade = max(`Statutory Class`),
        min_grade = min(`Statutory Class`)
    ) |>
    ungroup()

######################### Merge charges with no grade to code book by charge ID.
criminal_history_missing_grade_match_charge_id <-
    criminal_history_missing_grade |>
    inner_join(codebook_by_charge, by = "charge_id") |>
    mutate(
        match = "no grade - match on charge",
        max_grade = grade,
        min_grade = grade
    ) |>
    select(-grade)

criminal_history_missing_grade_no_match <-
    criminal_history_missing_grade |>
    anti_join(codebook_by_charge, by = "charge_id")

## Merge charges with no grade to code book by charge ID (remove or add a star).
criminal_history_missing_grade_no_match_stars <-
    criminal_history_missing_grade_no_match |>
    mutate(
        new_charge_id =
            if_else(
                str_detect(charge_id, "\\*"),
                str_replace_all(charge_id, "\\*", ""),
                paste0(charge_id, "*")
            )
    )

criminal_history_missing_grade_stars_match <-
    criminal_history_missing_grade_no_match_stars |>
    inner_join(codebook_by_charge, by = c("new_charge_id" = "charge_id")) |>
    mutate(
        match = "no grade - stars",
        max_grade = grade,
        min_grade = grade
    ) |>
    select(-grade, -new_charge_id)

criminal_history_missing_grade_stars_not_fixed <-
    criminal_history_missing_grade_no_match_stars |>
    anti_join(codebook_by_charge, by = c("new_charge_id" = "charge_id"))

##################################### Try and impute the missing grades by hand.
charges_by_hand <-
    criminal_history_missing_grade_stars_not_fixed |>
    mutate(
        description = str_replace(description, "\\s{10,}.*", ""),
        grade =
            case_when(
                str_detect(description, "false id.*") ~ "m3",
                str_detect(description, "murder|homicide of unborn child") ~ "h1",
                str_detect(description, "criminal homicide|homicide") ~ "f1",
                str_detect(description, "simple.*assault") ~ "m",
                str_detect(description, "officer - firearm discharged") ~ "f1",
                str_detect(description, "assault of law|agg.* assaul|assault by prisoner|aggrav.* asslt|ind.*ass.*l|agg.*asslt|aggrav.*indec") ~ "f",
                str_detect(description, "terroristic.*threats") ~ "f",
                str_detect(description, "firearm into an occupied") ~ "f3",
                str_detect(description, "paintball") ~ "m",
                str_detect(description, "harassment") ~ "m3",
                str_detect(description, "stalking") ~ "f",
                str_detect(description, "unlaw.* restraint|invol servitude") ~ "m1",
                str_detect(description, "false imprisonment") ~ "m2",
                str_detect(description, "concealment of whereabouts of child") ~ "f3",
                str_detect(description, "(rape|idsi) person less than") ~ "f1",
                str_detect(description, "statutory sexual assault") ~ "f2",
                str_detect(description, "arson") ~ "f",
                str_detect(description, "criminal.*mischief") ~ "m",
                str_detect(description, "burglary") | charge_id == "18_3502_a" ~ "f1",
                str_detect(description, "crim.*tres|def.* tres") & str_detect(charge_id, "b") ~ "m",
                str_detect(description, "crim.*tres|def.* tres") & str_detect(charge_id, "3503_a1") ~ "m",
                str_detect(description, "robbery") ~ "f1",
                str_detect(description, "fleeing or attempting") ~ "m2",
                str_detect(description, "bad check") ~ "m",
                str_detect(description, "incest") ~ "f2",
                str_detect(description, "endanger.*child|endangering.*welfare") | charge_id %in% c("18_4304_a", "18_4304_b") ~ "f",
                str_detect(description, "tamper.*evidence") ~ "m",
                str_detect(description, "(inconsistent|false).* statement") ~ "m",
                str_detect(description, "falsely pretends") ~ "m",
                # failures to register, predominantly sex offenders.
                charge_id %in% c("18_4915_a1", "18_4915_a2", "18_4915_a3") ~ "f",
                str_detect(description, "disarming.*law.*enforce") ~ "f3",
                str_detect(description, "evading arrest") ~ "m2",
                str_detect(description, "hinder apprehen") ~ "f",
                str_detect(description, "disorderly.*conduct|disordelry.*conduct") ~ "m3",
                str_detect(description, "illegal to taunt police animal") ~ "f3",
                str_detect(description, "cr.* anim.*") ~ "m2",
                str_detect(description, "firearm without a license|firearm.*w/o.*lic") ~ "f3",
                str_detect(description, "poss.*firearm.*fugitive") ~ "m1",
                str_detect(description, "poss.*firearm.*drug") ~ "f",
                str_detect(description, "not.*firearm.*(incompetent|alien)|mental health patient.*firearm") ~ "m1",
                str_detect(description, "not.*firearm.*delinquent") ~ "m1",
                str_detect(description, "penalty - felony") ~ "f",
                str_detect(description, "not.*firearm|poss.*firearm") | str_detect(charge_id, "18_6105_(a|c)") ~ "m",
                str_detect(description, "fails to relinquish firearm") ~ "m2",
                str_detect(description, "sales of firearms") ~ "f",
                str_detect(description, "corruption.*of.*minors") ~ "m",
                str_detect(description, "purch etc alcoh bev by a minor") ~ "m3",
                str_detect(description, "sexual abuse.* child") ~ "f",
                str_detect(description, "child sex|child porn|dissem photo") | charge_id == "18_6312_b1" ~ "f",
                str_detect(description, "contact.*minor") ~ "f3",
                str_detect(description, "invasion of privacy") ~ "m",
                str_detect(description, "criminal use of communication facility") ~ "f3",
                str_detect(description, "small amount.*mari|drug para|marijuana.*small.*amt|poss of marijuana|marijuana-small") ~ "m",
                str_detect(description, "operat.*meth.*lab") ~ "f",
                str_detect(description, "theft from a motor vehicle") ~ "m",
                str_detect(description, "kidnap") ~ "f1",
                str_detect(description, "rape") ~ "f1",
                str_detect(description, "sex.*ass.*l|sexual aslt") ~ "f",
                str_detect(description, "reckless.*endanger") ~ "m2",
                str_detect(description, "identity theft") ~ "f",
                str_detect(description, "indecent exposure") ~ "m",
                str_detect(description, "vand.*educ") ~ "f3",
                str_detect(description, "solicit.*patronizing.*prostitutes|solicit prom pros-(loiter|prost)") ~ "m2",
                str_detect(description, "possession of firearm prohibited") ~ "m",
                str_detect(description, "bui.*first|bui: bac|alcohol in breath") ~ "m",
                str_detect(description, "operating watercraft.*alcohol|ope watercraft under|operate boat dui") ~ "m",
                str_detect(description, "liquefied ammonia") ~ "m",
                # Various types of marijuana possession.
                charge_id %in% c("35_780-113_a31i", "35_780-113_a31ii", "35_780-113_a31iii", "35_780-113_a3ii") ~ "m",
                # Possession of illegal substances with intention to distribute.
                charge_id %in% c("35_780-113_a35", "35_780-113_a3o") | str_detect(description, "int to man") ~ "f",
                # Distributing controlled substances to minors.
                charge_id == "35_780-114" ~ "m2",
                # Use/possession of druga paraphernalia.
                charge_id == "35_780_a32" ~ "m",
                str_detect(description, "procure for self/other drug by fraud") ~ "f",
                str_detect(description, "driving while bac .02 or greater while license susp") ~ "m",
                # Accident involving injury while not properly licensed.
                charge_id %in% c("75_3742.1_a", "75_3742.1_b1", "75_3742.1_b2") ~ "m",
                # Driving under the influence of a controlled substance.
                str_detect(charge_id, '75_3802_d1*') ~ "f3",
                str_detect(description, "tamper.*w/ignition") ~ "m",
                # Habitual traffic offenders.
                charge_id %in% c("75_6503_a", "75_6503_b", "75_6503_b1", "75_6503_") | str_detect(charge_id, "75_6503") ~ "m2",
                # Fraudulent vehicle/license papers.
                charge_id %in% c("75_7122_", "75_7122_1", "75_7122_2", "75_7122_3") ~ "m1",
                str_detect(description, "refuse to move-obstruct highway") ~ "m3",
                str_detect(description, "poss.*w/int|pwi|poss with intent|int manuf or del|poss w/i to man|poss w/i") ~ "f",
                str_detect(description, "agricultural trespasser") ~ "m",
                str_detect(description, "abandon.*dog") ~ "m",
                str_detect(description, "acc involving death" ) ~ "f",
                str_detect(description, "acc.*dam.*to.*unattend.*veh|accidents.*involv.*damage") ~ "m",
                str_detect(statute, "35.*780 113.*a30") ~ "f",
                # DUI
                str_detect(charge_id, "75_1543_b1") ~ "m",
                # Small amout of drug possession.
                str_detect(charge_id, "780.*(31|32)") ~ "m",
                # Possession with intent to distribute.
                str_detect(charge_id, "35.*780.*113.*30") ~ "f",
                # Child abuse.
                str_detect(charge_id, "18.*6312") ~ "f",
                str_detect(description, "purpose of prostitution|solicit.*prom.*pros") ~ "m2"
            )
    )

charges_fixed_by_hand <-
    charges_by_hand |>
    filter(!is.na(grade)) |>
    mutate(
        match = "no grade - fixed by hand",
        max_grade = grade,
        min_grade = grade
    ) |>
    select(-grade, -new_charge_id)

charges_not_fixed_by_hand <-
    charges_by_hand |>
    filter(is.na(grade)) |>
    mutate(
        match = "no grade - not fixed by hand",
        max_grade = "missing",
        min_grade = "missing"
    ) |>
    select(-grade, -new_charge_id)

###################################### Assemble all the criminal history tables.
criminal_history_charges_final <-
    bind_rows(
        criminal_history_has_grade, criminal_history_missing_grade_stars_match,
        criminal_history_missing_grade_match_charge_id,
        charges_fixed_by_hand, charges_not_fixed_by_hand
    )

criminal_history_summary <-
    criminal_history_charges_final |>
    lazy_dt(key_by = c(L1, L2)) |>
    group_by(L1, L2) |>
    summarise(
        nr_charges = n(),
        nr_h1_max = sum(max_grade == "h1"),
        nr_h2_max = sum(max_grade == "h2"),
        nr_f1_max = sum(max_grade == "f1"),
        nr_f2_max = sum(max_grade == "f2"),
        nr_f3_max = sum(max_grade == "f3"),
        nr_f_max = sum(max_grade == "f"),
        nr_m1_max = sum(max_grade == "m1"),
        nr_m2_max = sum(max_grade == "m2"),
        nr_m3_max = sum(max_grade == "m3"),
        nr_m_max = sum(max_grade == "m"),
        nr_h1_min = sum(min_grade == "h1"),
        nr_h2_min = sum(min_grade == "h2"),
        nr_f1_min = sum(min_grade == "f1"),
        nr_f2_min = sum(min_grade == "f2"),
        nr_f3_min = sum(min_grade == "f3"),
        nr_f_min = sum(min_grade == "f"),
        nr_m1_min = sum(min_grade == "m1"),
        nr_m2_min = sum(min_grade == "m2"),
        nr_m3_min = sum(min_grade == "m3"),
        nr_m_min = sum(min_grade == "m"),
        nr_missing = sum(min_grade == "missing"),
        nr_summary = sum(str_detect(max_grade, "^s[1-9]*$")),
        nr_other =
            sum(
                !(
                    max_grade %in%
                        c(
                            "h1", "h2", "f1", "f2", "f3", "f", "m1", "m2", "m3",
                            "m", "s1", "s2", "s3", "s4", "s5", "s", "s6", "s7",
                            "s8", "s9", "missing"
                        )
                )
            )
    ) |>
    ungroup() |>
    mutate(
        nr_felonies_max = rowSums(across(matches("*nr_(h|f)[1-3]*_max"))),
        nr_felonies_min = rowSums(across(matches("*nr_(h|f)[1-3]*_min"))),
        nr_misd_max = rowSums(across(matches("*nr_m[1-3]*_max"))),
        nr_misd_min = rowSums(across(matches("*nr_m[1-3]*_min")))
    ) |>
    as_tibble()

################################################################################
# Aggregate criminal history to the case level.
################################################################################
criminal_history <-
    criminal_history_summary |>
    full_join(criminal_history_cases_df, by = c("L1", "L2")) |>
    mutate(
        across(matches("nr_"), function(col) {if_else(is.na(col), 0, col)})
    ) |>
    separate_wider_delim(
        cols = L1,
        delim = "_",
        names =
            c(
                "pdf_type", "master_county", "court_type", "court_id",
                "hearing_type", "case_id", "master_year"
            ),
        cols_remove = F
    ) |>
    mutate(
        master_docket_nr =
            tolower(
                paste(
                    court_type, court_id, hearing_type, case_id, master_year,
                    sep = "-"
                )
            )
    ) |>
    select(-pdf_type, -court_type, -court_id, -hearing_type, -case_id) |>
    rename_with(function(col) {paste0("prior_", col)}, matches("nr_"))

write_csv(criminal_history, file.path(dir, "cs_MJ_CR_criminal_history.csv"))
