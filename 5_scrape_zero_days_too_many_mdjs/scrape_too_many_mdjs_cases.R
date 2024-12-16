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
main_dir <- here()
search_table_dir <- file.path(main_dir, "output", "search_tables")
log_table_dir <- file.path(main_dir, "output", "log_tables")
scraped_table_dir <- file.path(main_dir, "output", "scraped_tables")
if(!dir.exists(scraped_table_dir)) {dir.create(scraped_table_dir, recursive = T)}
if(!dir.exists(log_table_dir)) {dir.create(log_table_dir, recursive = T)}

search_table_name <- "all_counties_0_days_too_many_mdjs.csv"
log_file <- "all_counties_0_days_too_many_mdjs_log.csv"
web_browser <- "firefox"
progress_file <- "scrape_progress_too_many_mdjs.txt"

##################################################################
##      Read in search table and compare against log file.      ##
##################################################################
search_table <-
    read_csv(file.path(search_table_dir, search_table_name)) %>%
    arrange(county, begin_date)

if(file.exists(file.path(log_table_dir, log_file))) {
    log_table <- read_csv(file.path(log_table_dir, log_file))
    search_table <- search_table %>% anti_join(log_table)
}

#################################################################
##                      Start web browser.                     ##
#################################################################
remote_driver <-
    rsDriver(
        browser = web_browser,
        port = 4546L,
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
##             Functions for navigating the website             ##
##################################################################
click_search_button <- function(browser) {
    # Search for court cases
    searchBtn <- browser$findElements("id", "btnSearch")[[1]]
    searchBtn$clickElement()
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
            # Detected unauthorized request error.
            if(!str_detect(unauthorized_request, "subscript out of bounds")) {
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
                # Detected page source error. Try again.
            } else {
                cat("SOURCE ERROR WHILE LOOKING FOR UNAUTHORIZED REQUESTS.\n")
            }
            # No errors detected.
        } else {
            cat("NO UNAUTHORIZED REQUEST ERROR\n")
            break
        }
    }
}

check_table_loaded_properly <- function(browser) {
    # Waiting for the table of court cases to load.
    table_empty_counter <- 0
    repeat{
        # Again, getPageSource() is sometimes empty. Odd it would error here
        # after checking for this error when checking for unauthorized requests.
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
                # Empty table doesn't cause an error. Try again.
                if(table_empty_counter <= 150) {
                    cat("TABLE IS EMPTY. HAS NOT FULLY LOADED. TRY AGAIN.\n")
                    table_empty_counter <- table_empty_counter + 1
                    # Sometimes the page is just blank, never loads. Not sure why.
                } else {
                    cat("EMPTY PAGE ERROR. TRYING TO RELOAD PAGE.\n")
                    table_empty_counter <- 0
                    
                    browser$refresh()
                    cat("REFRESHED BROWSER - EMPTY PAGE\n")
                    
                    browser$acceptAlert()
                    cat("ACCEPTED DIALOG BOX - EMPTY PAGE\n")
                }
            }
        } else {
            # Table was not found likely due to the page not fully loading.
            cat("BROwSER PAGE SOURCE ERROR. WAITING FOR PAGE TO LOAD.\n")
        }
    }
    
    return(court_cases)
}

extract_table <- function(browser, court_cases_df, start_date, end_date) {
    check_length <- -1
    docket_sheets <- c()
    court_summaries <- c()
    
    # Ensure the table and links have properly loaded.
    while(nrow(court_cases_df) != check_length) {
        docket_sheets <- c()
        court_summaries <- c()
        
        table <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements("#caseSearchResultGrid tbody tr")
        
        for(row in table) {
            links <-
                row %>%
                html_elements("a.icon-wrapper") %>%
                html_attr("href")
            
            docket_sheet <- links[1]
            court_summary <- links[2]
            docket_sheets <- c(docket_sheets, docket_sheet)
            court_summaries <- c(court_summaries, court_summary)
        }
        check_length <- length(docket_sheets)
        
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
    docket_sheet_links <- paste0(durl, docket_sheets)
    court_summary_links <- paste0(durl, court_summaries)
    
    court_cases_df <-
        court_cases_df[-c(1, 2, 19)] %>%
        mutate(
            start_date = start_date,
            end_date = end_date,
            docket_sheet_link = docket_sheet_links,
            court_summary_link = court_summary_links
        )
    
    return(court_cases_df)
}

############################################################################
##  Scrape the table of cases for a given date range for a given county.  ##
############################################################################
scrape_table <- function(start_date, end_date, county_name, county_id, browser, save_dir) {
    too_many_cases <- F
    cp_too_many_cases <- F
    mdjs_too_many_cases <- F
    too_many_cases_text <- ""
    too_many_cases_type <- "'"
    
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
    
    # Click the search button while doing proper error checking.
    click_search_button(browser)
    
    # Make sure table of court cases loaded properly.
    court_cases <- check_table_loaded_properly(browser)
    
    # A box will appear telling us if there are too many cases to display.
    too_many_cases_box <-
        browser$findElements(
            using="xpath",
            value="/html[1]/body[1]/div[3]/div[3]/div[1]/div[3]/table[1]/caption[1]"
        )
    
    # If the length is not 0, the box appeared. There are too many cases.
    if(length(too_many_cases_box) != 0) {
        too_many_cases <- T
        
        too_many_cases_text <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements(
                xpath = "/html/body/div[3]/div[3]/div[1]/div[3]/table/caption"
            ) %>%
            html_text()
        
        # Determine which court has too many cases: common pleas or magisterial.
        too_many_cases_type <-
            case_when(
                str_detect(too_many_cases_text, "Common Pleas") &
                    str_detect(too_many_cases_text, "Magisterial") ~ "cp_mc",
                str_detect(too_many_cases_text, "Magisterial") ~ "mc",
                str_detect(too_many_cases_text, "Common Pleas") ~ "cp"
            )
    } else {
        cat("THERE ARE NOT TOO MANY CASES. PROCEEDING TO SCRAPE TABLE.\n")
    }
    
    # If there are not too many cases or if there are too many court of common plea cases. 
    if(!too_many_cases | too_many_cases_type == "cp") {
        
        # Flag if there were too many court of common plea cases.
        if(too_many_cases_type == "cp") {
            cp_too_many_cases <- T
            cat("THERE ARE TOO MANY COURT OF COMMON PLEA CASES.\n")
        }
        
        # Check if there are any cases for the given date range.
        court_cases_df <- court_cases[[1]]
        no_results <- court_cases_df[[1, 1]]

        # Collect PDF download links if there are PDFs to download.
        if(no_results != "No results found") {
            # Extract the table for downloading.
            court_cases_df <- extract_table(browser, court_cases_df, start_date, end_date)
        # There were no court cases.
        } else {
            court_cases_df <-
                court_cases_df[-c(1, 2, 19)] %>%
                mutate(start_date = start_date, end_date = end_date)
            cat("NO COURT CASES IN THIS TIME RANGE FOR THIS COUNTY\n")
        }
        
        # Save the table of cases.
        write_csv(
            court_cases_df,
            file.path(
                save_dir,
                paste0(county_name, "_", start_date, "_", end_date, ".csv")
            )
        )
        cat("SCRAPED TABLE OF COURT CASES\n")
    }
    
    # If there are too many magisterial cases, go through each MDJS court office.
    if (str_detect(too_many_cases_type, "mc")) {
        cat("THERE ARE TOO MANY MAGISTERIAL COURT CASES.\n")
        
        # If there are also too many common plea cases, turn on the flag.
        if(str_detect(too_many_cases_type, "cp")) {
            cp_too_many_cases <- T
            cat("THERE ARE TOO MANY COURT OF COMMON PLEA CASES.\n")
        }
        
        # First, find all court of common plea offices.
        checkboxes <-
            rd_client$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements(
                xpath = "/html/body/div[3]/div[3]/div[1]/div[2]/div/div[2]/div[4]/div[2]"
            ) %>%
            html_elements(
                css = "label"
            )
        checkboxes_text <- checkboxes %>% html_text()
        cp_office_checkboxes <- str_detect(checkboxes_text, "CP-")
        cat("FOUND ALL COURT OF COMMON PLEA COURT OFFICES.\n")
        
        # un-select select all
        rd_client$findElement(
            using = "xpath",
            value = "/html/body/div[3]/div[3]/div[1]/div[2]/div/div[2]/div[4]/div[2]/label[1]"
        )$clickElement()
        cat("DE-SELECTED THE SELECT ALL CHECKBOX.\n")
        
        # Go through each common plea office check box.
        for(checkbox in 1:length(checkboxes)) {
            if(cp_office_checkboxes[checkbox]) {
                # Select the court office in the check box menu.
                rd_client$findElement(
                    using="xpath",
                    value = 
                        paste0(
                            "/html/body/div[3]/div[3]/div[1]/div[2]/div/div[2]/div[4]/div[2]/label[",
                            checkbox,
                            "]"
                        )
                )$clickElement()
                cat(paste0("SELECTED ", checkboxes_text[checkbox], ".\n"))
                
                # Extract the table for downloading.
                court_cases_df <- extract_table(browser, court_cases[[1]], start_date, end_date)
                
                # Save the table of cases.
                write_csv(
                    court_cases_df,
                    file.path(
                        save_dir,
                        paste0(
                            county_name, "_", start_date, "_", end_date, "_",
                            checkboxes_text[checkbox], ".csv"
                        )
                    )
                )
                cat("SCRAPED TABLE OF COURT CASES\n")
                
                # deselect the court office in the check-box menu.
                rd_client$findElement(
                    using="xpath",
                    value = 
                        paste0(
                            "/html/body/div[3]/div[3]/div[1]/div[2]/div/div[2]/div[4]/div[2]/label[",
                            checkbox,
                            "]"
                        )
                )$clickElement()
                cat("DE-SELECTED ", checkboxes_text[checkbox], ".\n\n")
            }
        }
        
        # Now that we have all CP court cases, Search by MDJS Court office.
        mdjs_court_offices <-
            browser$getPageSource()[[1]] %>%
            read_html() %>%
            html_elements(
                xpath = "/html/body/div[3]/div[2]/div/form/div[12]/div[2]/select"
            ) %>%
            html_elements(css = "option")
        
        # We skip the first office since it is always blank (all offices).
        for(court_office in 2:length(mdjs_court_offices)) {
            # Click on the drop-down menu for MDJS Court offices.
            browser$findElement(
                using = "xpath",
                value = "/html/body/div[3]/div[2]/div/form/div[12]/div[2]/select"
            )$clickElement()
            cat("SELECTED MDJS COURT OFFICE DROPDOWN\n")
            
            # Select the court office in the drop-down menu.
            browser$findElement(
                using="xpath",
                value = 
                    paste0(
                        "/html/body/div[3]/div[2]/div/form/div[12]/div[2]/select/option[",
                        court_office,
                        "]"
                    )
            )$clickElement()
            cat(paste0("SELECTED ", court_office, " MDJS COURT OFFICE OPTION.\n"))
            
            # Click the search button.
            click_search_button(browser)
            
            # Make sure table of court cases loaded properly.
            court_cases <- check_table_loaded_properly(browser)
            
            # A box will appear telling us if there are too many cases to display.
            mdjs_too_many_cases_box <-
                browser$findElements(
                    using="xpath",
                    value="/html[1]/body[1]/div[3]/div[3]/div[1]/div[3]/table[1]/caption[1]"
                )
            
            # If the length is not 0, the box appeared. There are too many cases.
            if(length(mdjs_too_many_cases_box) != 0) {
                mdjs_too_many_cases <- T
                cat("THERE ARE TOO MANY MDJS CASES\n")
            } else {
                cat("THERE ARE NOT TOO MANY MDJS CASES. PROCEEDING TO SCRAPE TABLE.\n")
            }
            
            # Collect the table regardless of if there are too many cases.
            # Check if there are any cases for the given date range.
            court_cases_df <- court_cases[[1]]
            no_results <- court_cases_df[[1, 1]]
            
            # Collect PDF download links if there are PDFs to download.
            if(no_results != "No results found") {
                # Extract the table for downloading.
                court_cases_df <- extract_table(browser, court_cases_df, start_date, end_date)
            # There were no court cases for this county + date + office.
            } else {
                court_cases_df <-
                    court_cases_df[-c(1, 2, 19)] %>%
                    mutate(start_date = start_date, end_date = end_date)
                cat("NO COURT CASES IN THIS TIME RANGE FOR THIS COUNTY + MDJS OFFICE\n")
            }
            
            # Save the table of cases.
            write_csv(
                court_cases_df,
                file.path(
                    save_dir,
                    paste0(
                        county_name, "_", start_date, "_", end_date, "_",
                        court_office, ".csv"
                    )
                )
            )
            cat("SCRAPED TABLE OF COURT CASES\n\n")
        }
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
            too_many_cases = too_many_cases,
            mdjs_too_many_cases = mdjs_too_many_cases,
            cp_too_many_cases = cp_too_many_cases
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

        # Save results to the log file.
        result <-
            df[i,] %>%
            mutate(
                too_many = too_many_cases_list[[1]]$too_many_cases,
                mdjs_too_many = too_many_cases_list[[1]]$mdjs_too_many_cases,
                cp_too_many = too_many_cases_list[[1]]$cp_too_many_cases
            )
        
        write_csv(
            result,
            log_dir,
            append = T, 
            col_names = !file.exists(log_dir),
            progress = F
        )
    }
    end_time <- Sys.time()
    time_scrape <- end_time - start_time
        
    cat(
        paste0("TIME IT TOOK TO SCRAPE: ", time_scrape, " ", units(time_scrape))
    )
}

#################################################################
##                       Begin scraping.                       ##
#################################################################
counties_list <- as.list(sort(unique(search_table$county)))

progress_files_list <-
    as.list(
        file.path(
          main_dir,
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
    log_dir = file.path(log_table_dir, log_file)
)

#################################################################
##                        Close driver.                        ##
#################################################################
remote_driver$server$stop()
