library(here)
library(readr)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)
library(ggplot2)
library(R.utils)
library(forcats)

case_list_dir <- here("output", "pdf_download_list")
pdf_dir <- file.path("/media", "joe", "T7 Shield", "new_pdf_struct")
parse_list_dir <- here("output", "pdf_parse_list")
graph_dir <- here("7_parse_pdfs", "graphs")

################################################################################
# Read in the PDFs which were successfully downloaded and the full list of PDFs.
################################################################################
cr_cases <- read_csv(file.path(case_list_dir, "criminal_pdf_links.csv.gz"), col_select = file_name)
lt_cases <- read_csv(file.path(case_list_dir, "lt_pdf_links.csv.gz"), col_select = file_name)
all_cases_df <- bind_rows(cr_cases, lt_cases) %>% transmute(pdf_name = str_replace(file_name, ".pdf", ""))

pdfs <- list.files(pdf_dir, pattern = ".pdf$", recursive = T)
pdfs_download_df <-
    tibble(pdf_name = pdfs) %>%
    mutate(
        pdf_name = str_replace(pdf_name, ".pdf", ""),
        successfully_downloaded = T
    ) %>%
    separate_wider_delim(
        pdf_name,
        delim = "/",
        names = c("col1", "col2", "col3", "col4", "col5", "pdf_name")
    ) %>%
    select(pdf_name, successfully_downloaded) %>%
    full_join(all_cases_df, by = "pdf_name") %>%
    mutate(successfully_downloaded = if_else(is.na(successfully_downloaded), F, successfully_downloaded)) %>%
    separate_wider_delim(
        pdf_name,
        delim = "_",
        names = c("pdf_type", "county", "court_type", "judge_id", "case_type", "case_id", "year"),
        cols_remove = F
    )

# Save results of PDF downloading.
write_csv(pdfs_download_df, file.path(parse_list_dir, "pdf_dload_status.csv"))
gzip(file.path(parse_list_dir, "pdf_dload_status.csv"), overwrite = T)

################################################################################
# Create graphs demonstrating when/where PDFs are getting redacted.
################################################################################
create_count_df <- function(df, ...) {
    count(df, successfully_downloaded, pick(...)) %>%
        group_by(pick(...)) %>%
        mutate(prcnt = n / sum(n) * 100) %>%
        ungroup() %>%
        filter(!successfully_downloaded)
}

# No temporal component.
county_count <- create_count_df(pdfs_download_df, "county")
caseType_count <- create_count_df(pdfs_download_df, "case_type")
courtType_count <- create_count_df(pdfs_download_df, "court_type")
judge_count <- create_count_df(pdfs_download_df, "county", "judge_id")

create_graph_not_year <- function(df, xcol, xtitle, facet="", cFlip = F) {
    g <-
        ggplot(df, aes(x = fct_reorder(.data[[xcol]], prcnt), y = prcnt)) +
        geom_line(aes(group = 1)) +
        geom_point() +
        theme_bw() +
        labs(x = xtitle, y = "Percentage failed to download")
    
    if(cFlip) {g <- g + coord_flip()}
    
    if(facet != "") {
        g <-
            g +
            facet_wrap(~.data[[facet]], scale = "free_x") +
            theme(axis.text.x = element_blank())
    }
    
    return(g)
}

graph_county <- create_graph_not_year(county_count, "county", "County", cFlip = T)
ggsave(filename = "county.png", plot = graph_county, path = graph_dir, width = 12, height = 8)

graph_caseType <- create_graph_not_year(caseType_count, "case_type", "Case Type")
ggsave(filename = "caseType.png", plot = graph_caseType, path = graph_dir, width = 12, height = 8)

graph_courtType <- create_graph_not_year(courtType_count, "court_type", "Court Type")
ggsave(filename = "courtType.png", plot = graph_courtType, path = graph_dir, width = 12, height = 8)

graph_judge <- create_graph_not_year(judge_count, "judge_id", "Judge", facet = "county")
ggsave(filename = "judge.png", plot = graph_judge, path = graph_dir, width = 25, height = 12)

# County crossed by case type and court type.
county_caseType_count <-
    create_count_df(pdfs_download_df, "county", "case_type") %>%
    bind_rows(county_count) %>%
    mutate(case_type = if_else(is.na(case_type), "all", case_type))

county_courtType_count <-
    create_count_df(pdfs_download_df, "county", "court_type") %>%
    bind_rows(county_count) %>%
    mutate(court_type = if_else(is.na(court_type), "all", court_type))

graph_county_caseType <-
    ggplot(county_caseType_count, aes(x = fct_reorder(county, prcnt), y = prcnt)) +
    geom_point(aes(color = case_type)) +
    geom_line(aes(color = case_type, group = case_type)) +
    theme_bw() +
    coord_flip() +
    labs(x = "County")
ggsave(filename = "county_caseType.png", plot = graph_county_caseType, path = graph_dir, width = 12, height = 8)

graph_county_courtType <-
    ggplot(county_courtType_count, aes(x = fct_reorder(county, prcnt), y = prcnt)) +
    geom_point(aes(color = court_type)) +
    geom_line(aes(color = court_type, group = court_type)) +
    theme_bw() +
    coord_flip() +
    labs(x = "County")
ggsave(filename = "county_courtType.png", plot = graph_county_courtType, path = graph_dir, width = 12, height = 8)

# Graph redacted cases by year.
year_count <- create_count_df(pdfs_download_df, "year")
county_year_count <- create_count_df(pdfs_download_df, "county", "year")
judge_year_count <- create_count_df(pdfs_download_df, "county", "judge_id", "year")

graph_year <-
    ggplot(year_count, aes(x = year, y = prcnt)) +
    geom_point() +
    geom_line() +
    theme_bw() +
    labs(x = "Year", y = "Percentage failed to download")
ggsave(filename = "year.png", plot = graph_year, path = graph_dir, width = 12, height = 8)

graph_county_year <-
    ggplot(county_year_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = county)) +
    geom_line(aes(color = county, group = county), alpha = 0.3) +
    theme_bw() +
    labs(x = "Year", y = "Percentage failed to download", color = "County") +
    theme(legend.position = "none") +
    geom_point(data = year_count, aes(x = year, y = prcnt), color = "black") +
    geom_line(data = year_count, aes(x = year, y = prcnt), color = "black")
ggsave(filename = "county_year.png", plot = graph_county_year, path = graph_dir, width = 12, height = 8)

graph_county_year_facet <-
    ggplot(county_year_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = county)) +
    geom_line(aes(color = county, group = county), alpha = 0.3) +
    theme_bw() +
    labs(x = "Year", y = "Percentage failed to download", color = "County") +
    theme(legend.position = "none") +
    facet_wrap(~county) +
    geom_line(data = year_count, aes(x = year, y = prcnt), color = "black")
ggsave(filename = "county_year_facet.png", plot = graph_county_year_facet, path = graph_dir, width = 25, height = 12)

graph_judge_year <-
    ggplot(judge_year_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = judge_id), size = 1) +
    geom_line(aes(color = judge_id, group = judge_id), alpha = 0.4) +
    facet_wrap(~county, scales = "free_y") +
    theme_bw() +
    labs(x = "Year", y = "Percentage failed to download", color = "Court Office") +
    theme(legend.position = "none") +
    geom_line(data = county_year_count, aes(x = year, y = prcnt), color = "black")
ggsave(filename = "judge_year.png", plot = graph_judge_year, path = graph_dir, width = 25, height = 12)

# Year crossed by case type and court type.
year_caseType_count <-
    create_count_df(pdfs_download_df, "year", "case_type") %>%
    bind_rows(year_count) %>%
    mutate(case_type = if_else(is.na(case_type), "all", case_type))

year_courtType_count <-
    create_count_df(pdfs_download_df, "year", "court_type") %>%
    bind_rows(year_count) %>%
    mutate(court_type = if_else(is.na(court_type), "all", court_type))

graph_year_caseType <-
    ggplot(year_caseType_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = case_type)) +
    geom_line(aes(color = case_type, group = case_type)) +
    theme_bw() +
    labs(x = "Case Type")
ggsave(filename = "year_caseType.png", plot = graph_year_caseType, path = graph_dir, width = 12, height = 8)

graph_year_courtType <-
    ggplot(year_courtType_count, aes(x = year, y = prcnt)) +
    geom_point(aes(color = court_type)) +
    geom_line(aes(color = court_type, group = court_type)) +
    theme_bw() +
    labs(x = "Court Type")
ggsave(filename = "year_courtType.png", plot = graph_year_courtType, path = graph_dir, width = 12, height = 8)
