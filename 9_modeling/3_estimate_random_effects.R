library(here)
library(lme4)
library(dplyr)
library(rlang)
library(purrr)
library(tidyr)
library(readr)
library(broom.mixed)

################################################################################
# Read in models.
################################################################################
models <- readRDS(here("output", "analysis", "model_output", "null_models.rds"))
models <-
    models[
        names(models) %in%
            c(
                "judge", "defense", "prosecutor", "judge_defense_prosecutor",
                "judge_defense_prosecutor_dyads", "judge_defense_prosecutor_triad"
            )
    ]

################################################################################
# Extract random effects, confidence intervals, and predicted probabilities.
################################################################################
extract_re <- function(model, model_name) {
    random_effects <- ranef(model)
    predicted_values <- coef(model)
    
    pmap(
        list(list(random_effects), random_effects, predicted_values, names(random_effects)),
        function(re_obj, res, pvs, group_name) {
            tibble(
                name = rownames(res),
                group = group_name,
                random_effects = res$`(Intercept)`,
                std_error = sqrt(attr(re_obj[[group_name]], "postVar")[1,1,]),
                moe = qnorm(((1 - 0.95) / 2) + 0.95) * std_error,
                ci_lower = random_effects - moe,
                ci_upper = random_effects + moe,
                pred_log_odds = pvs$`(Intercept)`,
                predicted_probabilities = exp(pred_log_odds) / (1 + exp(pred_log_odds))
            )
        }
    ) |>
        bind_rows() |>
        mutate(model_name = model_name)
}

# fixed extracts the grand-mean intercept.
# ran_pars extracts the standard deviation around the grand-mean intercept.
# ran_vals extracts the random effects estimates.
# ran_coefs extracts the predicted probabilities.
extract_re_broom <- function(model, model_name) {
    tidy_model <-
        model |>
        tidy(
            effects = c("ran_vals", "ran_coefs"),
            conf.int = T,
            conf.level = 0.95
        ) |>
        mutate(model_name = model_name)
    
    tidy_model <-
        tidy_model |>
        filter(effect == "ran_coefs") |>
        pivot_wider(
            id_cols = c("model_name", "group", "level"),
            values_from = estimate,
            names_from = effect
        ) |>
        full_join(
            tidy_model |> filter(effect == "ran_vals"),
            by = c("model_name", "group", "level")
        ) |>
        mutate(predicted_probabilities = exp(ran_coefs) / (1 + exp(ran_coefs))) |>
        select(-term, -effect) |>
        rename(
            random_effects = estimate,
            pred_log_odds = ran_coefs,
            std_error = std.error,
            ci_lower = conf.low,
            ci_upper = conf.high
        )
}

# These two functions do the same thing just in different ways. I was testing
# them because calculating the random effects takes a long time on the
# complicated models.
values_df <-
    pmap(list(models, names(models)), extract_re) |>
    bind_rows() |>
    arrange(group, model_name, random_effects) |>
    mutate(
        name = paste0(group, model_name, name),
        actor = factor(name, levels = name)
    ) |>
    select(-name)

write_csv(
    values_df,
    here("output", "analysis", "model_output", "random_effects.csv")
)

# tidy_values_df <-
#     pmap(list(models, names(models)), extract_re_broom) |>
#     bind_rows() |>
#     arrange(group, model_name, random_effects) |>
#     mutate(
#         level = paste0(group, model_name, level),
#         actor = factor(level, levels = level)
#     ) |>
#     select(-level)
