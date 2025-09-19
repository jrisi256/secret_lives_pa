library(here)
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(R.utils)
library(stringr)

################################################################################
# Create list of PDF files.
################################################################################
pdf_dir <- file.path("/media", "joe", "T7 Shield", "new_pdf_struct")
out_dir <- here("output", "pdf_sample")
chunk_dir <- here(out_dir, "pdf_chunk_lists")
pdfs <- list.files(path = pdf_dir, recursive = T, full.names = T)

################################################################################
# Create data frame of PDF files we will use for logging.
################################################################################
pdf_df <-
    tibble(path = pdfs) %>%
    separate_wider_delim(
        cols = path,
        delim = "/",
        names = c(
            "junk1", "junk2",  "junk3", "junk4", "junk5", "county", "year",
            "pdf_type", "court_type", "case_type", "file_name"
        ),
        cols_remove = F
    ) %>%
    select(-matches("junk")) %>%
    mutate(id = str_remove(file_name, "ds_|cs_"))

write_csv(pdf_df, file.path(out_dir, "pdf_parse_table.csv"))
gzip(file.path(out_dir, "pdf_parse_table.csv"), overwrite = T)

################################################################################
# Create data frame of sample PDF files.
################################################################################
set.seed(420)

sample_pdf_df <-
    pdf_df %>%
    # Narrow the sample down to only target counties, years, and case types.
    filter(
        (
            year %in% c(2005, 2010, 2014, 2019, 2023) &
            county %in% c("Blair", "Centre", "Dauphin", "Montgomery", "Erie")
        ) |
        (
            year %in% c(2006, 2010, 2014, 2019, 2023) &
            county  == "Allegheny"
        ),
        case_type == "CR"
    ) %>%
    group_by(id) %>%
    # PDFs which were redacted could still have their court summaries downloaded.
    filter(n() == 2) %>%
    ungroup() %>%
    distinct(id, .keep_all = T) %>%
    select(-pdf_type, -file_name, -path) %>%
    # Randomly sample 9. Some groupings have less than 9 observations.
    group_by(county, year, court_type) %>%
    slice_sample(n = 9) %>%
    ungroup() %>%
    left_join(select(pdf_df, pdf_type, file_name, path, id), by = "id") |>
    mutate(successfully_parsed = F)

write_csv(sample_pdf_df, file.path(out_dir, "sample_pdf_table.csv"))

if(!(dir.exists(here("output", "pdf_sample")))) {
    dir.create(here("output", "pdf_sample"))
}

pwalk(
    list(list(sample_pdf_df$path), list(sample_pdf_df$file_name)),
    function(orig_path, file_name) {
        file.copy(orig_path, here("output", "pdf_sample", file_name))
    }
)

################################################################################
# Chunk up the sample for parsing.
################################################################################
args <-
    expand_grid(
        county = c("Allegheny", "Blair", "Centre", "Dauphin", "Montgomery", "Erie"),
        court_type = c("CP", "MJ"),
        pdf_type = c("cs", "ds")
    )

if(!(dir.exists(here("output", "pdf_sample", "pdf_chunk_lists")))) {
    dir.create(here("output", "pdf_sample"))
}

pwalk(
    list(args$county, args$court_type, args$pdf_type),
    function(county_arg, court_type_arg, pdf_type_arg, df, dir) {
        df <-
            df |>
            filter(county == county_arg, court_type == court_type_arg, pdf_type == pdf_type_arg) |>
            select(file_name, succesfully_parsed) |>
            write_csv(
                file.path(dir, paste0(county_arg, "_", court_type_arg, "_", pdf_type_arg, ".csv"))
            )
    },
    df = sample_pdf_table,
    dir = chunk_dir
)
