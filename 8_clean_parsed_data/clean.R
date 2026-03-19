library(here)
library(purrr)
library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(stringr)
library(jsonlite)

################################################################################
dir <- "/home/joe/Documents/secret_lives_pa/output/pdf_parse_list/json"
list_of_files <- list.files(dir)
list_of_json <-
    map(
        list_of_files,
        function(file, path) {read_json(file.path(path, file))},
        path = dir
    )

nr_lawyers <-
    map(list_of_json, function(json) {length(json$attorney_info)}) |> unlist()
nr_bail <-
    map(list_of_json, function(json) {length(json$bail$bail_info)}) |> unlist()

capture_lawyer_attr <- function(json, lawyer_nr, attribute) {
    if(is.null(json$attorney_info[[lawyer_nr]][[attribute]]))
        return("")
    else
        return(trimws(json$attorney_info[[lawyer_nr]][[attribute]]))
}

capture_bail_attr <- function(json, bail_nr, attribute) {
    if(is.null(json$bail$bail_info[[bail_nr]][[attribute]]))
        return("")
    else
        return(trimws(json$bail$bail_info[[bail_nr]][[attribute]]))
}

data_df <-
    tibble(
        id = 1:length(nr_lawyers),
        judge =
            list_of_json |>
            map(function(json) {json$case_info$judge_assigned}) |>
            unlist(),
        lawyer_one_name =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_0",
                attribute = "name"
            ) |>
            unlist(),
        lawyer_one_type =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_0",
                attribute = "type"
            ) |>
            unlist(),
        lawyer_two_name =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_1",
                attribute = "name"
            ) |>
            unlist(),
        lawyer_two_type =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_1",
                attribute = "type"
            ) |>
            unlist(),
        lawyer_three_name =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_2",
                attribute = "name"
            ) |>
            unlist(),
        lawyer_three_type =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_2",
                attribute = "type"
            ) |>
            unlist(),
        lawyer_four_name =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_3",
                attribute = "name"
            ) |>
            unlist(),
        lawyer_four_type =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_3",
                attribute = "type"
            ) |>
            unlist(),
        lawyer_five_name =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_4",
                attribute = "name"
            ) |>
            unlist(),
        lawyer_five_type =
            map(
                list_of_json,
                capture_lawyer_attr,
                lawyer_nr = "lawyer_nr_4",
                attribute = "type"
            ) |>
            unlist(),
        bail_one_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_0",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_one_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_0",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_one_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_0",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_one_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_0",
                attribute = "amount"
            ) |>
            unlist(),
        bail_two_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_1",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_two_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_1",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_two_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_1",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_two_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_1",
                attribute = "amount"
            ) |>
            unlist(),
        bail_three_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_2",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_three_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_2",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_three_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_2",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_three_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_2",
                attribute = "amount"
            ) |>
            unlist(),
        bail_four_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_3",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_four_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_3",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_four_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_3",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_four_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_3",
                attribute = "amount"
            ) |>
            unlist(),
        bail_five_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_4",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_five_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_4",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_five_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_4",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_five_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_4",
                attribute = "amount"
            ) |>
            unlist(),
        bail_six_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_5",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_six_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_5",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_six_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_5",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_six_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_5",
                attribute = "amount"
            ) |>
            unlist(),
        bail_seven_action =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_6",
                attribute = "bail_action"
            ) |>
            unlist(),
        bail_seven_type =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_6",
                attribute = "bail_type"
            ) |>
            unlist(),
        bail_seven_percentage =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_6",
                attribute = "percentage"
            ) |>
            unlist(),
        bail_seven_amount =
            map(
                list_of_json,
                capture_bail_attr,
                bail_nr = "bail_nr_6",
                attribute = "amount"
            ) |>
            unlist()
    )

################################################################################
list_of_json <-
    readRDS(here("output", "pdf_parse_list", "flattened_json_ds_mj.rds")) |>
    group_by(L1) |>
    filter(any(value == "centre")) |>
    ungroup() |>
    filter(
        (L2 == "attorney_info" & L4 == "name") |
            (L2 == "attorney_info" & L4 == "type") |    
            L3 == "judge_assigned" |
            L3 == "bail_info" & L5 == "bail_action" |
            L3 == "bail_info" & L5 == "bail_type"
    ) |>
    mutate(
        L3 = if_else(L3 == "bail_info", L4, L3),
        L4 = if_else(str_detect(L4, "bail_nr_"), L5, L4)
    ) |>
    pivot_wider(
        id_cols = "L1", names_from = c("L3", "L4"), values_from = "value"
    ) |>
    select(-matches("bail_nr_[1-9]")) |>
    rename("judge" = "judge_assigned_NA")

data_df_cleaned <-
    list_of_json |>
    filter(
        bail_nr_0_bail_action != "" & bail_nr_0_bail_action != "common pleas - revoke",
        lawyer_nr_0_name != "" | lawyer_nr_1_name != "" | lawyer_nr_2_name != "" | lawyer_nr_3_name != "" | lawyer_nr_4_name != ""
    ) |>
    mutate(
        bail_one_type =
            case_when(
                bail_nr_0_bail_type == "ror - common pleas" ~ "ROR",
                bail_nr_0_bail_type == "" ~ "Denied",
                bail_nr_0_bail_type == "nonmonetary" ~ "Unsecured or Non-monetary",
                bail_nr_0_bail_type == "unsecured" ~ "Unsecured or Non-monetary",
                bail_nr_0_bail_type == "monetary" ~ "Monetary",
                bail_nr_0_bail_type == "ror" ~ "ROR",
                T ~ bail_nr_0_bail_type
            ),
        prosecutor =
            case_when(
                lawyer_nr_0_type == "assistant district attorney" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "district attorney" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "attorney general" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "special prosectuor" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "complainant's attorney" ~ lawyer_nr_0_name
            ),
        defense =
            case_when(
                lawyer_nr_0_type == "private" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "public defender" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "court appointed" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "conflict counsel" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "court appointed - public defender" ~ lawyer_nr_0_name,
                lawyer_nr_0_type == "court appointed - private" ~ lawyer_nr_0_name
            ),
        prosecutor =
            case_when(
                lawyer_nr_1_type == "assistant district attorney" & is.na(prosecutor) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "district attorney" & is.na(prosecutor) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "attorney general" & is.na(prosecutor) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "special prosectuor" & is.na(prosecutor) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "complainant's attorney" & is.na(prosecutor) ~ lawyer_nr_1_name,
                !is.na(prosecutor) ~ prosecutor
            ),
        defense =
            case_when(
                lawyer_nr_1_type == "private" & is.na(defense) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "public defender" & is.na(defense) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "court appointed" & is.na(defense) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "conflict counsel" & is.na(defense) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "court appointed - public defender" & is.na(defense) ~ lawyer_nr_1_name,
                lawyer_nr_1_type == "court appointed - private" & is.na(defense) ~ lawyer_nr_1_name,
                !is.na(defense) ~ defense
            ),
        prosecutor =
            case_when(
                lawyer_nr_2_type == "assistant district attorney" & is.na(prosecutor) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "district attorney" & is.na(prosecutor) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "attorney general" & is.na(prosecutor) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "special prosectuor" & is.na(prosecutor) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "complainant's attorney" & is.na(prosecutor) ~ lawyer_nr_2_name,
                !is.na(prosecutor) ~ prosecutor
            ),
        defense =
            case_when(
                lawyer_nr_2_type == "private" & is.na(defense) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "public defender" & is.na(defense) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "court appointed" & is.na(defense) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "conflict counsel" & is.na(defense) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "court appointed - public defender" & is.na(defense) ~ lawyer_nr_2_name,
                lawyer_nr_2_type == "court appointed - private" & is.na(defense) ~ lawyer_nr_2_name,
                !is.na(defense) ~ defense
            ),
        prosecutor =
            case_when(
                lawyer_nr_3_type == "assistant district attorney" & is.na(prosecutor) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "district attorney" & is.na(prosecutor) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "attorney general" & is.na(prosecutor) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "special prosectuor" & is.na(prosecutor) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "complainant's attorney" & is.na(prosecutor) ~ lawyer_nr_3_name,
                !is.na(prosecutor) ~ prosecutor
            ),
        defense =
            case_when(
                lawyer_nr_3_type == "private" & is.na(defense) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "public defender" & is.na(defense) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "court appointed" & is.na(defense) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "conflict counsel" & is.na(defense) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "court appointed - public defender" & is.na(defense) ~ lawyer_nr_3_name,
                lawyer_nr_3_type == "court appointed - private" & is.na(defense) ~ lawyer_nr_3_name,
                !is.na(defense) ~ defense
            ),
        prosecutor =
            case_when(
                lawyer_nr_4_type == "assistant district attorney" & is.na(prosecutor) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "district attorney" & is.na(prosecutor) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "attorney general" & is.na(prosecutor) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "special prosectuor" & is.na(prosecutor) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "complainant's attorney" & is.na(prosecutor) ~ lawyer_nr_4_name,
                !is.na(prosecutor) ~ prosecutor
            ),
        defense =
            case_when(
                lawyer_nr_4_type == "private" & is.na(defense) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "public defender" & is.na(defense) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "court appointed" & is.na(defense) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "conflict counsel" & is.na(defense) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "court appointed - public defender" & is.na(defense) ~ lawyer_nr_4_name,
                lawyer_nr_4_type == "court appointed - private" & is.na(defense) ~ lawyer_nr_4_name,
                !is.na(defense) ~ defense
            ),
        prosecutor =
            case_when(
                prosecutor == "jason s dunkle, esq." ~ "jason dunkle",
                prosecutor == "jason s. dunkle, esq." ~ "jason dunkle",
                prosecutor == "joshua s maines, esq."  ~ "joshua maines",
                prosecutor == "joshua s. maines, esq."   ~ "joshua maines",
                prosecutor == "andrew joseph stover, esq."   ~ "andrew stover",
                prosecutor == "andrew stover, esq."   ~ "andrew stover",
                T ~ prosecutor
            ),
        defense =
            case_when(
                defense == "jason s dunkle, esq." ~ "jason dunkle",
                defense == "jason s. dunkle, esq." ~ "jason dunkle",
                defense == "joshua s maines, esq."  ~ "joshua maines",
                defense == "joshua s. maines, esq."   ~ "joshua maines",
                defense == "andrew joseph stover, esq."   ~ "andrew stover",
                defense == "andrew stover, esq."   ~ "andrew stover",
                T ~ defense
            ),
    ) |>
    select(-bail_nr_0_bail_action) |>
    group_by(judge) |>
    mutate(judge_id = paste0("Judge ", cur_group_id())) |>
    ungroup() |>
    group_by(prosecutor) |>
    mutate(
        prosecutor_id = paste0("Prosecutor ", cur_group_id()),
        prosecutor_id = if_else(is.na(prosecutor), NA, prosecutor_id)
    ) |>
    ungroup() |>
    group_by(defense) |>
    mutate(
        defense_id = paste0("Defense ", cur_group_id()),
        defense_id = if_else(is.na(defense), NA, defense_id)
    ) |>
    ungroup()

judge <-
    data_df_cleaned |>
    count(judge_id, bail_one_type) |>
    group_by(judge_id) |>
    mutate(prop = n / sum(n)) |>
    ungroup()

ggplot(judge, aes(x = judge_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    theme_bw() +
    labs(
        x = "Judge",
        y = "Proportion",
        fill = "Bail type"
    ) +
    theme(
        axis.text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.title = element_text(size = 15)
    )

judge_prosecutor <-
    data_df_cleaned |>
    filter(!is.na(prosecutor_id)) |>
    count(judge_id, prosecutor_id)

a <-
    judge_prosecutor |>
    arrange(-n) |>
    mutate(cumsum = cumsum(n), prcnt = cumsum / sum(n))

judge_prosecutor <-
    data_df_cleaned |>
    filter(!is.na(prosecutor_id)) |>
    group_by(judge_id, prosecutor_id) |>
    filter(n() >= 40) |>
    count(judge_id, prosecutor_id, bail_one_type) |>
    group_by(judge_id, prosecutor_id) |>
    mutate(prop = n / sum(n)) |>
    ungroup()

ggplot(judge_prosecutor, aes(x = prosecutor_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Prosecutor",
        y = "Proportion",
        fill = "Bail type"
    ) +
    theme(
        axis.text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.title = element_text(size = 15),
        strip.text = element_text(size = 15)
    ) +
    coord_flip()

judge_defense <-
    data_df_cleaned |>
    filter(!is.na(defense_id)) |>
    count(judge_id, defense_id)

a <-
    judge_defense |>
    arrange(-n) |>
    mutate(cumsum = cumsum(n), prcnt = cumsum / sum(n))

judge_defense <-
    data_df_cleaned |>
    filter(!is.na(defense_id)) |>
    group_by(judge_id, defense_id) |>
    filter(n() >= 25) |>
    count(judge_id, defense_id, bail_one_type) |>
    group_by(judge_id, defense_id) |>
    mutate(prop = n / sum(n)) |>
    ungroup()

ggplot(judge_defense, aes(x = defense_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Defense",
        y = "Proportion",
        fill = "Bail type"
    ) +
    coord_flip() +
    theme(
        axis.text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.title = element_text(size = 15),
        strip.text = element_text(size = 15)
    )

judge_prosecutor_defense <-
    data_df_cleaned |>
    filter(!is.na(defense_id), !is.na(prosecutor_id)) |>
    count(judge_id, defense_id, prosecutor_id)

a <-
    judge_prosecutor_defense |>
    arrange(-n) |>
    mutate(cumsum = cumsum(n), prcnt = cumsum / sum(n))

judge_prosecutor_defense <-
    data_df_cleaned |>
    filter(!is.na(defense_id), !is.na(prosecutor_id)) |>
    group_by(judge_id, defense_id, prosecutor_id) |>
    filter(n() >= 10) |>
    count(judge_id, defense_id, bail_one_type) |>
    group_by(judge_id, defense_id) |>
    mutate(prop = n / sum(n)) |>
    ungroup()

ggplot(judge_prosecutor_defense, aes(x = defense_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id+prosecutor_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Defense",
        y = "Proportion",
        fill = "Bail type"
    ) +
    coord_flip() +
    theme(
        axis.text = element_text(size = 9),
        legend.text = element_text(size = 13),
        axis.title = element_text(size = 10),
        strip.text = element_text(size = 12)
    )

judge_prosecutor_defense |>
    filter(
        judge_id == "Judge 3" | judge_id == "Judge 5",
        prosecutor_id == "Prosecutor 12"
    ) |>
    ggplot(aes(x = defense_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id+prosecutor_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Defense",
        y = "Proportion",
        fill = "Bail type"
    ) +
    coord_flip() +
    theme(
        axis.text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.title = element_text(size = 15),
        strip.text = element_text(size = 15)
    )

ggplot(judge_prosecutor_defense, aes(x = prosecutor_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id+defense_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Prosecutor",
        y = "Proportion",
        fill = "Bail type"
    ) +
    coord_flip() +
    theme(
        axis.text = element_text(size = 9),
        legend.text = element_text(size = 13),
        axis.title = element_text(size = 13),
        strip.text = element_text(size = 12)
    )

judge_prosecutor_defense |>
    filter(
        judge_id == "Judge 3" | judge_id == "Judge 5",
        defense_id == "Defense 155"
    ) |>
    ggplot(aes(x = prosecutor_id, y = prop)) +
    geom_bar(aes(fill = bail_one_type), position = "fill", stat = "identity") +
    facet_wrap(~judge_id+defense_id, scales = "free_y") +
    theme_bw() +
    labs(
        x = "Prosecutor",
        y = "Proportion",
        fill = "Bail type"
    ) +
    coord_flip() +
    theme(
        axis.text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.title = element_text(size = 15),
        strip.text = element_text(size = 15)
    )
