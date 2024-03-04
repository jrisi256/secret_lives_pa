library(here)
library(dplyr)
library(rvest)
library(tidyr)
library(purrr)
library(stringr)
library(RSelenium)
library(lubridate)

#' Create a list of start dates and end dates to search for cases.
#' 
#' @param s_date_str_init Character in MM-DD-YYYY format representing the start date.
#' @param browser Character that is either chrome of firefox to indicate browser of use.
#' @param day_increment Numeric that represents the length of time you want to search by.
#' @param cutoff_date Character in YYYY-MM-DD format representing when the date at which point you should stop searching.
#' @ returns A named two element list.
#' @examples 
#' create_date_range("01-01-1950", "firefox", 180, "2024-01-01")
create_date_range <- function(s_date_str_init, browser, day_increment, cutoff_date) {
    # Initialize starting values for start dates and end dates
    s_date <- mdy(s_date_str_init)
    s_date_str <- s_date_str_init
    e_date <- s_date + days(day_increment)
    
    # format day
    d_e <- day(e_date)
    d_e <- if_else(str_length(d_e) == 1, paste0("0", d_e), as.character(d_e))
    
    # format month
    m_e <- month(e_date)
    m_e <- if_else(str_length(m_e) == 1, paste0("0", m_e), as.character(m_e))
    
    # search end date
    e_date_str <- paste0(m_e, "-", d_e, "-", year(e_date))
    
    begin_dates <- list()
    end_dates <- list()
    cutoff_flag <- F
    
    # Depending on browser, dates need to be formatted differently.
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
        
        # If the new start date is past the cutoff, stop constructing dates.
        if(s_date >= ymd(cutoff_date)) {
            return(list(begin_dates = begin_dates, end_dates = end_dates))
        }
        
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
        e_date <- s_date + days(day_increment)
        
        # If end date is past cutoff, make end date one day before cutoff.
        if(e_date >= ymd(cutoff_date)) {
            e_date <- ymd(cutoff_date) - days(1)
            cutoff_flag <- T
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
        
        # Since our end date was past the cutoff date, we are done.
        if(cutoff_flag) {
            return(list(begin_dates = begin_dates, end_dates = end_dates))
        }
    }
}

##################################################################
##                      Create date ranges                      ##
##################################################################
web_browser <- "firefox"
date_range_180_days <- create_date_range("01-01-1950", web_browser, 180, "2024-01-01")

#################################################################
##            Create county and date search strings            ##
#################################################################
counties <-
  sort(
    c(
      "Adams",
      "Allegheny",
      "Armstrong",
      "Beaver",
      "Bedford",
      "Berks",
      "Blair",
      "Bradford",
      "Bucks",
      "Butler",
      "Cambria",
      "Cameron",
      "Carbon",
      "Centre",
      "Chester",
      "Clarion",
      "Clearfield",
      "Clinton",
      "Columbia",
      "Crawford",
      "Cumberland",
      "Dauphin",
      "Delaware",
      "Elk",
      "Erie",
      "Fayette",
      "Forest",
      "Franklin",
      "Fulton",
      "Greene",
      "Huntingdon",
      "Indiana",
      "Jefferson",
      "Juniata",
      "Lackawanna",
      "Lancaster",
      "Lawrence",
      "Lebanon",
      "Lehigh",
      "Luzerne",
      "Lycoming",
      "McKean",
      "Mercer",
      "Mifflin",
      "Monroe",
      "Montgomery",
      "Montour",
      "Northampton",
      "Northumberla",
      "Perry",
      "Philadelphia",
      "Pike",
      "Potter",
      "Schuylkill",
      "Snyder",
      "Somerset",
      "Sullivan",
      "Susquehanna",
      "Tioga",
      "Union",
      "Venango",
      "Warren",
      "Washington",
      "Wayne",
      "Westmoreland",
      "Wyoming",
      "York"
    )
  )

county_ids <- 2:(length(counties) + 1)

county_and_dates <-
    expand_grid(
        date =
            paste0(
                unlist(date_range_180_days$begin_dates),
                "_",
                unlist(date_range_180_days$end_dates)
            ),
        county = paste0(counties, "_", county_ids)
    ) %>%
    separate_wider_delim(date, delim = "_", names = c("begin_date", "end_date")) %>%
    separate_wider_delim(county, delim = "_", names = c("county", "county_id"))

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

#################################################################
##     Check if there are too many cases in the date range     ##
#################################################################
check_too_many_cases <- function(start_date, end_date, county, browser) {
    too_many_cases_flag <- F
    
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
                county,
                "]"
            )
        )$clickElement()
    print("SELECTED COUNTY")
    
    # Search for court cases
    searchBtn <- browser$findElements("id", "btnSearch")[[1]]
    searchBtn$clickElement()
    print("CLICKED SEARCH BUTTON")
    
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
        broweser$acceptAlert()
        print("ACCEPTED DIALOG BOX")
        
        # Look for the search button.
        searchBtn <- browser$findElements("id", "btnSearch")[[1]]
        
        # Need to wait for web page to load. Keep looking for search button.
        while(length(searchBtn == 0)) {
            searchBtn <- browser$findElements("id", "btnSearch")[[1]]
        }
        
        # Once the search button has loaded, click it.
        searchBtn$clickElement()
        print("CLICKED SEARCH BUTTON AFTER UNAUTHORIZED REQUEST")
    }
    
    # Waiting for page to load
    court_df <- list()
    while(length(court_df) == 0) {
        court_df <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements("#caseSearchResultGrid") %>%
            html_table()
    }
    print("EXTRACTED TABLE")
    
    #' TO DO
    #' A second, more mysterious issue. I believe the issue originates here.
    #' I will sometimes get a cryptic message that I am trying to access an
    #' element of browser$getPageSource() that does not exist i.e., it is an 
    #' empty list. Or somethign like that. It is a mysterious error because
    #' the page loads fine, and I cannot see any errors. When I run the code 
    #' manually in the console, it works fine. Not sure what's happening.
    #' 
    #' The idea is to create some while loop that wait until the page properly
    #' loads? Might fix the issue.
    #' 
    # while(length(browser$getPageSource()) == 0) {
    #     print("Waiting")
    # }
    
    # The date range is too broad and some cases will not appear.
    # A box will appear telling us if there are too many cases to display.
    too_many_cases <-
        try(
            browser$findElement(
                using="xpath",
                value="/html[1]/body[1]/div[3]/div[3]/div[1]/div[3]/table[1]/caption[1]"
            ),
            silent = T
        )
    
    # If it's a character, the error was captured (HTML element not found).
    # If it's a Web Element, the element was found. The date range is too broad.
    if(class(too_many_cases) == "webElement") {
        too_many_cases_flag <- T
        print("THERE ARE TOO MANY CASES")
    }
    
    # Reset the search field
    browser$findElements("id", "btnReset")[[1]]$clickElement()
    print("RESET THE SEARCH FIELD")
    
    return(
        tibble(
            start_date = start_date,
            end_date = end_date,
            county_id = county,
            too_many_cases = too_many_cases_flag
        )
    )
}

#' TO DO
#' Add changes to 1899_1949 scraper.
#' Make this scraper more robust. It should collect the tables as it goes along.
#' Somehow save the results so it can restart itself in the case of a crash?

###########################################################################
##  Check and see if the date range works for each county-date coupling  ##
###########################################################################
check_by_county <- function(df, target_county, browser) {
    # Keep only those dates associated with the target county.
    df <- df %>% filter(county == target_county) %>% arrange(begin_date)
    too_many_cases_col <- c()
    
    # For each pair of dates in the current county...
    for(i in 1:nrow(df)) {
        
        # Check and see if the ith date pair has too many cases
        too_many_cases_list <-
            pmap(
                list(
                    as.list(df$begin_date)[i],
                    as.list(df$end_date)[i],
                    as.list(df$county_id)[i]
                ),
                check_too_many_cases,
                browser = browser
            )
        
        too_many_cases_flag <- too_many_cases_list[[1]]$too_many_cases
        
        # If the ith date pair has too many cases...
        # Assume all future date pairs would also have too many cases. 
        # Stop searching for the current county.
        if(too_many_cases_flag == T) {
            too_many_cases_col <-
                c(
                    too_many_cases_col,
                    rep(T, nrow(df) - length(too_many_cases_col))
                )
            break
        # If the ith date pair does not have too many cases, continue on.
        } else if(too_many_cases_flag == F) {
            too_many_cases_col <- c(too_many_cases_col, too_many_cases_flag)
        }
    }
    
    # For each date pair, record if there were too many cases or not.
    df <- df %>% mutate(too_many_cases = too_many_cases_col)
    return(df)
}

# Check and see if the 6-month search range works for each county-date record.
test <-
    county_and_dates %>%
    filter(county %in% c("Adams", "Allegeheny", "Armstrong"), begin_date >= ymd("1990-02-21"))

six_month_check <-
    map(
        unique(test$county),
        check_by_county,
        df = test,
        browser = rd_client
    )

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()
