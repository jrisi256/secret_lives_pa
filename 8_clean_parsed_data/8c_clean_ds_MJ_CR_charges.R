library(here)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)

################################################################################
# Read in flattened json file.
################################################################################
flattened_json_ds_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds"))

################################################################################
# Read in code book.
################################################################################
calc_ogs_score <- function(col, fn) {
    if(any(is.na(as.numeric(col)))) {
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
    # None of our recorded charges involve eco-terrorism. Would be hard to 
    # clean, so we drop them for now.
    filter(!str_detect(Description, "Ecoterrorism")) |>
    # For charges w/ the same id + class, calculate the mean, min, and max OGS.
    group_by(charge_id, `Statutory Class`) |>
    summarise(
        mean_ogs_score = calc_ogs_score(`Offense Gravity Score`, "mean"),
        max_ogs_score = calc_ogs_score(`Offense Gravity Score`, "max"),
        min_ogs_score = calc_ogs_score(`Offense Gravity Score`, "min")
    ) |>
    mutate(omni_ogs_score = mean_ogs_score) |>
    ungroup()

################################################################################
# Clean charge information.
################################################################################
charges_df <-
    flattened_json_ds_mj |>
    filter(L2 == "charges") |>
    pivot_wider(
        id_cols = c("L1", "L3"),
        names_from = "L4",
        values_from = "value"
    ) |>
    mutate(
        charge = str_replace_all(trimws(charge), "\\s+", ""),
        charge_id = str_replace_all(charge, "§+", "_")
    )

################################################################################
# Partition out summary offenses, matched charges, and unmatched charges.
################################################################################
charges_summary <-
    charges_df |>
    filter(str_detect(grade, "s[0-9]{0,1}")) |>
    mutate(
        mean_ogs_score = "0",
        max_ogs_score = "0",
        min_ogs_score = "0",
        omni_ogs_score = "0",
        match = "summary charge"
    )

charges_matching <-
    charges_df |>
    inner_join(codebook_cleaned, by = c("charge_id", "grade" = "Statutory Class")) |>
    mutate(match = "initial match")

charges_non_matching <-
    charges_df |>
    filter(
        grade != "", grade != "none", grade != "0", grade != "ic",
        !(str_detect(grade, "s[0-9]{0,1}"))
    ) |>
    anti_join(codebook_cleaned, by = c("charge_id", "grade" = "Statutory Class"))

################################################################################
# Try and match non-matched offenses (with a grade) by removing/adding stars.
################################################################################
charges_stars <-
    charges_non_matching |>
    mutate(
        new_charge_id =
            if_else(
                str_detect(charge_id, "\\*"),
                str_replace_all(charge_id, "\\*", ""),
                paste0(charge_id, "*")
            )
    )
    
charges_stars_fixed <-
    charges_stars |>
    inner_join(
        codebook_cleaned,
        by = c("new_charge_id" = "charge_id", "grade" = "Statutory Class")
    ) |>
    mutate(match = "initial match - stars")

charges_stars_not_fixed <-
    charges_stars |>
    anti_join(
        codebook_cleaned,
        by = c("new_charge_id" = "charge_id", "grade" = "Statutory Class")
    )

################################################################################
# Use omnibus OGS scores for those we cannot match based on charge ID.
################################################################################
codebook_by_grade <-
    codebook_charge_id |>
    filter(!is.na(as.numeric(`Offense Gravity Score`))) |>
    mutate(ogs_nr = as.numeric(`Offense Gravity Score`)) |>
    group_by(`Statutory Class`) |>
    summarise(
        mean_ogs_score = as.character(mean(ogs_nr)),
        max_ogs_score = as.character(max(ogs_nr)),
        min_ogs_score = as.character(min(ogs_nr))
    ) |>
    ungroup() |>
    mutate(
        omni_ogs_score =
            case_when(
                `Statutory Class` == "f1" ~ "9",
                `Statutory Class` == "f2" ~ "7",
                `Statutory Class` == "f3" ~ "5",
                `Statutory Class` == "m1" ~ "3",
                `Statutory Class` == "m2" ~ "2",
                `Statutory Class` == "m3" ~ "1",
                `Statutory Class` == "f" ~ "5",
                `Statutory Class` == "m" ~ "1",
                T ~ mean_ogs_score
            )
    )

charges_fixed_by_omnibus <-
    charges_stars_not_fixed |>
    left_join(codebook_by_grade, by = c("grade" = "Statutory Class")) |>
    mutate(match = "initial match - grade")

################################################################################
# Match only on charge ID for those charges that do not have a grade.
################################################################################
charges_no_grade <-
    charges_df |>
    filter(grade == "" | grade == "none" | grade == "0" | grade == "ic")

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
        mean_ogs_score = calc_ogs_score(`Offense Gravity Score`, "mean"),
        max_ogs_score = calc_ogs_score(`Offense Gravity Score`, "max"),
        min_ogs_score = calc_ogs_score(`Offense Gravity Score`, "min"),
        max_grade = max(`Statutory Class`),
        min_grade = min(`Statutory Class`)
    ) |>
    mutate(omni_ogs_score = mean_ogs_score) |>
    ungroup()

charges_no_grade_matching <-
    charges_no_grade |>
    inner_join(codebook_by_charge, by = "charge_id") |>
    mutate(match = "no grade - match on charge")

charges_no_grade_non_matching <-
    charges_no_grade |>
    anti_join(codebook_by_charge, by = "charge_id")

##### Try and match non-matched offenses (w/ no grade) by removing/adding stars.
charges_no_grade_stars <-
    charges_no_grade_non_matching |>
    mutate(
        new_charge_id =
            if_else(
                str_detect(charge_id, "\\*"),
                str_replace_all(charge_id, "\\*", ""),
                paste0(charge_id, "*")
            )
    )

charges_no_grade_stars_fixed <-
    charges_no_grade_stars |>
    inner_join(codebook_by_charge, by = c("new_charge_id" = "charge_id")) |>
    mutate(match = "no grade - stars")

charges_no_grade_stars_not_fixed <-
    charges_no_grade_stars |>
    anti_join(codebook_by_charge, by = c("new_charge_id" = "charge_id"))

################################ Try and fix the one that did not match by hand.
# Summary + traffic (e.g., loitering, public drunkenness).
# Unclassified, blank, or too vague (e.g., precious metals, crime w/ firearm, criminal attempt).
# Too broad --> theft, criminal conspiracy, tampering with records, escape,
# trademark counterfeit, illegal device access, intimidation, prostitution,
# receiving stolen property, forgery, dissemination of obscene materials,
# interference with custody of children, retaliation, fraud in SNAP,
# violation or contempt of orders, unspecified conspiracy or criminal attempt,
# arrest prior to requisition, home improvement contractor issues,
# vehicle/traffic issues (e.g., no license, no registration),
# failure to provide worker's compensation.
charges_by_hand <-
    charges_no_grade_stars_not_fixed |>
    mutate(
        description = str_replace(description, "\\s{10,}.*", ""),
        grade =
            case_when(
                str_detect(description, "false id.*") ~ "m3",
                str_detect(description, "murder|homicide of unborn child") ~ "h1",
                str_detect(description, "criminal homicide|homicide") ~ "f1",
                str_detect(description, "simple assault") ~ "m",
                str_detect(description, "officer - firearm discharged") ~ "f1",
                str_detect(description, "assault of law|agg.* assaul|assault by prisoner|aggrav.* asslt|ind.*ass.*l") ~ "f",
                str_detect(description, "terroristic threats") ~ "f",
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
                str_detect(description, "criminal mischief") ~ "m",
                str_detect(description, "burglary") | charge_id == "18_3502_a" ~ "f1",
                str_detect(description, "crim.*tres|def.* tres") & str_detect(charge_id, "b") ~ "m",
                str_detect(description, "crim.*tres|def.* tres") & str_detect(charge_id, "3503_a1") ~ "m",
                str_detect(description, "robbery") ~ "f1",
                str_detect(description, "fleeing or attempting") ~ "m2",
                str_detect(description, "bad check") ~ "m",
                str_detect(description, "incest") ~ "f2",
                str_detect(description, "endanger.*child") | charge_id %in% c("18_4304_a", "18_4304_b") ~ "f",
                str_detect(description, "tamper.*evidence") ~ "m",
                str_detect(description, "(inconsistent|false).* statement") ~ "m",
                str_detect(description, "falsely pretends") ~ "m",
                # failures to register, predominantly sex offenders.
                charge_id %in% c("18_4915_a1", "18_4915_a2", "18_4915_a3") ~ "f",
                str_detect(description, "disarming law enforce") ~ "f3",
                str_detect(description, "evading arrest") ~ "m2",
                str_detect(description, "hinder apprehen") ~ "f",
                str_detect(description, "disorderly conduct") ~ "m3",
                str_detect(description, "illegal to taunt police animal") ~ "f3",
                str_detect(description, "cr.* anim.*") ~ "m2",
                str_detect(description, "poss.*firearm.*fugitive") ~ "m1",
                str_detect(description, "poss.*firearm.*drug") ~ "f",
                str_detect(description, "not.*firearm.*(incompetent|alien)|mental health patient.*firearm") ~ "m1",
                str_detect(description, "not.*firearm.*delinquent") ~ "m1",
                str_detect(description, "not.*firearm|poss.*firearm") | str_detect(charge_id, "18_6105_(a|c)") ~ "m",
                str_detect(description, "penalty - felony") ~ "f",
                str_detect(description, "firearm without a license") ~ "f3",
                str_detect(description, "fails to relinquish firearm") ~ "m2",
                str_detect(description, "sales of firearms") ~ "f",
                str_detect(description, "corruption of minors") ~ "m",
                str_detect(description, "purch etc alcoh bev by a minor") ~ "m3",
                str_detect(description, "sexual abuse.* child") ~ "f",
                str_detect(description, "child sex|child porn|dissem photo") | charge_id == "18_6312_b1" ~ "f",
                str_detect(description, "contact.*minor") ~ "f3",
                str_detect(description, "invasion of privacy") ~ "m",
                str_detect(description, "criminal use of communication facility") ~ "f3",
                str_detect(description, "small amount.*mari|drug para|marijuana small amt|poss of marijuana") ~ "m",
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
                charge_id %in% c("75_6503_a", "75_6503_b", "75_6503_b1", "75_6503_") ~ "m2",
                # Fraudulent vehicle/license papers.
                charge_id %in% c("75_7122_", "75_7122_1", "75_7122_2", "75_7122_3") ~ "m1",
                str_detect(description, "refuse to move-obstruct highway") ~ "m3",
                str_detect(description, "poss.*w/int|pwi|poss with intent|int manuf or del|poss w/i to man|poss w/i") ~ "f",
                str_detect(description, "agricultural trespasser") ~ "m"
            )
    )
    
charges_fixed_by_hand <-
    charges_by_hand |>
    inner_join(codebook_by_grade, by = c("grade" = "Statutory Class")) |>
    mutate(match = "no grade - fixed by hand")

charges_not_fixed_by_hand <-
    charges_by_hand |>
    anti_join(codebook_by_grade, by = c("grade" = "Statutory Class")) |>
    mutate(match = "no grade - not fixed by hand")

################################################################################
# Combine all the different charges together.
################################################################################
charges_df_final <-
    bind_rows(
        charges_matching, charges_stars_fixed, charges_fixed_by_omnibus,
        charges_no_grade_matching, charges_no_grade_stars_fixed,
        charges_fixed_by_hand, charges_summary, charges_not_fixed_by_hand
    ) |>
    mutate(
        max_grade = if_else(is.na(max_grade), grade, max_grade),
        min_grade = if_else(is.na(min_grade), grade, min_grade)
    ) |>
    select(-L3, -nr, -charge_id, -new_charge_id, -grade)

write_csv(charges_df_final, here("output", "final_data", "ds_MJ_CR_charges.csv"))
