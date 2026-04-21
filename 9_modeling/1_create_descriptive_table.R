library(here)
library(dplyr)
library(tidyr)
library(readr)
library(flextable)
read_dir <- here("output", "final_data")
write_dir <- here("output", "analysis", "graphs_tables")

################################################################################
# Read in data.
################################################################################
data <-
    read_csv(file.path(read_dir, "final_analysis_file.csv")) |>
    mutate(
        highest_charge_max =
            case_when(
                highest_charge_max %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_max
            ),
        year_cat =
            case_when(
                year >= 2005 & year <= 2012 ~ "2005-2012",
                year >= 2013 & year <= 2016 ~ "2013-2016",
                year >= 2017 & year <= 2019 ~ "2017-2019",
                year >= 2020 & year <= 2023 ~ "2020-2023"
            )
    )

################################################################################
# Descriptive table for categorical variables.
################################################################################
descriptive_table_cat <-
    data |>
    select(
        county, sex, race_collapsed, bail_decision_bin_nr, mult_defense,
        mult_prosecutor, main_defense_private, highest_charge_max, year, year_cat
    ) |>
    mutate(across(everything(), function(col) {as.character(col)})) |>
    pivot_longer(everything(), names_to = "variable", values_to = "value") |>
    count(variable, value) |>
    arrange(variable, value) |>
    group_by(variable) |>
    mutate(prcnt = n / sum(n) * 100) |>
    ungroup()

################################################################################
# Descriptive table for courtroom actors.
################################################################################
actor_distribution <-
    data |>
    select(-matches("mult"), -main_defense_private, -matches("team")) |>
    pivot_longer(
        cols = matches("judge|defense|prosecutor"),
        names_to = "variable",
        values_to = "name"
    ) |>
    count(variable, name)

descriptive_table_actors <-
    actor_distribution |>
    group_by(variable) |>
    summarise(
        nr_unique = length(unique(name)),
        mean = mean(n),
        sd = sd(n),
        min = min(n),
        p10 = quantile(n, seq(0, 1, 0.1))[["10%"]],
        p25 = quantile(n, seq(0, 1, 0.25))[["25%"]],
        median = median(n),
        p75 = quantile(n, seq(0, 1, 0.25))[["75%"]],
        p90 = quantile(n, seq(0, 1, 0.1))[["90%"]],
        max = max(n),
        iqr = IQR(n),
        mad = mad(n)
    ) |>
    ungroup()

################################################################################
# Descriptive table for numerical variables.
################################################################################
descriptive_table_nr <-
    data |>
    select(age) |>
    pivot_longer(everything(), names_to = "variable", values_to = "value") |>
    group_by(variable) |>
    summarise(
        mean = mean(value),
        sd = sd(value),
        min = min(value),
        p10 = quantile(value, seq(0, 1, 0.1))[["10%"]],
        p25 = quantile(value, seq(0, 1, 0.25))[["25%"]],
        median = median(value),
        p75 = quantile(value, seq(0, 1, 0.25))[["75%"]],
        p90 = quantile(value, seq(0, 1, 0.1))[["90%"]],
        max = max(value),
        iqr = IQR(value),
        mad = mad(value)
    ) |>
    ungroup()

################################################################################
# Make tables pretty.
################################################################################
descriptive_table <-
    bind_rows(
        descriptive_table_cat, descriptive_table_actors, descriptive_table_nr
    ) |>
    mutate(
        variable =
            case_when(
                variable == "main_defense_private" ~ "Private attorney on case?",
                variable == "bail_decision_bin_nr" ~ "Bail set?",
                variable == "county" ~ "County",
                variable == "highest_charge_max" ~ "Highest charge",
                variable == "mult_defense" ~ "Multiple defense attorneys?",
                variable == "mult_prosecutor" ~ "Multiple prosecutors?",
                variable == "race_collapsed" ~ "Race",
                variable == "sex" ~ "Sex",
                variable == "year" ~ "Year",
                variable == "year_cat" ~ "Year (collapsed)",
                variable == "defense_prosecutor_dyad" ~ "Defense + Prosecutor (Dyad)",
                variable == "judge_assigned" ~ "Judge",
                variable == "judge_defense_dyad" ~ "Judge + Defense (Dyad)",
                variable == "judge_defense_prosecutor_triad" ~ "Judge + Defense + Prosecutor (Triad)",
                variable == "judge_prosecutor_dyad" ~ "Judge + Prosecutor (Dyad)",
                variable == "main_defense" ~ "Defense Attorney",
                variable == "main_prosecutor" ~ "Prosecutor",
                variable == "age" ~ "Age"
            ),
        value =
            case_when(
                value == F ~ as.character(0),
                value == T ~ as.character(1),
                value == "allegheny" ~ "Allegheny",
                value == "blair" ~ "Blair",
                value == "centre" ~ "Centre",
                value == "dauphin" ~ "Dauphin",
                value == "erie" ~ "Erie",
                value == "montgomery" ~ "Montgomery",
                value == "black" ~ "Black",
                value == "white" ~ "White",
                value == "female" ~ "Female",
                value == "male" ~ "Male",
                is.na(value) ~ "-",
                T ~ as.character(value),
            ),
        across(
            matches("prcnt|mean|sd|iqr|min|max|mad|median|p[0-9]{2}"),
            function(col) {
                if_else(!is.na(col), sprintf("%.1f", signif(col, 3)), "-")
            }
        ),
        n = if_else(is.na(n), "-", as.character(n)),
        nr_unique = if_else(is.na(nr_unique), "-", as.character(nr_unique)),
        prcnt = if_else(prcnt != "-", paste0(prcnt, "%"), prcnt),
        variable =
            factor(
                variable,
                levels =
                    c(
                        "Judge", "Defense Attorney", "Prosecutor",
                        "Judge + Defense (Dyad)", "Judge + Prosecutor (Dyad)",
                        "Defense + Prosecutor (Dyad)",
                        "Judge + Defense + Prosecutor (Triad)",
                        "Age", "Private attorney on case?",
                        "Bail set?", "County", "Highest charge",
                        "Multiple defense attorneys?", "Multiple prosecutors?",
                        "Race", "Sex", "Year", "Year (collapsed)"
                    )
            )
    ) |>
    arrange(variable) |>
    rename(
        Variable = variable, Value = value, N = n, Percent = prcnt,
        `Nr. Unique` = nr_unique, Mean = mean, `Std. Dev.` = sd, `Min.` = min,
        Max = max, IQR = iqr, `Median Abs. Dev.` = mad, Median = median
    )

################################################################################
# Make tables pretty.
################################################################################
descriptive_flextable <-
    descriptive_table |>
    as_grouped_data(groups = "Variable") |>
    as_flextable() |>
    compose(j = 1, i = ~ !is.na(Variable), value = as_paragraph(as_chunk(Variable))) |>
    bold(j = 1, i = ~ !is.na(Variable), bold = T, part = "body") |>
    fontsize(size = 6, part = "all") |>
    set_table_properties(layout = "autofit")

save_as_docx(
    descriptive_flextable,
    path = file.path(write_dir, "descriptive_table.docx")
)
