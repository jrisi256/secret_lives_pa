library(here)
library(lme4)
library(dplyr)
library(rlang)
library(purrr)
library(tidyr)
library(stringr)
library(flextable)
library(broom.mixed)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")
models <- readRDS(file.path(read_dir, "null_models.rds"))

################################################################################
# Tidy up tables to obtain intercept and standard deviations.
################################################################################
intercept_std_dev_table <-
    pmap(
        list(models, names(models)),
        function(model, model_name) {tidy(model) |> mutate(model = model_name)}
    ) |>
    bind_rows() |>
    select(-statistic, -effect) |>
    filter(!str_detect(model, "^defense_prosecutor"))

################################################################################
# Create cleaned up table.
################################################################################
calc_probability <- function(log_odds) {exp(log_odds) / (1 + exp(log_odds))}

intercept_std_dev_table_cleaned <-
    intercept_std_dev_table |>
    filter(is.na(group)) |>
    pivot_wider(
        id_cols = "model",
        names_from = "term",
        values_from = c("estimate", "p.value", "std.error")
    ) |>
    full_join(intercept_std_dev_table |> filter(!is.na(group)), by = "model") |>
    mutate(
        range_log_odds = qnorm(((1 - 0.95) / 2) + 0.95) * estimate,
        lower_bound_log_odds = `estimate_(Intercept)` - range_log_odds,
        upper_bound_log_odds = `estimate_(Intercept)` + range_log_odds,
        lower_bound_probability = calc_probability(lower_bound_log_odds),
        upper_bound_probability = calc_probability(upper_bound_log_odds),
        pvalue =
            case_when(
                `p.value_(Intercept)` > 0.1 ~ "",
                `p.value_(Intercept)` <= 0.1 & `p.value_(Intercept)` > 0.05 ~ "+",
                `p.value_(Intercept)` <= 0.05 & `p.value_(Intercept)` > 0.01 ~ "*",
                `p.value_(Intercept)` <= 0.01 & `p.value_(Intercept)` > 0.001 ~ "**",
                `p.value_(Intercept)` <= 0.001 ~ "***",
            ),
        `Intercept (Probability)` = calc_probability(`estimate_(Intercept)`) * 100,
        across(where(is.numeric), function(col) {signif(col, 3)}),
        Intercept = paste0(`estimate_(Intercept)`, pvalue),
        Range =
            paste0(
                `Intercept (Probability)`, "% ", "[",
                lower_bound_probability * 100, ", ",
                upper_bound_probability * 100, "]"
            ),
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
            ),
        group =
            case_when(
                group == "judge_assigned" ~ "Judge",
                group == "main_defense" ~ "Defense",
                group == "main_prosecutor" ~ "Prosecutor",
                group == "judge_defense_dyad" ~ "Judge + Defense",
                group == "judge_prosecutor_dyad" ~ "Judge + Prosecutor",
                group == "defense_prosecutor_dyad" ~ "Defense + Prosecutor",
                group == "judge_defense_prosecutor_triad" ~ "Judge + Prosecutor + Defense",
            )
    ) |>
    relocate(matches("^Intercept$"), .before = "estimate") |>
    rename("Std Dev" = "estimate", "Model" = "model") |>
    select(
        -p.value, -std.error, -pvalue, -term,
        -matches("p.value_|std.error_|estimate_|log_odds|_probability|Intercept \\(P")
    ) |>
    pivot_wider(
        id_cols = "Model",
        names_from = "group",
        values_from = matches("Intercept|Std|Range"),
        names_glue = "{group}_{.value}"
    ) |>
    relocate(
        matches("Judge_"), matches("^Defense_"), matches("^Prosecutor_"),
        matches("Judge \\+ Defense"), matches("Judge \\+ Prosecutor_"),
        matches("Defense \\+"), matches("Triad"),
        .after = "Model"
    )

################################################################################
# Create flex table.
################################################################################
intercept_std_dev_flex <-
    intercept_std_dev_table_cleaned |>
    filter(str_detect(Model, "1|2|3|6|9")) |>
    flextable() |>
    separate_header() |>
    theme_box() |>
    fontsize(size = 4, part = "all") |>
    set_table_properties(layout = "fixed") |>
    width(
        j = grep("Intercept", colnames(intercept_std_dev_table_cleaned), value = T),
        width = 0.375
    ) |>
    width(
        j = grep("Std Dev", colnames(intercept_std_dev_table_cleaned), value = T),
        width = 0.325
    ) |>
    width(
        j = grep("Range", colnames(intercept_std_dev_table_cleaned), value = T),
        width = 0.34
    )

save_as_docx(
    intercept_std_dev_flex,
    path = file.path(write_dir, "intercept_std_dev_table.docx")
)
