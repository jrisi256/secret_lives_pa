library(here)
library(dplyr)
library(readr)
library(stringr)

# Read in the final search table.
search_table <-
  read_csv(
    here("output", "search_tables", "all_counties_0_days_too_many_mdjs.csv")
  )

# These are the tables which need to be removed.
cases_to_remove_vector <-
  paste0(
    search_table$county, "_", search_table$begin_date, "_", search_table$end_date
  )

# Find all tables.
case_tables <-
  list.files(
    here("output", "scraped_tables"),
    pattern = "^[A-Za-z]*_[0-9]{4}"
  )

# Get the base name for each of the tables.
case_table_base_names <-
  str_extract(
    case_tables,
    "^[A-Za-z]*_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{4}-[0-9]{2}-[0-9]{2}"
  )

# Find those tables which need to be removed.
case_tables_to_be_removed <-
  case_tables[case_table_base_names %in% cases_to_remove_vector]

# Remove those tables.
file.remove(file.path("output", "scraped_tables", case_tables_to_be_removed))
