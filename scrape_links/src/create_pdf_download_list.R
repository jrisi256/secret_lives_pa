library(here)
library(dplyr)
library(purrr)
library(readr)
library(dtplyr)
library(stringr)
library(R.utils)
library(lubridate)
library(data.table)
path <- here("scrape_links", "output")

dirs <- list.dirs(here("scrape_links", "output"))
files <- list.files(dirs, full.names = T)
csv_files <- files[str_detect(files, "csv")]

court_cases <- map(csv_files, function(csv, path) {fread(csv)})

court_cases_df <-
    map(court_cases,
        function(df) {
            df %>%
                rename_with(
                    function(col) {tolower(str_replace_all(str_replace_all(str_replace_all(col, " ", "_"), "\\(|\\)|\\?", ""), "#", "nr"))}
                ) %>%
                mutate(
                    across(
                        matches("number|type|caption|status|primary|county|office|otn|complaint|incident|event|link"),
                        ~ as.character(.x)
                    )
                )
        }
    ) %>%
    bind_rows()

write_csv(court_cases_df, file.path(path, "court_cases_df.csv"))
gzip(file.path(path, "court_cases_df.csv"), overwrite = T)
