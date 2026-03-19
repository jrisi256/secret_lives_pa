library(here)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)

################################################################################
# Read in flattened json file.
################################################################################
flattened_json_ds_mj <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds"))

################################################################################
# Clean bail information.
################################################################################
bail_df <-
    flattened_json_ds_mj |>
    filter(L3 == "bail_info") |>
    pivot_wider(
        id_cols = c("L1", "L4"),
        names_from = "L5",
        values_from = "value"
    ) |>
    mutate(bail_action = trimws(bail_action)) |>
    filter(
        (bail_action == "set" | bail_action == "denied") & originating_court != "common pleas"
    ) |>
    mutate(bail_nr = as.numeric(str_extract(L4, "[0-9]+"))) |>
    group_by(L1) |>
    filter(bail_nr == min(bail_nr)) |>
    ungroup() |>
    mutate(
        bail_type = trimws(bail_type),
        bail_decision =
            case_when(
                bail_action == "denied" ~ "denied",
                bail_type == "ror" ~ "ROR",
                bail_type == "nonmonetary" ~ "Non-monetary",
                bail_type == "unsecured" ~ "Unsecured",
                bail_type == "monetary" ~ "Monetary",
                bail_type == "nominal" ~ "Monetary"
            )
    ) |>
    select(-L4, -bail_action, -bail_type, -originating_court, -bail_nr) |>
    mutate(
        percentage = 
            if_else(
                percentage == "",
                1,
                as.numeric(str_replace_all(percentage, "%", "")) / 100
            ),
        amount = as.numeric(str_replace_all(amount, "\\$|,", "")),
        effective_amount = if_else(is.na(percentage), amount, percentage * amount),
        amount = if_else(bail_decision == "ROR" & amount > 0, 0, amount),
        percentage = if_else(bail_decision == "ROR" & percentage < 1, 1, percentage),
        bail_decision_bin =
            if_else(
                bail_decision == "ROR" | bail_decision == "Non-monetary",
                "Effectively no bail",
                "Effectively bail or detained"
            )
    ) |>
    filter(
        (bail_decision == "Monetary" & amount > 0) |
            (bail_decision == "Non-monetary" & amount == 0) |
            (bail_decision != "Monetary" & bail_decision != "Non-monetary")
    ) |>
    select(-date)

################################################################################
# Save results.
################################################################################
write_csv(bail_df, here("output", "final_data", "ds_MJ_CR_bail.csv"))
