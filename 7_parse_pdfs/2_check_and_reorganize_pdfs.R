library(here)
library(dplyr)
library(purrr)
library(tidyr)
library(readr)
library(stringr)
library(pdftools)

# Set up the PDF directories
pdf_dir <-
    file.path(
        "/media", "joe", "T7 Shield", "OneDrive - The Pennsylvania State University",
        "SecretLives", "Joe's Folder", "pdf_download_list", "pdfs"
    )

new_pdf_dir <- file.path("/media", "joe", "T7 Shield", "new_pdf_struct")

# Find all PDF folders.
pdf_folders <- list.files(pdf_dir, full.names = T, recursive = F)

# For each PDF folder, do the following.
walk(
    pdf_folders,
    function(pdf_path, new_pdf_path) {
        # Find every PDF file in the current directory.
        pdf_files <- list.files(path = pdf_path, full.names = F, recursive = T)
        full_pdf_file_paths <- file.path(pdf_path, pdf_files)
        
        # Attempt to read in the PDFs.
        pdf_success <-
            map(
                full_pdf_file_paths,
                function(pdf_file) {
                    attempt <- try(pdf_text(pdf_file))
                    if_else(class(attempt) == "try-error", F, T)
                }
            )
        
        # Create a data frame which tracks if each PDF was successfully scraped.
        pdf_paths_df <-
            tibble(
                pdf_name = str_replace(pdf_files, "pdfs/", ""),
                date_scraped = str_extract(pdf_path, "pdfs_2025_0[2-4]_[0-9]{2}"),
                successfully_scraped = unlist(pdf_success),
                old_path = full_pdf_file_paths
            ) %>%
            # Using the name of the PDF, we can generate characteristics of the case.
            separate_wider_delim(
                pdf_name,
                delim = "_",
                names = c("pdf_type", "county", "court_type", "judge_id", "case_type", "case_id", "year"),
                cols_remove = F
            ) %>%
            # Create new directory to store the PDF based on its characteristics.
            mutate(
                year = str_remove(year, ".pdf"),
                new_path =
                    if_else(
                        successfully_scraped,
                        file.path(new_pdf_path, county, year, pdf_type, court_type, case_type, pdf_name),
                        file.path(new_pdf_path, "junk", pdf_name)
                    )
            )
        
        # Move PDFs from their old directory to their new directory.
        pwalk(
            list(pdf_paths_df$old_path, pdf_paths_df$new_path),
            function(old_path, new_path) {
                if (!dir.exists(dirname(new_path))) dir.create(dirname(new_path), recursive = T) 
                file.rename(old_path, new_path)
            }
        )
    },
    new_pdf_path = new_pdf_dir
)
