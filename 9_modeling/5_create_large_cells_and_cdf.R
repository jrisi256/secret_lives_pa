library(here)
library(lme4)
library(rlang)
library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
data_dir <- here("output", "final_data")
graph_dir <- here("output", "analysis", "graphs_tables")
data_df <- read_csv(file.path(data_dir, "final_analysis_file.csv"))

################################################################################
# Create cumulative distribution data frame.
################################################################################
actor_distribution <-
    data_df |>
    select(-matches("mult|team|private")) |>
    rename(
        "Judge" = "judge_assigned",
        "Defense Attorney" = "main_defense",
        "Prosecutor" = "main_prosecutor",
        "Judge + Defense Attorney" = judge_defense_dyad,
        "Judge + Prosecutor" = judge_prosecutor_dyad,
        "Defense Attorney + Prosecutor" = defense_prosecutor_dyad,
        "Judge + Defense Attorney + Prosecutor" = judge_defense_prosecutor_triad,
    ) |>
    pivot_longer(
        cols = matches("judge|defense|prosecutor"),
        names_to = "variable",
        values_to = "name"
    ) |>
    count(variable, name)

cumsum <-
    actor_distribution |>
    count(variable, n, name = "nr_actors_with_n_cases") |>
    mutate(total_nr_cases = n * nr_actors_with_n_cases) |>
    arrange(variable, n) |>
    group_by(variable) |>
    mutate(
        cum_sum_cases = cumsum(total_nr_cases),
        cum_prop_cases = cum_sum_cases / sum(total_nr_cases),
        cum_sum_actors = cumsum(nr_actors_with_n_cases),
        cum_prop_actors = cum_sum_actors / sum(nr_actors_with_n_cases)
    ) |>
    ungroup()

################################################################################
# Graph cumulative distribution function.
################################################################################
pp_graph <-
    cumsum |>
    filter(
        variable %in% c("Judge", "Defense Attorney", "Prosecutor", "Judge + Defense Attorney + Prosecutor")
    ) |>
    ggplot(aes(x = cum_prop_actors, y = cum_prop_cases)) +
    geom_line(aes(group = variable, color = variable)) +
    theme_bw() +
    labs(
        x = "Cumulative proportion of actors",
        y = "Cumulative proportion of cases"
    ) +
    scale_x_continuous(breaks = seq(0, 1, 0.1)) +
    scale_y_continuous(breaks = seq(0, 1, 0.1)) +
    theme(
        axis.text = element_text(size = 15),
        axis.title = element_text(size = 18)
    )

ggsave(
    file.path(graph_dir, "pp_graph_actors.png"),
    pp_graph,
    height = 8,
    width = 12
)

################################################################################
# Create data frames for different cell sizes.
################################################################################
create_topN_prcnt_cases <- function(cumsum_df, actors_df, prop) {
    cumsum_df |>
        filter(cum_prop_cases >= prop) |>
        select(variable, n) |>
        left_join(actors_df, by = c("variable", "n")) |>
        nest(.by = variable)
}

get_actor_ids <- function(df, actor) {
    df |> filter(variable == actor) |> pull(data) |> (\(df) df[[1]])() |> pull(name)
}

top90prcnt_cases <- create_topN_prcnt_cases(cumsum, actor_distribution, 0.1)
top75prcnt_cases <- create_topN_prcnt_cases(cumsum, actor_distribution, 0.25)
top50prcnt_cases <- create_topN_prcnt_cases(cumsum, actor_distribution, 0.5)

# Most active defense attorneys.
data_top90prcnt_defense <-
    data_df |>
    filter(main_defense %in% get_actor_ids(top90prcnt_cases, "Defense Attorney"))

data_top50prcnt_defense <-
    data_df |>
    filter(main_defense %in% get_actor_ids(top50prcnt_cases, "Defense Attorney"))

# Most active prosecutors.
data_top90prcnt_prosecutor <-
    data_df |>
    filter(main_prosecutor %in% get_actor_ids(top90prcnt_cases, "Prosecutor"))

data_top50prcnt_prosecutor <-
    data_df |>
    filter(main_prosecutor %in% get_actor_ids(top50prcnt_cases, "Prosecutor"))

# Most active triads.
data_top50prcnt_triads <-
    data_df |>
    filter(
        judge_defense_prosecutor_triad %in%
            get_actor_ids(
                top50prcnt_cases, "Judge + Defense Attorney + Prosecutor"
            )
    )

write_csv(data_top90prcnt_defense, file.path(data_dir, "top90prcnt_cases_defense.csv"))
write_csv(data_top50prcnt_defense, file.path(data_dir, "top50prcnt_cases_defense.csv"))
write_csv(data_top90prcnt_prosecutor, file.path(data_dir, "top90prcnt_cases_prosecutor.csv"))
write_csv(data_top50prcnt_prosecutor, file.path(data_dir, "top50prcnt_cases_prosecutor.csv"))
write_csv(data_top50prcnt_triads, file.path(data_dir, "top50prcnt_cases_triads.csv"))
