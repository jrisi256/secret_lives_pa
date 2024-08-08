library(here)
library(dplyr)
library(purrr)
library(rvest)
library(readr)
library(stringr)
library(lubridate)
library(RSelenium)

#################################################################
##                      Start web browser.                     ##
#################################################################
web_browser <- "firefox"
remote_driver <-
    rsDriver(
        browser = web_browser,
        port = 4545L,
        chromever = NULL,
        extraCapabilities =
            list(
                makeFirefoxProfile(
                    list(
                        "browser.cache.disk.enable" = FALSE,
                        "browser.cache.memory.enable" = FALSE,
                        "browser.cache.offline.enable" = FALSE,
                        "network.http.use-cache" = FALSE,
                        "network.cookie.cookieBehavior" = 2
                    )
                ),
                `moz:firefoxOptions` = list(args = list("--headless"))
            )
    )
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

##################################################################
##          Create 6 month intervals for all counties.          ##
##################################################################
s_date <- mdy("01-01-1899")
s_date_str <- paste0("0", month(s_date), "-0", day(s_date), "-", year(s_date))
e_date <- s_date + days(180)
e_date_str <- paste0("0", month(e_date), "-", day(e_date), "-", year(e_date))
begin_dates <- list()
end_dates <- list()

if(web_browser == "chrome") {
    begin_dates <- append(begin_dates, s_date_str)
    end_dates <- append(end_dates, e_date_str)
} else if(web_browser == "firefox") {
    begin_dates <- append(begin_dates, as.character(s_date))
    end_dates <- append(end_dates, as.character(e_date))
}

while(T) {
    # update our beginning date
    s_date <- mdy(e_date_str) + days(1)
    
    # format day
    d_b <- day(s_date)
    d_b <- if_else(str_length(d_b) == 1, paste0("0", d_b), as.character(d_b))
    
    # format month
    m_b <- month(s_date)
    m_b <- if_else(str_length(m_b) == 1, paste0("0", m_b), as.character(m_b))
    
    # new search beginning date
    s_date_str <- paste0(m_b, "-", d_b, "-", year(s_date))
    
    if(web_browser == "chrome") {
        begin_dates <- append(begin_dates, s_date_str)
    } else if(web_browser == "firefox") {
        begin_dates <- append(begin_dates, as.character(s_date))
    }
    
    # update our end date
    e_date <- s_date + days(180)
    
    if(e_date >= mdy("01-01-1950")) {
        e_date <- ymd("1949-12-31")
        e_date_str <- "12-31-1949"
        
        if(web_browser == "chrome") {
            end_dates <- append(end_dates, e_date_str)
        } else if(web_browser == "firefox") {
            end_dates <- append(end_dates, as.character(e_date))
        }
        
        break
    }
    
    # format day
    d_e <- day(e_date)
    d_e <- if_else(str_length(d_e) == 1, paste0("0", d_e), as.character(d_e))
    
    # format month
    m_e <- month(e_date)
    m_e <- if_else(str_length(m_e) == 1, paste0("0", m_e), as.character(m_e))
    
    # new search end date
    e_date_str <- paste0(m_e, "-", d_e, "-", year(e_date))
    
    if(web_browser == "chrome") {
        end_dates <- append(end_dates, e_date_str)
    } else if(web_browser == "firefox") {
        end_dates <- append(end_dates, as.character(e_date))
    }
}

##################################################################
##                Collect all PDF download links                ##
##################################################################
scrape_download_links <- function(start_date, end_date, browser) {
    
    cat(paste0("START DATE: ", start_date, "\n"))
    cat(paste0("END DATE: ", end_date, "\n"))
    
    # Enter start dates and end dates
    sdate_box <- browser$findElement(using = "name", value = "FiledStartDate")
    sdate_box$sendKeysToElement(list(start_date))
    cat("ENTERED START DATE\n")
    
    enddate_box <- browser$findElement(using = "name", value = "FiledEndDate")
    enddate_box$sendKeysToElement(list(end_date))
    cat("ENTERED END DATE\n")
    
    # Search for court cases
    browser$findElements("id", "btnSearch")[[1]]$clickElement()
    cat("CLICKED SEARCH BUTTON\n")
    
    # Checking for unauthorized request HTTP 429 error.
    repeat{
        # Odd error where page source is empty. Code executes before page loads?
        unauthorized_request <-
            try(
                unauthorized_request <-
                    browser$getPageSource()[[1]] %>%
                    read_html() %>%
                    html_nodes("pre") %>%
                    html_text(),
                silent = T
            )
        
        # If we detect an unauthorized request or encounter page source error...
        if(length(unauthorized_request) != 0) {
            # Detected unauthorized request error. Break out of loop.
            if(!str_detect(unauthorized_request, "subscript out of bounds")) {
                cat("CHECKING FOR UNAUTHORIZED REQUEST HTTP 429 ERROR...\n")
                break
                # Detected page source error. Try again.
            } else {
                cat("BROWSER PAGE SOURCE ERROR. WAITING FOR PAGE TO LOAD.\n")
                next
            }
            # No errors detected.
        } else {
            cat("CHECKING FOR UNAUTHORIZED REQUEST HTTP 429 ERROR...\n")
            break
        }
    }
    
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
    cat("NO UNAUTHORIZED REQUEST ERROR\n")
    
    # Waiting for the table of court cases to load.
    repeat{
        # Again getPageSource is sometimes empty. Odd it would error here after
        # checking for this error when checking for unauthorized requests.
        court_cases <-
            try(
                browser$getPageSource()[[1]] %>%
                    read_html() %>%
                    html_elements("#caseSearchResultGrid") %>%
                    html_table(),
                silent = T
            )
        
        # Test that we find the table.
        if(class(court_cases) == "list") {
            # Test that the table is not empty.
            if(length(court_cases) == 1) {
                # Test that the table is a data frame.
                if(!is.null(nrow(court_cases[[1]]))) {
                    # Test that the data frame is not empty.
                    if(nrow(court_cases[[1]]) != 0) {
                        cat("RETRIEVED TABLE OF COURT CASES\n")
                        break
                    }
                }
            } else {
                # An empty table does not cause an error.
                # Keep trying until the page fully loads.
                cat("TABLE IS EMPTY. PAGE HAS NOT FULLY LOADED. TRY AGAIN.\n")
                next
            }
        } else {
            # Table was not found likely due to the page not fully loading.
            cat("BROwSER PAGE SOURCE ERROR. WAITING FOR PAGE TO LOAD.\n")
        }
    }
    
    # Check if there are any cases for the given date range.
    court_cases_df <- court_cases[[1]]
    no_results <- court_cases_df[[1, 1]]
    
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
            
            court_cases <-
                browser$getPageSource()[[1]] %>%
                read_html() %>%
                html_elements("#caseSearchResultGrid") %>%
                html_table()
            court_cases_df <- court_cases[[1]]
            cat("TABLE HAS NOT FULLY LOADED. TRYING AGAIN.\n")
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
        cat("NO COURT CASES IN THIS TIME RANGE\n")
    }
    cat("SCRAPED TABLE OF COURT CASES\n")
    
    # Reset the search field
    browser$findElements("id", "btnReset")[[1]]$clickElement()
    cat("RESET THE SEARCH FIELD\n\n")
    
    return(court_cases_df)
}

start_time <- Sys.time()
download_links_list <-
    pmap(
        list(begin_dates, end_dates),
        scrape_download_links,
        browser = rd_client
    )
end_time <- Sys.time()

diff_time <- end_time - start_time
cat(
    paste0(
        "IT TOOK: ", diff_time, " ", units(diff_time), " TO COLLECT ",
        length(begin_dates), " TABLES.", "\n"
    )
)

download_links_df <-
    download_links_list %>%
    map(
        function(df) {df %>% mutate(`Incident #` = as.character(`Incident #`))}
    ) %>%
    list_rbind()

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()

##################################################################
##                         Save results                         ##
##################################################################
scraped_table_dir <- here("output", "scraped_tables")
if(!dir.exists(scraped_table_dir)) {dir.create(scraped_table_dir, recursive = T)}

write_csv(
    download_links_df, here(scraped_table_dir, "all_counties_1889_1949.csv")
)
