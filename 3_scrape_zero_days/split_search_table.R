library(here)
library(purrr)
library(dplyr)
library(readr)

# Read in the search table.
search_table_dir <- here("output", "search_tables")
search_table_name <- "all_counties_0_days"
search_table <-
    read_csv(file.path(search_table_dir, paste0(search_table_name, ".csv")))

# Determine how many chunks to split the data into.
max_nr_searches <- 48 * 60 * 60 / 13
nr_groups <- ceiling(nrow(search_table) / max_nr_searches)

# Split the search table up into chunks.
search_table_split <-
  search_table %>% 
  mutate(chunk = ntile(n = nr_groups)) %>%
  group_split(chunk) %>%
  map(function(df) {df %>% select(-chunk)})

# Save each of the component chunks.
walk(
  0:(length(search_table_split) - 1),
  function(list_of_chunks, save_dir, table_name, index) {
    write_csv(
      list_of_chunks[[index + 1]],
      file.path(save_dir, paste0(table_name, "_part_", index, ".csv"))
    )
  },
  list_of_chunks = search_table_split,
  save_dir = search_table_dir,
  table_name = search_table_name
)
