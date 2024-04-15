library(here)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(lubridate)

#' Create a list of start dates and end dates to search for cases.
#' 
#' @param s_date_str_init Character in YYYY-MM-DD format representing the start date.
#' @param browser Character that is either chrome of firefox to indicate browser of use.
#' @param day_increment Numeric that represents the length of time you want to search by.
#' @param cutoff_date Character in YYYY-MM-DD format representing the date at which point to stop searching.
#' @ returns A named two element list.
#' @examples 
#' create_date_range("1950-01-01", "firefox", 180, "2024-01-01")
create_date_range <- function(s_date_str_init, browser, day_increment, cutoff_date) {
    s_date <- ymd(s_date_str_init)
    begin_dates <- list()
    end_dates <- list()
    cutoff_flag <- F
    
    while(T) {
        # If the new start date is past the cutoff, stop constructing dates.
        if(s_date >= ymd(cutoff_date)) {
            return(list(begin_date = begin_dates, end_date = end_dates))
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
        
        # update our beginning date
        s_date <- mdy(e_date_str) + days(1)
    }
}

#################################################################
##  INITIALIZE STARTING VALUES. MAKE SURE TO CHANGE EACH RUN.  ##
#################################################################
web_browser <- "firefox"
path_to_log_file <- ""
increment <- 180
search_table_name <- "all_counties_6_months.csv"

#########################################################################
##  Match counties to their IDs. IDs come from the PA courts website.  ##
#########################################################################
counties_vec <-
    sort(
        c(
            "Adams", "Allegheny", "Armstrong", "Beaver", "Bedford", "Berks",
            "Blair", "Bradford", "Bucks", "Butler", "Cambria", "Cameron",
            "Carbon", "Centre", "Chester", "Clarion", "Clearfield", "Clinton",
            "Columbia", "Crawford", "Cumberland", "Dauphin", "Delaware", "Elk",
            "Erie", "Fayette", "Forest", "Franklin", "Fulton", "Greene",
            "Huntingdon", "Indiana", "Jefferson", "Juniata", "Lackawanna",
            "Lancaster", "Lawrence", "Lebanon", "Lehigh", "Luzerne", "Lycoming",
            "McKean", "Mercer", "Mifflin", "Monroe", "Montgomery", "Montour",
            "Northampton", "Northumberla", "Perry", "Philadelphia", "Pike",
            "Potter", "Schuylkill", "Snyder", "Somerset", "Sullivan",
            "Susquehanna", "Tioga", "Union", "Venango", "Warren", "Washington",
            "Wayne", "Westmoreland", "Wyoming", "York"
        )
    )
county_ids_vec <- 2:(length(counties_vec) + 1)
county_df <- tibble(county = counties_vec, county_id = county_ids_vec)

###########################################################################
##  If not using a log file, default to 6-month range for every county.  ##
###########################################################################
if(path_to_log_file == "") {
    # Create 6 month date range.
    date_range <-
        create_date_range("1950-01-01", web_browser, increment, "2024-01-01")
    
    # Create 6 month date ranges for each county.
    county_and_dates <-
        expand_grid(
            date =
                paste0(
                    unlist(date_range$begin_dates),
                    "_",
                    unlist(date_range$end_dates)
                ),
            county = paste0(counties_vec, "_", county_ids_vec)
        ) %>%
        separate_wider_delim(
            date, delim = "_", names = c("begin_date", "end_date")
        ) %>%
        separate_wider_delim(
            county, delim = "_", names = c("county", "county_id")
        )
} else {
    # Read in the log file and keep only those searches that had too many cases.
    log_file <-
        read_csv(path_to_log_file) %>%
        filter(too_many) %>%
        group_by(county) %>%
        summarise(begin_date = min(begin_date)) %>%
        mutate(end_date = "2024-01-01")
    
    # Create dates for each county starting when they had too many cases.
    new_dates <-
        pmap(
            list(
                s_date_str_init = as.list(log_file$begin_date),
                cutoff_date = as.list(log_file$end_date)
            ),
            create_date_range,
            browser = "firefox",
            day_increment = increment
        )
    
    county_and_dates <-
        pmap(
            list(new_dates, as.list(unique(log_file$county))),
            function(list_of_dates, county) {
                list_of_dates["county"] <- county
                return(list_of_dates)
            }
        ) %>%
        bind_rows() %>%
        left_join(county_df, by = "county")
}

#################################################################
##                 Write out search parameters                 ##
#################################################################
save_dir <- here("scrape_links", "output", "search_tables")
if(!dir.exists(save_dir)) {dir.create(save_dir, recursive = T)}
write_csv(county_and_dates, here(save_dir, search_table_name))
