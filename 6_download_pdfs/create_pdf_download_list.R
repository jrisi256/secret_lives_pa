library(here)
library(dplyr)
library(purrr)
library(readr)
library(tidyr)
library(dtplyr)
library(stringr)
library(lubridate)
library(data.table)

# Find tar files.
tar_dir <- here("output", "scraped_tables", "tar_gz")
files <- list.files(tar_dir, full.names = T)
old_csv <- files[str_detect(files, "csv")]
tar_files <- files[!str_detect(files, "csv")]

# Unzip tar files.
table_dir <- here("output", "scraped_tables", "all_tables")
if(!dir.exists(table_dir)) {dir.create(table_dir)}

walk(
  tar_files,
  function(tar_file, path) {untar(tar_file, exdir = path)},
  path = table_dir
)

# Read in all the court case tables.
csv_files <- list.files(table_dir, full.names = T)
csv_files <- csv_files[str_detect(csv_files, "csv")]
csv_files <- c(csv_files, old_csv)
court_cases <- map(csv_files, function(csv) {fread(csv)})

# Bind together all the court case tables.
court_cases_df <-
  map(
    court_cases,
    function(df) {
      df %>%
        as_tibble() %>%
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

if(!dir.exists(here("output", "pdf_download_list"))) {dir.create(here("output", "pdf_download_list"))}
saveRDS(court_cases_df, here("output", "pdf_download_list", "all_cases_no_fltr.rds"))

court_cases_df <-
  court_cases_df %>%
  lazy_dt() %>%
  filter(docket_number != "No results found") %>%
  filter(!str_detect(docket_sheet_link, "NA$")) %>%
  mutate(filing_date = mdy(filing_date)) %>%
  filter(county != "Adams" | filing_date >= mdy("11/22/2004")) %>%
  filter(county != "Allegheny" | filing_date >= mdy("2/28/2006")) %>%
  filter(county != "Armstrong" | filing_date >= mdy("1/12/2004")) %>%
  filter(county != "Beaver" | filing_date >= mdy("2/9/2004")) %>%
  filter(county != "Bedford" | filing_date >= mdy("3/8/2004")) %>%
  filter(county != "Berks" | filing_date >= mdy("6/6/2005")) %>%
  filter(county != "Blair" | filing_date >= mdy("9/19/2005")) %>%
  filter(county != "Bradford" | filing_date >= mdy("7/5/2005")) %>%
  filter(county != "Bucks" | filing_date >= mdy("1/3/2006")) %>%
  filter(county != "Butler" | filing_date >= mdy("2/17/2004")) %>%
  filter(county != "Cambria" | filing_date >= mdy("3/15/2004")) %>%
  filter(county != "Cameron" | filing_date >= mdy("3/29/2004")) %>%
  filter(county != "Carbon" | filing_date >= mdy("8/22/2005")) %>%
  filter(county != "Centre" | filing_date >= mdy("3/28/2005")) %>%
  filter(county != "Chester" | filing_date >= mdy("2/6/2006")) %>%
  filter(county != "Clarion" | filing_date >= mdy("1/12/2004")) %>%
  filter(county != "Clearfield" | filing_date >= mdy("11/7/2005")) %>%
  filter(county != "Clinton" | filing_date >= mdy("8/1/2005")) %>%
  filter(county != "Columbia" | filing_date >= mdy("8/15/2005")) %>%
  filter(county != "Crawford" | filing_date >= mdy("1/26/2004")) %>%
  filter(county != "Cumberland" | filing_date >= mdy("11/17/2003")) %>%
  filter(county != "Dauphin" | filing_date >= mdy("10/11/2005")) %>%
  filter(county != "Delaware" | filing_date >= mdy("12/19/2005")) %>%
  filter(county != "Elk" | filing_date >= mdy("3/15/2004")) %>%
  filter(county != "Erie" | filing_date >= mdy("8/1/2005")) %>%
  filter(county != "Fayette" | filing_date >= mdy("2/23/2004")) %>%
  filter(county != "Forest" | filing_date >= mdy("3/22/2004")) %>%
  filter(county != "Franklin" | filing_date >= mdy("10/3/2005")) %>%
  filter(county != "Fulton" | filing_date >= mdy("9/6/2005")) %>%
  filter(county != "Greene" | filing_date >= mdy("1/20/2004")) %>%
  filter(county != "Huntingdon" | filing_date >= mdy("10/24/2005")) %>%
  filter(county != "Indiana" | filing_date >= mdy("2/2/2004")) %>%
  filter(county != "Jefferson" | filing_date >= mdy("2/23/2004")) %>%
  filter(county != "Juniata" | filing_date >= mdy("2/28/2005")) %>%
  filter(county != "Lackawanna" | filing_date >= mdy("1/24/2005")) %>%
  filter(county != "Lancaster" | filing_date >= mdy("5/16/2005")) %>%
  filter(county != "Lawrence" | filing_date >= mdy("2/2/2004")) %>%
  filter(county != "Lebanon" | filing_date >= mdy("2/22/2005")) %>%
  filter(county != "Lehigh" | filing_date >= mdy("7/25/2005")) %>%
  filter(county != "Luzerne" | filing_date >= mdy("12/5/2005")) %>%
  filter(county != "Lycoming" | filing_date >= mdy("2/22/2005")) %>%
  filter(county != "McKean" | filing_date >= mdy("2/23/2004")) %>%
  filter(county != "Mercer" | filing_date >= mdy("1/18/2005")) %>%
  filter(county != "Mifflin" | filing_date >= mdy("1/18/2005")) %>%
  filter(county != "Monroe" | filing_date >= mdy("4/25/2005")) %>%
  filter(county != "Montgomery" | filing_date >= mdy("4/4/2005")) %>%
  filter(county != "Montour" | filing_date >= mdy("8/29/2005")) %>%
  filter(county != "Northampton" | filing_date >= mdy("10/17/2005")) %>%
  filter(county != "Northumberland" | filing_date >= mdy("7/25/2005")) %>%
  filter(county != "Perry" | filing_date >= mdy("4/4/2005")) %>%
  filter(county != "Philadelphia" | filing_date >= mdy("9/18/2006")) %>%
  filter(county != "Pike" | filing_date >= mdy("9/12/2005")) %>%
  filter(county != "Potter" | filing_date >= mdy("5/23/2005")) %>%
  filter(county != "Schuylkill" | filing_date >= mdy("1/24/2005")) %>%
  filter(county != "Snyder" | filing_date >= mdy("6/6/2005")) %>%
  filter(county != "Somerset" | filing_date >= mdy("9/6/2005")) %>%
  filter(county != "Sullivan" | filing_date >= mdy("5/23/2005")) %>%
  filter(county != "Susquehanna" | filing_date >= mdy("11/14/2005")) %>%
  filter(county != "Tioga" | filing_date >= mdy("2/28/2005")) %>%
  filter(county != "Union" | filing_date >= mdy("5/9/2005")) %>%
  filter(county != "Venango" | filing_date >= mdy("3/1/2004")) %>%
  filter(county != "Warren" | filing_date >= mdy("3/1/2004")) %>%
  filter(county != "Washington" | filing_date >= mdy("6/20/2005")) %>%
  filter(county != "Wayne" | filing_date >= mdy("6/20/2005")) %>%
  filter(county != "Westmoreland" | filing_date >= mdy("12/8/2003")) %>%
  filter(county != "Wyoming" | filing_date >= mdy("4/18/2005")) %>%
  filter(county != "York" | filing_date >= mdy("11/28/2004")) %>%
  as_tibble()

court_cases_df <-
  court_cases_df %>%
  select(-court_type) %>%
  separate_wider_delim(
    cols = docket_number,
    delim = "-",
    names = c("court_type", "judge_id", "case_type", "case_id", "docket_year"),
    cols_remove = F
  ) %>%
  lazy_dt() %>%
  mutate(
    filing_year = year(filing_date),
    filing_month = month(filing_date),
    filing_day = day(filing_date),
    filing_wday = wday(filing_date)
  ) %>%
  as_tibble()

cr <- court_cases_df %>% lazy_dt() %>% filter(case_type == "CR") %>% as_tibble()
lt <- court_cases_df %>% lazy_dt() %>% filter(case_type == "LT") %>% as_tibble()
other <- court_cases_df %>% lazy_dt() %>% filter(case_type != "LT" & case_type != "CR") %>% as_tibble()

saveRDS(cr, here("output", "pdf_download_list", "criminal_cases.rds"))
saveRDS(lt, here("output", "pdf_download_list", "landlord_tenant_cases.rds"))
saveRDS(other, here("output", "pdf_download_list", "other_cases.rds"))

cr_links <- cr %>% select(docket_sheet_link, court_summary_link)
lt_links <- lt %>% select(docket_sheet_link, court_summary_link)
other_links <- other %>% select(docket_sheet_link, court_summary_link)
write_csv(cr_links, here("output", "pdf_download_list", "criminal_pdf_links.csv"))
write_csv(lt_links, here("output", "pdf_download_list", "lt_pdf_links.csv"))
write_csv(other_links, here("output", "pdf_download_list", "other_pdf_links.csv"))
