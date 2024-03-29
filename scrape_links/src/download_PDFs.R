library(here)
library(dplyr)
library(readr)
library(purrr)
library(stringr)
library(foreach)
library(parallel)
library(doParallel)

#################################################################
##                  Create directory for PDFs                  ##
#################################################################
if(!dir.exists(here("scrape_links", "output", "pdfs"))) {
    dir.create(here("scrape_links", "output", "pdfs"))
}

#################################################################
##   Read in the scraped tables to obtain the download links   ##
#################################################################
scraped_tables <- list.files(here("scrape_links", "output", "scraped_tables"))
scraped_tables_names <- str_replace(scraped_tables, ".csv", "")
names(scraped_tables) <- scraped_tables_names
scraped_table_list <-
    map(
        scraped_tables,
        function(file_name) {
            read_csv(here("scrape_links", "output", "scraped_tables", file_name))
        }
    ) %>%
    bind_rows() %>%
    filter(
        `Docket Number` != "No results found",
        !is.na(docket_sheet_link)
    )

#################################################################
##                      Download the PDFs                      ##
#################################################################
# Read in links
docket_sheets <- scraped_table_list$docket_sheet_link
court_summaries <- scraped_table_list$court_summary_link
docket_nrs <-
    here(
        "scrape_links",
        "output",
        "pdfs",
        paste0(scraped_table_list$`Docket Number`, ".pdf")
    )

# Detect number of cores available
nrCores <- detectCores()

system("resolvectl flush-caches")

# Estimate about 6 seconds per download.
start_time_serial <- Sys.time()
pwalk(
    list(as.list(docket_sheets)[1:48], as.list(docket_nrs)[1:48]),
    function(url, file_name) {
        download.file(url, file_name, method = "wget", extra = "--no-cookies --no-cache --no-dns-cache")
    }
)
end_time_serial <- Sys.time()
completion_time_serial <- end_time_serial - start_time_serial

# Using mcapply reduces execution time by 50% when using 12 cores.
start_time_mcapply <- Sys.time()
mcmapply(
    function(url, file_name) {download.file(url, file_name)},
    as.list(docket_sheets)[1:48],
    as.list(docket_nrs)[1:48]
)
end_time_mcapply <- Sys.time()
completion_time_mcapply <- end_time_mcapply - start_time_mcapply

#
cluster <- makeCluster(nrCores)
registerDoParallel(cluster)

start_time_foreach <- Sys.time()
foreach(i = 1:nrow(scraped_table_list[1:48,])) %dopar% {
    download.file(
        docket_sheets[i], docket_nrs[i], method = "wget", extra = "--no-cookies --no-cache --no-dns-cache")
}
end_time_foreach <- Sys.time()
completion_time_foreach <- end_time_foreach - start_time_foreach
