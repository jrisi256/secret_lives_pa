library(here)
library(dplyr)
library(rvest)
library(purrr)
library(readr)
library(RSelenium)

##################################################################
##         Read in search table and set-up directories.         ##
##################################################################
search_table_dir <- here("scrape_links", "output", "search_tables")
log_table_dir <- here("scrape_links", "output", "log_tables")
scraped_table_dir <- here("scrape_links", "output", "scraped_tables")
if(!dir.exists(scraped_table_dir)) {dir.create(scraped_table_dir)}
if(!dir.exists(log_table_dir)) {dir.create(log_table_dir)}
search_table <- read_csv(here(search_table_dir, "all_counties_6_months.csv"))

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
    
    print(paste0("START DATE: ", start_date))
    print(paste0("END DATE: ", end_date))
    print(paste0("COUNTY: ", county))
    
    # Click on advanced search check box
    browser$findElements("name", "AdvanceSearch")[[1]]$clickElement()
    print("CLICKED ADVANCE SEARCH TEXT BOX")
    
    # Enter start dates and end dates
    sdate_box <- browser$findElement(using = "name", value = "FiledStartDate")
    sdate_box$sendKeysToElement(list(start_date))
    print("ENTERED START DATE")
    
    enddate_box <- browser$findElement(using = "name", value = "FiledEndDate")
    enddate_box$sendKeysToElement(list(end_date))
    print("ENTERED END DATE")
    
    # Click on county selection drop-down menu
    browser$findElement(
        using = "xpath",
        value = "/html[1]/body[1]/div[3]/div[2]/div[1]/form[1]/div[10]/div[2]/select[1]"
    )$clickElement()
    print("CLICKED ON COUNTY SELECTION DROP DOWN")
    
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
    print("SELECTED COUNTY")
    
    # Search for court cases
    searchBtn <- browser$findElements("id", "btnSearch")[[1]]
    searchBtn$clickElement()
    print("CLICKED SEARCH BUTTON")
    
    # The page errors. Perhaps the code executes faster then the page can load?
    while(length(browser$getPageSource()) == 0) {
        print("BROwSER PAGE SOURCE ERROR. WAITING FOR PAGE TO LOAD.")
        Sys.sleep(1)
    }
    
    # Sometimes the web page errors. We are likely making too many requests.
    unauthorized_request <-
        browser$getPageSource()[[1]] %>%
        read_html() %>%
        html_nodes("pre") %>%
        html_text()
    
    # If we do receive the unauthorized request error...
    if(length(unauthorized_request) != 0) {
        print("UNAUTHORIZED REQUEST")
        
        # Refresh the page.
        browser$refresh()
        print("REFRESHED BROWSER")
        
        # Accept the modal dialog pop-up box.
        browser$acceptAlert()
        print("ACCEPTED DIALOG BOX")
        
        # Look for the search button.
        searchBtn <- browser$findElements("id", "btnSearch")[[1]]
        
        # Need to wait for web page to load. Keep looking for search button.
        while(length(searchBtn) == 0) {
            searchBtn <- browser$findElements("id", "btnSearch")[[1]]
        }
        
        # Once the search button has loaded, click it.
        searchBtn$clickElement()
        print("CLICKED SEARCH BUTTON AFTER UNAUTHORIZED REQUEST")
    }
    
    # Waiting for the page to load.
    court_cases_df <- list()
    while(length(court_cases_df) == 0) {
        court_cases_df <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements("#caseSearchResultGrid") %>%
            html_table()
    }
    print("COURT CASES LOADED")
    
    # A box will appear telling us if there are too many cases to display.
    too_many_cases <-
        browser$findElements(
            using="xpath",
            value="/html[1]/body[1]/div[3]/div[3]/div[1]/div[3]/table[1]/caption[1]"
        )
    
    # If the length is not 0, the box appeared. There are too many cases.
    if(length(too_many_cases) != 0) {
        too_many_cases <- T
        print("THERE ARE TOO MANY CASES")
    }
    
    # If there are not too many cases, scrape and download the table of cases.
    if(!too_many_cases) {
        # Extract docket numbers to see if there are cases in the date range.
        court_cases_df <- court_cases_df[[1]]
        court_cases_df <- court_cases_df[-c(1, 2, 19)]
        court_cases_df <-
            court_cases_df %>%
            mutate(start_date = start_date, end_date = end_date)
        docket_nrs <- court_cases_df %>% pull(`Docket Number`)
        
        # Collect PDF download links if there being PDFs to download.
        if(docket_nrs[1] != "No results found") {
            # Extract links to download PDFs.
            links <-
                browser$getPageSource()[[1]] %>%
                read_html() %>%
                html_nodes('a') %>%
                html_attr('href')
            
            durl <- "https://ujsportal.pacourts.us"
            docket_sheet_links <- paste0(durl, str_subset(links, 'DocketSheet'))
            court_summary_links <- paste0(durl, str_subset(links, 'CourtSummary'))
            
            # Add links to our table.
            court_cases_df <-
                court_cases_df %>%
                mutate(
                    docket_sheet_link = docket_sheet_links,
                    court_summary_link = court_summary_links
                )
        }
        
        # Save the table of cases.
        write_csv(
            court_cases_df,
            here(save_dir, paste0(county_name, "_", start_date, "_", end_date))
        )
        print("SCRAPED TABLE OF COURT CASES")
    }
    
    # Reset the search field
    browser$findElements("id", "btnReset")[[1]]$clickElement()
    print("RESET THE SEARCH FIELD\n")
    
    return(
        tibble(
            start_date = start_date,
            end_date = end_date,
            county_id = county,
            too_many_cases = too_many_cases
        )
    )
}

#################################################################
##                Scrape court cases by county.                ##
#################################################################
scrape_cases_by_county <- function(df, target_county, browser) {
    # Keep only those dates associated with the target county.
    df <- df %>% filter(county == target_county) %>% arrange(begin_date)
    
    # For each pair of dates in the current county...
    for(i in 1:nrow(df)) {
        # Scrape the table of court cases.
        too_many_cases_list <-
            pmap(
                list(
                    as.list(df$begin_date)[i],
                    as.list(df$end_date)[i],
                    as.list(df$county_id)[i]
                ),
                scrape_table,
                browser = browser
            )
        
        too_many_cases_flag <- too_many_cases_list[[1]]$too_many_cases
        
        # If the date pair had too many cases, assume all future dates would as well.
        if(too_many_cases_flag) {
            result <- df[i:nrow(df),] %>% mutate(too_many_cases = too_many_cases_flag)
            write_csv(result, dir)
            break
        # If the date pair does not have too many cases, continue on.
        } else if(!too_many_cases_flag) {
            result <- df[i,] %>% mutate(too_many_cases = too_many_cases_flag)
            write_csv(result, dir)
        }
    }
}

# Check and see if the 6-month search range works for each county-date record.
test <-
    county_and_dates %>%
    filter(county %in% c("Adams", "Allegeheny", "Armstrong"), begin_date >= ymd("1990-02-21"))

six_month_check <-
    map(
        county_and_dates$county,
        check_by_county,
        df = test,
        browser = rd_client
    )

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()

#' TO DO
#' Add changes to 1899_1949 scraper.
#' Somehow save the results so it can restart itself in the case of a crash?