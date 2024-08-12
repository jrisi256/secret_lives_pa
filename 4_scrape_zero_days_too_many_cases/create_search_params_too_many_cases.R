library(here)
library(dplyr)
library(readr)
library(purrr)
library(stringr)
library(data.table)

################################################################################
# Set browser and directories.
################################################################################
path_to_log_files <- here("output", "log_tables")
path_to_search_table <- here("output", "search_tables")
search_table_name <- "all_counties_0_days_too_many_cases.csv"

################################################################################
# Read in log files.
################################################################################
log_files <- list.files(path_to_log_files, full.names = T)
log_files <- log_files[str_detect(log_files, "part")]

log_table <-
    map(log_files, function(csv, path) {fread(csv)}) %>%
    bind_rows()

log_table_too_many <- log_table %>% filter(too_many) %>% select(-too_many)

################################################################################
# Create new search table. Save compiled log tables.
################################################################################
write_csv(log_table, here(path_to_log_files, "all_counties_0_days_log.csv"))
write_csv(log_table_too_many, here(path_to_search_table, search_table_name))
