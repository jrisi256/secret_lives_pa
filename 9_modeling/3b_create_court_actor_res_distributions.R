library(here)
library(dplyr)
library(readr)
library(stringr)
library(ggplot2)

################################################################################
# Read in the estimated random effects and pull arrange the actors
################################################################################
random_effects <-
    read_csv(here("output", "analysis", "model_output", "random_effects.csv")) |>
    arrange(group, model_name, random_effects) |>
    mutate(
        name = str_replace(actor, paste0(group, model_name), ""),
        name = paste0(group, "_", name)
    )

levels <-
    random_effects |>
    filter(
        model_name %in% c("judge", "prosecutor", "defense") |
        str_detect(model_name, "dyads") & str_detect(group, "dyad") |
        str_detect(model_name, "triad") & str_detect(group, "triad")
    ) |>
    arrange(group, model_name, random_effects) |>
    mutate(name = factor(name, levels = name)) |>
    pull(name)

random_effects_factor <-
    random_effects |>
    mutate(
        name = factor(name, levels = levels),
        model_name =
            case_when(
                model_name == "judge" ~ "Model 1 (Just Judge)",
                model_name == "defense" ~ "Model 2  (Just Defense)",
                model_name == "prosecutor" ~ "Model 3 (Just Prosecutor)",
                model_name == "judge_defense_prosecutor" ~ "Model 6 (All 3 Actors)",
                model_name == "judge_defense_prosecutor_dyads" ~ "Model 9 (All 3 Actors + Dyads)",
                model_name == "judge_defense_prosecutor_triad" ~ "Model 10 (All 3 Actors + Triad"
            ),
        model_name =
            factor(
                model_name,
                levels =
                    c(
                        "Model 1 (Just Judge)", "Model 2  (Just Defense)",
                        "Model 3 (Just Prosecutor)", "Model 6 (All 3 Actors)",
                        "Model 9 (All 3 Actors + Dyads)", "Model 10 (All 3 Actors + Triad"
                    )
            ),
        group =
            case_when(
                group == "judge_assigned" ~ "Judge",
                group == "main_defense" ~ "Defense",
                group == "main_prosecutor" ~ "Prosecutor",
                group == "judge_defense_dyad" ~ "Judge + Defense (Dyad)",
                group == "judge_prosecutor_dyad" ~ "Judge + Prosecutor (Dyad)",
                group == "defense_prosecutor_dyad" ~ "Defense + Prosecutor (Dyad)",
                group == "judge_defense_prosecutor_triad" ~ "Judge + Prosecutor + Defense (Triad)",
            ),
        group =
            factor(
                group,
                levels =
                    c(
                        "Judge", "Defense", "Prosecutor", "Judge + Defense (Dyad)",
                        "Judge + Prosecutor (Dyad)", "Defense + Prosecutor (Dyad)",
                        "Judge + Prosecutor + Defense (Triad)"
                    )
            )
    )

################################################################################
# Graph results.
################################################################################
random_effects_graph <-
    random_effects_factor |>
    ggplot(aes(x = name, y = random_effects)) +
    geom_point(color = "red") +
    geom_ribbon(
        aes(ymin = ci_lower, ymax = ci_upper, group = group), alpha = 0.2
    ) +
    theme_bw() +
    theme(axis.text.y = element_blank()) +
    labs(
        x = "Courtroom Actor",
        y = "Random Effect (Courtroom actor-level deviations from overall (grand mean) intercept)"
    ) +
    coord_flip() +
    geom_hline(yintercept = 0) +
    facet_wrap(~group+model_name, scales = "free_y", ncol = 4) +
    theme(
        axis.text = element_text(size = 15),
        axis.title = element_text(size = 18),
        strip.text = element_text(size = 15)
    )

predicted_probabilities_graph <-
    random_effects_factor |>
    ggplot(aes(x = name, y = predicted_probabilities)) +
    geom_point(color = "red") +
    theme_bw() +
    theme(axis.text.y = element_blank()) +
    labs(
        x = "Courtroom Actor", y = "Predicted Probability of Assigning Bail"
    ) +
    coord_flip() +
    geom_hline(yintercept = 0.5) +
    facet_wrap(~group+model_name, scales = "free_y", ncol = 4) +
    theme(
        axis.text = element_text(size = 15),
        axis.title = element_text(size = 18),
        strip.text = element_text(size = 15)
    )

save_dir <- here("output", "analysis", "graphs_tables")

ggsave(
    file.path(save_dir, "random_effects_graph.png"),
    random_effects_graph,
    width = 18,
    height = 14
)

ggsave(
    file.path(save_dir, "predicted_probabilities_graph.png"),
    predicted_probabilities_graph,
    width = 18,
    height = 14
)
