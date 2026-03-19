library(here)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)

################################################################################
# Read in flattened json file.
################################################################################
flattened_json_ds_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds"))

################################################################################
# Clean demographic information.
################################################################################
addr_pattern <- "[A-Za-z\\s\\-']+\\s*,\\s*[A-Za-z]{2}\\s*[0-9]{5}"

demographic_judge_df <-
    flattened_json_ds_mj |>
    mutate(
        L4 =
            if_else(
                (L3 == "address" | L3 == "address_type") & is.na(L4), "1", L4
            )
    ) |>
    filter(
        L3 %in%
            c(
                "sex", "dob", "race", "county", "township", "judge_assigned",
                "address", "address_type", "counsel", "defender_requested",
                "application_provided", "fingerprinted", "issue_date",
                "file_date", "arrest_date"
            )
    ) |>
    pivot_wider(
        id_cols = "L1", names_from = c("L3", "L4"), values_from = "value"
    ) |>
    rename_with(function(col) {str_replace(col, "_NA", "")}) |>
    mutate(
        address =
            case_when(
                # If the first address is a valid home address, use that one.
                address_type_1 == "Home" & str_detect(address_1, addr_pattern) ~ address_1,
                # If all addresses are invalid/missing, the address is missing.
                (!str_detect(address_1, addr_pattern) | is.na(address_1)) &
                    (!str_detect(address_2, addr_pattern) | is.na(address_2)) &
                    (!str_detect(address_3, addr_pattern) | is.na(address_3)) ~ "missing",
                # If the 1st address is invalid...
                # and the 2nd address is valid (regardless of home)...
                # use the 2nd address.
                !str_detect(address_1, addr_pattern) & str_detect(address_2, addr_pattern) ~ address_2,
                # If the 1st address is not home but the 2nd address is valid home...
                # use the 2nd address.
                address_type_1 != "Home" & address_type_2 == "Home" & str_detect(address_2, addr_pattern) ~ address_2,
                # If the 1st address is not a primary but the 2nd address is valid primary...
                # use the 2nd address.
                address_type_1 != "Primary" & address_type_2 == "Primary" & str_detect(address_2, addr_pattern) ~ address_2,
                # Slight error in the parser.
                # Basically, if the 3rd address type is one of the 3...
                # It is really referring to the 2nd address type.
                address_type_3 %in% c("Home", "Mailing", "Primary") & str_detect(address_2, addr_pattern) ~ address_2,
                # Same error as above. The parser lagged by one address, so to speak.
                address_type_2 == "Correctional" ~ address_1,
                # Same error as above. The parser lagged by one address, so to speak.
                address_type_2 %in% c("Facility", "Local", "1") & !is.na(address_2) ~ address_2,
                # Else just use address 1.
                T ~ address_1
            ),
        zip = str_extract(address, "[0-9]{5}"),
        sex = if_else(sex == "", "unreported/unknown", sex),
        race = if_else(race == "", "unknown/unreported", race),
        race_collapsed = case_when(
            race == "asian" ~ "Other",
            race == "asian/pacific islander" ~ "Other",
            race == "bi-racial" ~ "Other",
            race == "native american/alaskan native" ~ "Other",
            race == "native hawaiian/pacific islander" ~ "Other",
            T ~ race,
        ),
        dob = mdy(dob)
    ) |>
    select(-matches("address_"))

################################################################################
# Save results.
################################################################################
write_csv(
    demographic_judge_df,
    here("output", "final_data", "ds_MJ_CR_demo_judge.csv")
)
