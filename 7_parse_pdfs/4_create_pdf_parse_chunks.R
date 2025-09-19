library(here)
library(readr)
library(tidyr)
library(dplyr)
library(purrr)

# Read in the master list of all PDFs to be parsed.
pdf_parse_table <-
    read_csv(here("output", "pdf_parse_list", "pdf_parse_table.csv.gz"))

# Chunk the master list into smaller sub-tables which will be fed to the parser.
pdf_parse_chunks <-
    pdf_parse_table |>
    nest(.by = c("county", "pdf_type", "court_type", "case_type")) |>
    mutate(
        data =
            map(
                data,
                function(df) {
                    df |> select(file_name) |> mutate(successfully_parsed = F)
                }
            )
        )

# Save the smaller sub-tables.
pwalk(
    list(
        pdf_parse_chunks$county, pdf_parse_chunks$pdf_type,
        pdf_parse_chunks$court_type, pdf_parse_chunks$case_type,
        pdf_parse_chunks$data
    ),
    function(county, pdf_type, court_type, case_type, df, dir) {
        write_csv(
            df,
            file.path(
                dir,
                paste0(
                    county, "_", pdf_type, "_", court_type, "_", case_type,
                    "_chunkList.csv"
                )
            )
        )
    },
    dir = here("output", "pdf_parse_list", "pdf_chunk_lists")
)
