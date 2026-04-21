library(here)
library(readr)
library(dplyr)
library(purrr)
library(broom)
library(stringr)
library(flextable)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")
icc_df <- read_csv(file.path(read_dir, "icc_df.csv"))
models <- readRDS(here("output", "analysis", "model_output", "null_models.rds"))

################################################################################
# Conduct Chi-Squared LR tests.
################################################################################
conduct_lr_test <- function(model1, model2, compare_str) {
    anova(model1, model2) |> tidy() |> mutate(comparison = compare_str)
}

lr_tests <-
    pmap(
        list(
            list(
                models$judge, models$judge, models$judge,
                models$defense, models$defense,
                models$prosecutor, models$prosecutor,
                models$judge_defense, models$judge_prosecutor,
                models$judge_defense_dyad, models$judge_prosecutor_dyad,
                models$judge_defense_prosecutor,
                models$judge_defense_prosecutor_dyads
            ),
            list(
                models$judge_defense, models$judge_prosecutor, models$judge_defense_prosecutor,
                models$judge_defense, models$judge_defense_prosecutor,
                models$judge_prosecutor, models$judge_defense_prosecutor,
                models$judge_defense_dyad, models$judge_prosecutor_dyad,
                models$judge_defense_prosecutor_dyads, models$judge_defense_prosecutor_dyads,
                models$judge_defense_prosecutor_dyads,
                models$judge_defense_prosecutor_triad
            ),
            list(
                "judge_vs_judgeDefense", "judge_vs_judgeProsecutor", "judge_vs_judgeDefenseProsecutor",
                "defense_vs_judgeDefense", "defense_vs_judgeDefenseProsecutor",
                "prosecutor_vs_judgeProsecutor", "prosecutor_vs_judgeDefenseProsecutor",
                "judgeDefense_vs_Dyad", "judgeProsecutor_vs_Dyad",
                "judgeDefenseDyad_vs_AllDyads", "judgeProsecutorDyad_vs_AllDyads",
                "judgeDefenseProsecutor_vs_AllDyads",
                "dyads_vs_triads"
            )
        ),
        conduct_lr_test
    ) |>
    bind_rows()

################################################################################
# Create ICC tables for paper.
################################################################################
icc_table <-
    icc_df |>
    filter(!(model %in% c("defense_prosecutor", "defense_prosecutor_dyad"))) |>
    mutate(
        model =
            case_when(
                model == "judge" ~ "Model 1",
                model == "defense" ~ "Model 2",
                model == "prosecutor" ~ "Model 3",
                model == "judge_defense" ~ "Model 4",
                model == "judge_prosecutor" ~ "Model 5",
                model == "judge_defense_prosecutor" ~ "Model 6",
                model == "judge_defense_dyad" ~ "Model 7",
                model == "judge_prosecutor_dyad" ~ "Model 8",
                model == "judge_defense_prosecutor_dyads" ~ "Model 9",
                model == "judge_defense_prosecutor_triad" ~ "Model 10"
            )
    ) |>
    rename(
        "Model" = "model",
        "Judge" = "judge_assigned",
        "Defense" = "main_defense",
        "Prosecutor" = "main_prosecutor",
        "Judge + Defense Dyad" = "judge_defense_dyad",
        "Judge + Prosecutor Dyad" = "judge_prosecutor_dyad",
        "Defense + Prosecutor Dyad" = "defense_prosecutor_dyad",
        "Judge + Prosecutor + Defense Triad" = "judge_defense_prosecutor_triad"
    ) |>
    mutate(
        across(where(is.numeric), function(col) {as.character(signif(col, 4))}),
        across(everything(), function(col) {if_else(is.na(col), "-", col)})
    )

table1 <- icc_table |> filter(str_detect(Model, "\\b[1-6]\\b"))
table2 <- icc_table |> filter(str_detect(Model, "4|7"))
table3 <- icc_table |> filter(str_detect(Model, "5|8"))
table4 <- icc_table |> filter(str_detect(Model, "6|9|10"))

icc_tables <-
    bind_rows(table1, table2, table3, table4) |>
    mutate(
        id = row_number(),
        group =
            case_when(
                id <= 3 ~ "Panel A: Single-actor",
                id >= 4 & id <= 6 ~ "Panel B: Multiple actors (no dyads)",
                id >= 7 & id <= 8 ~ "Panel C: Judge + Defense Dyads",
                id >= 9 & id <= 10 ~ "Panel D: Judge + Prosecutor Dyads",
                id >= 11 & id <= 13 ~ "Panel E: All Dyads + Triad"
            )
    ) |>
    select(-id)

icc_flextable <-
    icc_tables |>
    as_grouped_data(groups = "group") |>
    as_flextable() |>
    compose(j = 1, i = ~ !is.na(group), value = as_paragraph(as_chunk(group))) |>
    bold(j = 1, i = ~ !is.na(group), bold = T, part = "body") |>
    width(j = 1, width = 2) |>
    fontsize(size = 8, part = "all") |>
    set_table_properties(layout = "fixed")

save_as_docx(icc_flextable, path = file.path(write_dir, "icc_table.docx"))
