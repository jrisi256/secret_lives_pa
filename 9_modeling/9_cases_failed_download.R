library(here)
library(readr)
library(dplyr)
library(ggplot2)
read_dir <- here("output", "pdf_parse_list")
graph_dir <- here("output", "analysis", "graphs_tables")

################################################################################
# Read in data and keep only target cases.
################################################################################
pdfs_download_df <- read_csv(file.path(read_dir, "pdf_dload_status.csv.gz"))

flattened_json_ds_mj <-
    readRDS(file.path(read_dir, "flattened_json_ds_mj.rds")) |>
    distinct(L1)

docket_sheets_mj_cr_target_county <-
    pdfs_download_df |>
    filter(
        pdf_type == "ds", court_type == "MJ", case_type == "CR",
        county %in% c("Allegheny", "Blair", "Centre", "Dauphin", "Erie", "Montgomery")
    ) |>
    mutate(successfully_downloaded_new = pdf_name %in% flattened_json_ds_mj$L1)

################################################################################
# Estimate amount that failed to download.
################################################################################
create_count_df <- function(df, ...) {
    count(df, successfully_downloaded_new, pick(...)) %>%
        group_by(pick(...)) %>%
        mutate(prcnt = n / sum(n) * 100) %>%
        ungroup() %>%
        filter(!successfully_downloaded_new, year != 2024, year >= 2005)
}

year_count <- create_count_df(docket_sheets_mj_cr_target_county, "year")
county_year_count <- create_count_df(docket_sheets_mj_cr_target_county, "county", "year")

graph_county_year_facet <-
    ggplot(county_year_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = county)) +
    geom_line(aes(color = county, group = county), alpha = 0.3) +
    theme_bw() +
    labs(x = "Year", y = "Percentage failed to download", color = "County") +
    theme(legend.position = "none") +
    facet_wrap(~county) +
    geom_line(data = year_count, aes(x = year, y = prcnt), color = "black") +
    scale_y_continuous(breaks = seq(0, 55, 5))

ggsave(
    filename = "county_year.png",
    plot = graph_county_year_facet,
    path = graph_dir,
    width = 12,
    height = 8
)
