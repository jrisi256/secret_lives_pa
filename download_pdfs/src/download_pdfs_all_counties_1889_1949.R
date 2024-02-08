library(here)
library(dplyr)
library(purrr)
library(rvest)
library(stringr)
library(lubridate)
library(RSelenium)

#################################################################
##                      Start web browser.                     ##
#################################################################
web_browser <- "firefox"
remote_driver <- rsDriver(browser = web_browser, port = 4545L)
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
} else if(web_browser == "firefox") {
    begin_dates <- append(begin_dates, as.character(s_date))
}

if(web_browser == "chrome") {
    end_dates <- append(end_dates, e_date_str)
} else if(web_browser == "firefox") {
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
##                      Download all PDFS.                      ##
##################################################################
create_download_links <- function(start_date, end_date, browser) {
    # Enter start dates and end dates
    sdate_box <- browser$findElement(using = "name", value = "FiledStartDate")
    sdate_box$sendKeysToElement(list(start_date))
    
    enddate_box <- browser$findElement(using = "name", value = "FiledEndDate")
    enddate_box$sendKeysToElement(list(end_date))
    
    # Search for court cases
    browser$findElements("id", "btnSearch")[[1]]$clickElement()
    Sys.sleep(3)
    
    # Create folder to hold PDFs
    save_path <- here("download_pdfs", "output")
    folder_name <- paste0(start_date, "_", end_date, "_", "all-counties")
    
    if(!dir.exists(here(save_path, folder_name))) {
        dir.create(here(save_path, folder_name))
    }
    
    # Wait for page to load
    court_df <- list()
    while(length(court_df) == 0) {
        court_df <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_nodes("#caseSearchResultGrid") %>%
            html_table()
        Sys.sleep(0.001)
    }
    
    # Extract docket number to name the PDFs
    court_df <- court_df[[1]]
    court_df <- court_df[-c(1, 2, 19)]
    court_df <-
        court_df %>% mutate(start_date = start_date, end_date = end_date)
    docket_ns <- court_df %>% pull(`Docket Number`)
    
    # Download the PDFs conditional on there being PDFs to download.
    if(docket_ns[1] != "No results found") {
        # Extract links to download PDFs
        links <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_nodes('a') %>%
            html_attr('href')
        
        durl <- "https://ujsportal.pacourts.us"
        docket_sheet_links <- paste0(durl, str_subset(links, 'DocketSheet'))
        court_summary_links <- paste0(durl, str_subset(links, 'CourtSummary'))
        
        # Add links to our data table
        court_df <-
            court_df %>%
            mutate(
                docket_sheet_link = docket_sheet_links,
                court_summary_link = court_summary_links
            )
    }
    
    # Reset the search field
    browser$findElements("id", "btnReset")[[1]]$clickElement()
    
    return(court_df)
}

download_links_df <-
    pmap_dfr(
        list(begin_dates[1:5], end_dates[1:5]),
        create_download_links,
        browser = rd_client
    )

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()
