library(here)
library(dplyr)
library(purrr)
library(tidyr)
library(readr)
library(stringr)
library(pdftools)

pdf_dir <-
    file.path(
        "/media", "joe", "4TB SSD", "joe_pdfs", "OneDrive - The Pennsylvania State University",
        "SecretLives", "Joe's Folder", "pdf_download_list", "pdfs", "pdfs_2025_04_05_p3"
    )

new_pdf_dir <-
    file.path(
        "/media", "joe", "4TB SSD", "joe_pdfs", "OneDrive - The Pennsylvania State University",
        "SecretLives", "Joe's Folder", "pdf_download_list", "new_organization"
    )

################################################################################
# Find and read in all PDF files.
################################################################################
pdf_paths <- list.files(path = pdf_dir, full.names = T, recursive = T)
pdf_filenames <- list.files(path = pdf_dir, full.names = F, recursive = T)
pdf_success <-
    map(
        pdf_paths,
        function(pdf_path) {
            attempt <- try(pdf_text(pdf_path))
            if_else(class(attempt) == "try-error", F, T)
        }
    )

################################################################################
# Create new folder structure to save the PDFs.
################################################################################
pdf_paths_df <-
    tibble(
        pdf_name = str_replace(pdf_filenames, "pdfs/", ""),
        date_scraped = "pdfs_2025_04_05_p3",
        successfully_scraped = unlist(pdf_success),
        old_path = unlist(pdf_paths)
    ) %>%
    ungroup() %>%
    separate_wider_delim(
        pdf_name,
        delim = "_",
        names =
            c(
                "pdf_type", "county", "court_type", "judge_id", "case_type",
                "case_id", "year"
            ),
        cols_remove = F
    ) %>%
    mutate(
        year = str_remove(year, ".pdf"),
        new_path =
            if_else(
                successfully_scraped,
                file.path(new_pdf_dir, county, year, pdf_type, court_type, case_type, pdf_name),
                file.path(new_pdf_dir, "junk", pdf_name)
            )
    )

# Save PDF results.
pwalk(
    list(pdf_paths_df$old_path, pdf_paths_df$new_path),
    function(old_path, new_path) {
        if (!dir.exists(dirname(new_path))) dir.create(dirname(new_path), recursive = TRUE) 
        file.copy(old_path, new_path)
    }
)

# Create list of PDFs which were successfully downloaded.
full_case_list_df<-
    pdf_paths_df %>%
    group_by(pdf_name, county, year, pdf_type, court_type, case_type, judge_id, case_id) %>%
    summarise(successfully_scraped = any(successfully_scraped)) %>%
    ungroup()
write_csv(
    full_case_list_df,
    file.path(new_pdf_dir, "case_download_status.csv")
)

# pdf_df <-
#     tibble(
#         pdf_name = str_replace(pdf_filenames, "pdfs_2025_0[2-4]_[0-9]{2}(_p[0-9]+)?/pdfs/", ""),
#         date_scraped = str_extract(pdf_filenames, "pdfs_2025_0[2-4]_[0-9]{2}"),
#         successfully_scraped = unlist(pdf_success),
#         old_path = unlist(pdf_paths)
#     )
