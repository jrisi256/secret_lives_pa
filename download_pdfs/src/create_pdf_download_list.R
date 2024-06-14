library(here)
library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(R.utils)
library(data.table)
read_path <- here("scrape_links", "output", "scraped_tables")
out_path <- here("download_pdfs", "output")

# Extract the contents of all the zipped files
tar_files <- list.files(read_path, full.names = T)
tar_files <- tar_files[!str_detect(tar_files, "csv")]
walk(
    tar_files,
    function(tar_file, path) {untar(tar_file, exdir = path)},
    path = read_path
)

# Get list of all court case tables
files <- list.files(read_path, full.names = T)
csv_files <- files[str_detect(files, "csv")]

# Read in all court cases
court_cases <- map(csv_files, function(csv, path) {fread(csv)})

# Combine all court cases into one table
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

# Write out all court cases
write_csv(court_cases_df, file.path(out_path, "court_cases_df.csv"))
gzip(file.path(out_path, "court_cases_df.csv"), overwrite = T)
