library(here)
library(readr)
library(dplyr)
library(flextable)
read_dir <- here("output", "analysis", "model_output")
write_dir <- here("output", "analysis", "graphs_tables")
icc_df <- read_csv(file.path(read_dir, "icc_df_large_cells.csv"))

################################################################################
# Create ICC tables for paper.
################################################################################
icc_table <-
    icc_df |>
    mutate(
        model =
            case_when(
                model == "defense_top90" ~ "Top 90% of cases (defense attorneys)",
                model == "defense_top50" ~ "Top 50% of cases (defense attorneys)",
                model == "prosecutor_top90" ~ "Top 90% of cases (prosecutors)",
                model == "prosecutor_top50" ~ "Top 50% of cases (prosecutors)",
                model == "dyad_model" ~ "Top 50% of cases (triad)"
            )
    ) |>
    relocate(
        c(
            "model", "judge_assigned", "main_defense", "main_prosecutor",
            "judge_defense_dyad", "judge_prosecutor_dyad", "defense_prosecutor_dyad"
        ),
        .after = "model"
    ) |>
    rename(
        "Model" = "model",
        "Judge" = "judge_assigned",
        "Defense" = "main_defense",
        "Prosecutor" = "main_prosecutor",
        "Judge + Defense Dyad" = "judge_defense_dyad",
        "Judge + Prosecutor Dyad" = "judge_prosecutor_dyad",
        "Defense + Prosecutor Dyad" = "defense_prosecutor_dyad"
    ) |>
    mutate(
        across(where(is.numeric), function(col) {as.character(signif(col, 4))}),
        across(everything(), function(col) {if_else(is.na(col), "-", col)})
    )

icc_flextable <-
    icc_table |>
    flextable() |>
    fontsize(size = 8, part = "all") |>
    set_table_properties(layout = "autofit")

save_as_docx(
    icc_flextable,
    path = file.path(write_dir, "icc_table_large_cells.docx")
)
