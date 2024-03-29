library(here)
library(dplyr)
library(rvest)
library(purrr)
library(readr)
library(stringr)
library(RSelenium)

##################################################################
##              Set up directories and file names.              ##
##################################################################
search_table_dir <- here("scrape_links", "output", "search_tables")
log_table_dir <- here("scrape_links", "output", "log_tables")
scraped_table_dir <- here("scrape_links", "output", "scraped_tables")
if(!dir.exists(scraped_table_dir)) {dir.create(scraped_table_dir, recursive = T)}
if(!dir.exists(log_table_dir)) {dir.create(log_table_dir, recursive = T)}

log_file <- "all_counties_6_months_log.csv"
progress_file <- "scrape_progress.txt"
web_browser <- "firefox"
search_table_name <- "all_counties_6_months.csv"

##################################################################
##      Read in search table and compare against log file.      ##
##################################################################
search_table <- read_csv(here(search_table_dir, search_table_name))

if(file.exists(here(log_table_dir, log_file))) {
    log_table <- read_csv(here(log_table_dir, log_file))
    search_table <- search_table %>% anti_join(log_table)
}

#################################################################
##                      Start web browser.                     ##
#################################################################
remote_driver <- rsDriver(browser = web_browser, port = 4545L, chromever = NULL)
rd_client <- remote_driver[["client"]]

##################################################################
##                     Navigate to website.                     ##
##################################################################
home_url <- "https://ujsportal.pacourts.us/CaseSearch"
rd_client$navigate(home_url)

# Search by date filed
rd_client$findElement(using = "id", value = "SearchBy-Control")$clickElement()
rd_client$findElement(
    using = "xpath",
    value = "/html[1]/body[1]/div[3]/div[2]/div[1]/form[1]/div[1]/div[2]/select[1]/option[7]"
)$clickElement()

############################################################################
##  Scrape the table of cases for a given date range for a given county.  ##
############################################################################
scrape_table <- function(start_date, end_date, county_name, county_id, browser, save_dir) {
    too_many_cases <- F
    
    cat(paste0("START DATE: ", start_date, "\n"))
    cat(paste0("END DATE: ", end_date, "\n"))
    cat(paste0("COUNTY: ", county_name, "\n"))
    
    # Click on advanced search check box
    browser$findElements("name", "AdvanceSearch")[[1]]$clickElement()
    cat("CLICKED ADVANCE SEARCH TEXT BOX\n")
    
    # Enter start dates and end dates
    sdate_box <- browser$findElement(using = "name", value = "FiledStartDate")
    sdate_box$sendKeysToElement(list(start_date))
    cat("ENTERED START DATE\n")
    
    enddate_box <- browser$findElement(using = "name", value = "FiledEndDate")
    enddate_box$sendKeysToElement(list(end_date))
    cat("ENTERED END DATE\n")
    
    # Click on county selection drop-down menu
    browser$findElement(
        using = "xpath",
        value = "/html[1]/body[1]/div[3]/div[2]/div[1]/form[1]/div[10]/div[2]/select[1]"
    )$clickElement()
    cat("CLICKED ON COUNTY SELECTION DROP DOWN\n")
    
    # Select the correct county
    browser$findElement(
        using="xpath",
        value =
            paste0(
                "/html[1]/body[1]/div[3]/div[2]/div[1]/form[1]/div[10]/div[2]/select[1]/option[",
                county_id,
                "]"
            )
        )$clickElement()
    cat("SELECTED COUNTY\n")
    
    # Search for court cases
    searchBtn <- browser$findElements("id", "btnSearch")[[1]]
    searchBtn$clickElement()
    cat("CLICKED SEARCH BUTTON\n")
    
    # Unauthorized request HTTP error.
    unauthorized_request <-
        browser$getPageSource()[[1]] %>%
        read_html() %>%
        html_nodes("pre") %>%
        html_text()
    
    # If we do receive the unauthorized request error...
    if(length(unauthorized_request) != 0) {
        cat("UNAUTHORIZED REQUEST\n")
        searchBtn <- list()
        
        # Go through recovery process to get back to scraping.
        while(length(searchBtn) == 0) {
            # Refresh the page.
            browser$refresh()
            cat("REFRESHED BROWSER\n")
            
            # Accept the modal dialog pop-up box.
            browser$acceptAlert()
            cat("ACCEPTED DIALOG BOX\n")
            
            # Look for the search button.
            browser$setTimeout(type = "implicit", milliseconds = 20000)
            searchBtn <- browser$findElements("id", "btnSearch")
        }
        
        # Once the search button has loaded, click it.
        browser$setTimeout(type = "implicit", milliseconds = 0)
        searchBtn[[1]]$clickElement()
        cat("CLICKED SEARCH BUTTON AFTER UNAUTHORIZED REQUEST\n")
    }
    
    # Waiting for the page to load.
    repeat{
        # Sometimes the web page errors. Code executes before page fully loads.
        court_cases_df <-
            try(
                browser$getPageSource()[[1]] %>%
                    read_html() %>%
                    html_elements("#caseSearchResultGrid") %>%
                    html_table(),
                silent = T
            )

        if(class(court_cases_df) == "list") {
            if(length(court_cases_df) != 0) {
                break
            # If the table is empty, an error won't be thrown.
            } else {
                next
            }
        } else {
            cat("BROwSER PAGE SOURCE ERROR. WAITING FOR PAGE TO LOAD.\n")
        }
    }
    cat("SEARCH HAS CONCLUDED\n")
    
    # A box will appear telling us if there are too many cases to display.
    too_many_cases_box <-
        browser$findElements(
            using="xpath",
            value="/html[1]/body[1]/div[3]/div[3]/div[1]/div[3]/table[1]/caption[1]"
        )

    # If the length is not 0, the box appeared. There are too many cases.
    if(length(too_many_cases_box) != 0) {
        too_many_cases <- T
        cat("THERE ARE TOO MANY CASES\n")
    }
    
    # If there are not too many cases, scrape the table of court cases.
    if(!too_many_cases) {
        # Check if there are any cases for the given date range.
        court_cases_df <- court_cases_df[[1]]
        no_results <- court_cases_df[[1,1]]

        # Collect PDF download links if there are PDFs to download.
        if(no_results != "No results found") {
            check_length <- c()
            
            # Ensure the table and links have properly loaded.
            while(nrow(court_cases_df) != length(check_length)) {
                links <-
                    browser$getPageSource()[[1]] %>%
                    read_html() %>%
                    html_nodes('a') %>%
                    html_attr('href')
                check_length <- str_subset(links, "DocketSheet")
                
                court_cases_df <-
                    browser$getPageSource()[[1]] %>%
                    read_html() %>%
                    html_elements("#caseSearchResultGrid") %>%
                    html_table()
                court_cases_df <- court_cases_df[[1]]
            }
            cat("COURT CASES AND LINKS HAVE FULLY LOADED\n")
            
            # Scrape the table and the links.
            durl <- "https://ujsportal.pacourts.us"
            docket_sheet_links <- paste0(durl, str_subset(links, 'DocketSheet'))
            court_summary_links <- paste0(durl, str_subset(links, 'CourtSummary'))
            
            court_cases_df <-
                court_cases_df[-c(1, 2, 19)] %>%
                mutate(
                    start_date = start_date,
                    end_date = end_date,
                    docket_sheet_link = docket_sheet_links,
                    court_summary_link = court_summary_links
                )
        } else {
            court_cases_df <-
                court_cases_df[-c(1, 2, 19)] %>%
                mutate(start_date = start_date, end_date = end_date)
            cat("NO COURT CASES IN THIS TIME RANGE FOR THIS COUNTY\n")
        }
        
        # Save the table of cases.
        write_csv(
            court_cases_df,
            here(
                save_dir,
                paste0(county_name, "_", start_date, "_", end_date, ".csv")
            ),
            progress = F
        )
        cat("SCRAPED TABLE OF COURT CASES\n")
    }
    
    # Reset the search field
    browser$findElements("id", "btnReset")[[1]]$clickElement()
    cat("RESET THE SEARCH FIELD\n\n")
    
    return(
        tibble(
            start_date = start_date,
            end_date = end_date,
            county_name = county_name,
            county_id = county_id,
            too_many_cases = too_many_cases
        )
    )
}

#################################################################
##                Scrape court cases by county.                ##
#################################################################
scrape_cases_by_county <- function(df, target_county, browser, scrape_dir, log_dir, out_file) {
    # Keep only those dates associated with the target county.
    df <- df %>% filter(county == target_county) %>% arrange(begin_date)
    
    sink(out_file, split = T)
    on.exit(sink())
    
    start_time <- Sys.time()
    # For each pair of dates in the current county...
    for(i in 1:nrow(df)) {
        # Scrape the table of court cases.
        too_many_cases_list <-
            pmap(
                list(
                    start_date = as.list(df$begin_date)[i],
                    end_date = as.list(df$end_date)[i],
                    county_name = as.list(df$county)[i],
                    county_id = as.list(df$county_id)[i]
                ),
                scrape_table,
                browser = browser,
                save_dir = scrape_dir
            )
        
        too_many_cases_flag <- too_many_cases_list[[1]]$too_many_cases
        
        # If the date pair had too many cases, assume all future dates would as well.
        if(too_many_cases_flag) {
            result <- df[i:nrow(df),] %>% mutate(too_many = too_many_cases_flag)
            write_csv(result, log_dir, append = T, col_names = !file.exists(log_dir), progress = F)
            break
        # If the date pair does not have too many cases, continue on.
        } else if(!too_many_cases_flag) {
            result <- df[i,] %>% mutate(too_many = too_many_cases_flag)
            write_csv(result, log_dir, append = T, col_names = !file.exists(log_dir), progress = F)
        }
    }
    end_time <- Sys.time()
    cat(paste0("TIME IT TOOK FOR SCRAPE TO COMPLETE: ", end_time - start_time))
}

#################################################################
##                       Begin scraping.                       ##
#################################################################
counties_list <- as.list(sort(unique(search_table$county)))
progress_files_list <-
    as.list(
        here(
            "scrape_links",
            "output",
            paste0(sort(unique(search_table$county)), "_", progress_file)
        )
    )

pwalk(
    list(target_county = counties_list, out_file = progress_files_list),
    scrape_cases_by_county,
    df = search_table,
    browser = rd_client,
    scrape_dir = scraped_table_dir,
    log_dir = here(log_table_dir, log_file)
)

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()
