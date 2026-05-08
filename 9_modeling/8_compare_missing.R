library(here)
library(lme4)
library(dplyr)
library(readr)
library(rlang)
library(broom)
library(purrr)
library(tidyr)
library(flextable)
read_dir <- here("output", "final_data")
write_dir <- here("output", "analysis", "graphs_tables")
model_dir <- here("output", "analysis", "model_output")

################################################################################
# Read in data.
################################################################################
data <- read_csv(file.path(read_dir, "final_analysis_file.csv"))
data_missing <-
    read_csv(file.path(read_dir, "final_analysis_file_missings.csv")) |>
    mutate(
        sex = if_else(is.na(sex), "unreported/unknown", sex),
        race_collapsed = if_else(is.na(race_collapsed), "unknown/unreported", race_collapsed),
        highest_charge_max =
            case_when(
                highest_charge_max %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_max
            ),
        highest_charge_min =
            case_when(
                highest_charge_min %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_min
            )
    )

################################################################################
# Conduct statistical tests.
################################################################################
conduct_ztest_prop <- function(df1, df2, col, target_val) {
    df1 <-
        df1 |>
        count(.data[[col]], name = "x") |>
        mutate(prop = x / sum(x), total = sum(x)) |>
        filter(.data[[col]] == target_val)
    View
    
    df2 <-
        df2 |>
        count(.data[[col]], name = "x") |>
        mutate(prop = x / sum(x), total = sum(x)) |>
        filter(.data[[col]] == target_val)
    
    x1 <- df1 |> pull(x)
    x2 <- df2 |> pull(x)
    n1 <- df1 |> pull(total)
    n2 <- df2 |> pull(total)
    
    prop.test(
        x = c(x1, x2), n = c(n1, n2), alternative = "two.sided", correct = F
    ) |>
        tidy() |>
        rename("missing" = "estimate1", "not_missing" = "estimate2") |>
        mutate(
            missing_x = x1, not_missing_x = x2, missing_n = n1, not_missing_n = n2,
            col = col,
            target_val = as.character(target_val)
        )
}

# Sex.
sex_not_missing <- data_missing |> filter(sex != "unreported/unknown") |> select(sex)
prop_test_sex <- conduct_ztest_prop(sex_not_missing, data, "sex", "male")

# Race
race_not_missing <- data_missing |> filter(race_collapsed != "unknown/unreported") |> select(race_collapsed)
prop_test_black <- conduct_ztest_prop(race_not_missing, data, "race_collapsed", "black")
prop_test_other <- conduct_ztest_prop(race_not_missing, data, "race_collapsed", "Other")
prop_test_white <- conduct_ztest_prop(race_not_missing, data, "race_collapsed", "white")

# Private defense attorney.
private_not_missing <- data_missing |> filter(!is.na(main_defense_private)) |> select(main_defense_private)
prop_test_private <- conduct_ztest_prop(private_not_missing, data, "main_defense_private", 1)

# Bail.
bail_not_missing <- data_missing |> filter(!is.na(bail_decision_bin_nr)) |> select(bail_decision_bin_nr)
prop_test_bail <- conduct_ztest_prop(bail_not_missing, data, "bail_decision_bin_nr", "1")

# County.
county_not_missing <- data_missing |> filter(!is.na(county)) |> select(county)
prop_test_alle <- conduct_ztest_prop(county_not_missing, data, "county", "allegheny")
prop_test_blair <- conduct_ztest_prop(county_not_missing, data, "county", "blair")
prop_test_centre <- conduct_ztest_prop(county_not_missing, data, "county", "centre")
prop_test_dauph <- conduct_ztest_prop(county_not_missing, data, "county", "dauphin")
prop_test_erie <- conduct_ztest_prop(county_not_missing, data, "county", "erie")
prop_test_monty <- conduct_ztest_prop(county_not_missing, data, "county", "montgomery")

# Age.
age_not_missing <- data_missing |> filter(!is.na(age)) |> select(age) |> filter(age >= 14)
t_test_age <-
    t.test(age_not_missing$age, data$age) |>
    tidy() |>
    rename("missing" = estimate1, "not_missing" = estimate2) |> 
    mutate(
        missing_n = nrow(age_not_missing), not_missing_n = nrow(data), col = "age"
    )

# Year.
year_not_missing <- data_missing |> filter(!is.na(year), year != 2024) |> select(year)
prop_test_years <-
    map(
        sort(unique(year_not_missing$year)),
        conduct_ztest_prop,
        df1 = year_not_missing,
        df2 = data,
        col = "year"
    ) |>
    bind_rows()

# Charges.
charge_not_missing <- data_missing |> filter(!is.na(highest_charge_max)) |> select(matches("charge"))
prop_test_charges_max <-
    map(
        sort(unique(charge_not_missing$highest_charge_max)),
        conduct_ztest_prop,
        df1 = charge_not_missing,
        df2 = data,
        col = "highest_charge_max"
    ) |>
    bind_rows()

prop_test_charges_min <-
    map(
        sort(unique(charge_not_missing$highest_charge_max)),
        conduct_ztest_prop,
        df1 = charge_not_missing,
        df2 = data,
        col = "highest_charge_min"
    ) |>
    bind_rows()

# Multiple defense attorneys.
judge_defense <-
    data_missing |>
    filter(!is.na(judge_assigned), !is.na(main_defense)) |>
    mutate(judge_defense_dyad = paste0(judge_assigned, "_", main_defense))

prop_test_multd <- conduct_ztest_prop(judge_defense, data, "mult_defense", "1")

# Multiple prosecutors.
judge_prosecutor <-
    data_missing |>
    filter(!is.na(judge_assigned), !is.na(main_prosecutor)) |>
    mutate(judge_prosecutor_dyad = paste0(judge_assigned, "_", main_prosecutor))

prop_test_multp <- conduct_ztest_prop(judge_prosecutor, data, "mult_prosecutor", "1")

################################################################################
# Create statistical test table.
################################################################################
statistical_test_table <-
    bind_rows(
        prop_test_sex, prop_test_black, prop_test_other, prop_test_white,
        prop_test_private, prop_test_bail, prop_test_alle, prop_test_blair,
        prop_test_centre, prop_test_dauph, prop_test_erie, prop_test_monty,
        t_test_age, prop_test_years, prop_test_charges_max, prop_test_multd,
        prop_test_multp
    ) |>
    mutate(
        significance =
            case_when(
                p.value > 0.1 ~ "",
                p.value <= 0.1 & p.value > 0.05 ~ "+",
                p.value <= 0.05 & p.value > 0.01 ~ "*",
                p.value <= 0.01 & p.value > 0.001 ~ "**",
                p.value <= 0.001 ~ "***",
            ),
        col =
            case_when(
                col == "main_defense_private" ~ "Private attorney on case?",
                col == "bail_decision_bin_nr" ~ "Bail set?",
                col == "county" ~ "County",
                col == "highest_charge_max" ~ "Highest charge",
                col == "mult_defense" ~ "Multiple defense attorneys?",
                col == "mult_prosecutor" ~ "Multiple prosecutors?",
                col == "race_collapsed" ~ "Race",
                col == "sex" ~ "Sex",
                col == "year" ~ "Year",
                col == "year_cat" ~ "Year (collapsed)",
                col == "defense_prosecutor_dyad" ~ "Defense + Prosecutor (Dyad)",
                col == "judge_assigned" ~ "Judge",
                col == "judge_defense_dyad" ~ "Judge + Defense (Dyad)",
                col == "judge_defense_prosecutor_triad" ~ "Judge + Defense + Prosecutor (Triad)",
                col == "judge_prosecutor_dyad" ~ "Judge + Prosecutor (Dyad)",
                col == "main_defense" ~ "Defense Attorney",
                col == "main_prosecutor" ~ "Prosecutor",
                col == "age" ~ "Age"
            ),
        target_val =
            case_when(
                target_val == "allegheny" ~ "Allegheny",
                target_val == "blair" ~ "Blair",
                target_val == "centre" ~ "Centre",
                target_val == "dauphin" ~ "Dauphin",
                target_val == "erie" ~ "Erie",
                target_val == "montgomery" ~ "Montgomery",
                target_val == "black" ~ "Black",
                target_val == "white" ~ "White",
                target_val == "female" ~ "Female",
                target_val == "male" ~ "Male",
                is.na(target_val) ~ "-",
                T ~ target_val
            ),
        across(
            c("missing", "not_missing"),
            function(x) {
                if_else(
                    col == "Age",
                    sprintf("%.3f", signif(x, 3)),
                    paste0(sprintf("%.1f", signif(x * 100, 3)), "%")
                )
            }
        )
    ) |>
    select(
        -statistic, -parameter, -matches("conf"), -method, -alternative,
        -estimate, -p.value
    ) |>
    relocate(target_val, .before = missing) |>
    relocate(significance, .after = not_missing) |>
    rename(
        "Value" = target_val, "Missing data" = missing, "Clean data" = not_missing,
        "N (missing data)" = missing_x, "N (clean data)" = not_missing_x,
        "Total (missing data)" = missing_n, "Total (clean data)" = not_missing_n,
        "Significance" = significance
    )

missing_flextable <-
    statistical_test_table |>
    as_grouped_data(groups = "col") |>
    as_flextable() |>
    compose(j = 1, i = ~ !is.na(col), value = as_paragraph(as_chunk(col))) |>
    bold(j = 1, i = ~ !is.na(col), bold = T, part = "body") |>
    width(j = 1, width = 2) |>
    fontsize(size = 8, part = "all") |>
    set_table_properties(layout = "fixed")

save_as_docx(missing_flextable, path = file.path(write_dir, "missing_comparison_table.docx"))

################################################################################
# Estimate null models using only defense and judge.
################################################################################
# Defense.
judge_defense_no_missing <-
    judge_defense |>
    filter(
        sex != "unreported/unknown", race_collapsed != "unknown/unreported",
        !is.na(main_defense_private), !is.na(bail_decision_bin_nr), !is.na(county),
        !is.na(age), !is.na(year), !is.na(highest_charge_max)
    ) |>
    bind_rows(data) |>
    select(-matches("prosecutor|mult|any_private|nr_charges|private_or|team")) |>
    mutate(
        year_cat =
            case_when(
                year >= 2005 & year <= 2012 ~ "2005-2012",
                year >= 2013 & year <= 2016 ~ "2013-2016",
                year >= 2017 & year <= 2019 ~ "2017-2019",
                year >= 2020 & year <= 2023 ~ "2020-2023"
            ),
        year_cat = relevel(factor(year_cat), ref = "2020-2023"),
        year = relevel(factor(as.character(year)), ref = "2023"),
        county = relevel(factor(county), ref = "allegheny"),
        sex = relevel(factor(sex), ref = "female"),
        race_collapsed = relevel(factor(race_collapsed), ref = "black"),
        highest_charge_max =
            case_when(
                highest_charge_max %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_max
            ),
        highest_charge_min =
            case_when(
                highest_charge_min %in% c("h1", "h2") ~ "f1",
                T ~ highest_charge_min
            ),
        highest_charge_max = relevel(factor(highest_charge_max), ref = "f1"),
        highest_charge_min = relevel(factor(highest_charge_min), ref = "f1"),
        age_scaled = (age - mean(age)) / sd(age),
        main_defense_private = relevel(factor(as.character(main_defense_private)), ref = "0")
    )

null_defense_model <-
    glmer(
        bail_decision_bin_nr ~
            (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad),
        data = judge_defense_no_missing,
        family = "binomial"
    )

saveRDS(
    null_defense_model,
    file.path(model_dir, "null_defense_model_missing.rds")
)

################################################################################
# Estimate null models using only defense and judge for top 50% of cases.
################################################################################
actor_distribution <-
    judge_defense_no_missing |>
    pivot_longer(
        cols = matches("judge_assigned|main_defense$"),
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

top50prcnt_cases <-
    cumsum |>
    filter(cum_prop_cases >= 0.5) |>
    select(variable, n) |>
    left_join(actor_distribution, by = c("variable", "n")) |>
    nest(.by = variable)

get_actor_ids <- function(df, actor) {
    df |> filter(variable == actor) |> pull(data) |> (\(df) df[[1]])() |> pull(name)
}

judge_defense_no_missing_top50prcnt <-
    judge_defense_no_missing |>
    filter(main_defense %in% get_actor_ids(top50prcnt_cases, "main_defense"))

null_defense_model_top50prcnt <-
    glmer(
        bail_decision_bin_nr ~
            (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad),
        data = judge_defense_no_missing_top50prcnt,
        family = "binomial"
    )

saveRDS(
    null_defense_model_top50prcnt,
    file.path(model_dir, "null_defense_model_missing_top50prcnt.rds")
)

################################################################################
# Estimate null models using only prosecutor and judge.
################################################################################
judge_prosecutor_no_missing <- judge_prosecutor |> bind_rows(data)

null_prosecutor_model <-
    glmer(
        bail_decision_bin_nr ~
            (1 | judge_assigned) + (1 | main_prosecutor) + (1 | judge_prosecutor_dyad),
        data = judge_prosecutor_no_missing,
        family = "binomial"
    )

saveRDS(
    null_prosecutor_model,
    file.path(model_dir, "null_prosecutor_model_missing.rds")
)

################################################################################
# Estimate full model for defense attorneys.
################################################################################
full_model_max <-
    glmer(
        bail_decision_bin_nr ~
            sex + race_collapsed + main_defense_private + age_scaled +
            I(age_scaled ^ 2) + highest_charge_max + year_cat + county +
            (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad),
        family = "binomial",
        data = judge_defense_no_missing,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )

full_model_min <-
    glmer(
        bail_decision_bin_nr ~
            sex + race_collapsed + main_defense_private + age_scaled +
            I(age_scaled ^ 2) + highest_charge_min + year_cat + county +
            (1 | judge_assigned) + (1 | main_defense) + (1 | judge_defense_dyad),
        family = "binomial",
        data = judge_defense_no_missing,
        control = glmerControl(optCtrl = list(maxfun = 100000))
    )

saveRDS(
    full_model_max,
    file.path(model_dir, "full_defense_model_missing_max.rds")
)

saveRDS(
    full_model_min,
    file.path(model_dir, "full_defense_model_missing_min.rds")
)
