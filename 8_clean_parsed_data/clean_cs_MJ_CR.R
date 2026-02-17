library(here)
library(purrr)
library(dplyr)
library(tidyr)
library(readxl)
library(rrapply)
library(stringr)
library(jsonlite)
library(lubridate)

read_dir <-
    here(
        "output", "pdf_parse_list", "json",
        "json_cs_MJ_CR_Allegheny_Blair_Centre_Dauphin_Erie_Montgomery"
    )

################################################################################
# Read in JSON files + code book.
################################################################################
codebook <-
    read_xlsx(here("output", "pdf_parse_list", "ogs_and_prs_codebook.xlsx")) |>
    mutate(
        id =
            paste0(
                str_replace_all(Code, "(Pa\\.C\\.S\\.\\s+§\\s*|P\\.S\\.\\s*§*\\s*)", "_"),
                "_",
                str_replace_all(Statute, "\\(|\\)", "")
            ),
        id = str_replace_all(id, "\\s+", ""),
        id = str_replace_all(id, "_+", "_")
    )

list_of_files <- list.files(read_dir)
list_of_json <-
    map(
        list_of_files,
        function(file, path) {read_json(file.path(path, file))},
        path = read_dir
    )
names <- str_replace(list_of_files, ".json", "")
list_of_json <- list_of_json |> set_names(names)

################################################################################
# Flatten JSON files into a data frame.
################################################################################
flattened_json <-
    rrapply(
        list_of_json,
        condition = function(x, .xname) {
            .xname %in%
                c(
                    "dob", "eyes", "sex", "hair", "race", "docket_number",
                    "arrest_date", "disp_event_date", "last_action_date",
                    "statute", "grade", "descriptions", "disposition", "counts"
                )
        },
        how = "melt"
    )


































################################################################################
# Extract demographic information from JSON files.
################################################################################
access_element <- function(json, element) {
    if(!is.null(json[[element]])) {
        json[[element]]
    } else {
        ""
    }
}

demographic_info_df <-
    tibble(
        id = names(list_of_json),
        dob = unname(unlist(map(list_of_json, access_element, element = "dob"))),
        sex = unname(unlist(map(list_of_json, access_element, element = "sex"))),
        eyes = unname(unlist(map(list_of_json, access_element, element = "eyes"))),
        hair = unname(unlist(map(list_of_json, access_element, element = "hair"))),
        race = unname(unlist(map(list_of_json, access_element, element = "race")))
    ) |>
    mutate(
        race_collapsed = case_when(
            race == "" ~ "Unknown/Unreported",
            race == "Asian" ~ "Other",
            race == "Asian/Pacific Islander" ~ "Other",
            race == "Bi-Racial" ~ "Other",
            race == "Native American/Alaskan Native" ~ "Other",
            race == "Native Hawaiian/Pacific Islander" ~ "Other",
            T ~ race
        ),
        hair_collapsed = case_when(
            hair == "" ~ "Unknown or Completely Bald",
            hair %in% c("Blue", "Green", "Orange", "Pink", "Purple") ~ "Dyed Hair",
            hair == "Gray or Partially Gray" | hair == "White" ~ "Gray/White Hair",
            hair == "Sandy" ~ "Blond or Strawberry",
            T ~ hair
        ),
        eyes_collapsed = case_when(
            eyes %in% c("Gray", "Maroon", "Multicolored", "Pink") ~ "Other",
            eyes == "" ~ "Unknown",
            T ~ eyes
        ),
        sex = if_else(sex == "", "Unreported/Unknown", sex),
        dob = mdy(dob)
    )

################################################################################
# Extract case information.
################################################################################
nr_cases <-
    map(
        list_of_json,
        function(list) {sum(stri_detect_fixed(names(list), "case_"))}
    ) |>
    unlist() |>
    unname()

max_nr_cases <- max(nr_cases) - 1

extract_case_attr <- function(list, case_nr, case_attr) {
    if(is.null(list[[case_nr]][[case_attr]]))
        return("")
    else
        return(is.null(list[[case_nr]][[case_attr]]))
}

vector_case_nrs <- paste0("case_", 0:max_nr_cases)

start_time <- Sys.time()
cases_df <-
    tibble(
        docket_nr =
            map(
                list_of_json[1:1000],
                function(json) {
                    map(
                        vector_case_nrs,
                        extract_case_attr,
                        list = json,
                        case_attr = "docket_number"
                    )
                }
            )
    )
end_time <- Sys.time()
total_time <- end_time - start_time
total_run_time <- 412313 * total_time / 1000





extract_charges <- function(case) {
    charges <- names(case)[str_detect(names(case), "charge_nr_")]
    charge_df <- case[charges] |> bind_rows()
    
    case_df <-
        tibble(
            docket_nr = case$docket_number,
            arrest_date = case$arrest_date,
            disp_date = case$disp_event_date,
            last_action_date = case$last_action_date
        )
    
    if(nrow(charge_df) != 0) {
        case_df <-
            case_df |>
            mutate(charges = list(charge_df))
    }
    
    return(case_df)
}

extract_cases <- function(json, id) {
    cases <- names(json)[str_detect(names(json), "case_")]
    cases_df <- map(json[cases], extract_charges) |> bind_rows()
    
    if(nrow(cases_df) != 0) {
        cases_df <- cases_df |> mutate(id = id)
    } else {
        cases_df <- tibble(id = id)
    }
    
    return(cases_df)
}



























extract_cases <- function(json, id) {
    cases <- names(json)[str_detect(names(json), "case_")]
    cases_df <- map(json[cases], extract_charges) |> bind_rows()
    
    if(nrow(cases_df) != 0) {
        cases_df <- cases_df |> mutate(id = id)
    } else {
        cases_df <- tibble(id = id)
    }
    
    return(cases_df)
}












extract_charges <- function(case) {
    charges <- names(case)[str_detect(names(case), "charge_nr_")]
    charge_df <-
        map(
            case[charges],
            function(charge) {
                tibble(
                    statute = charge$statute,
                    grade = charge$grade,
                    description = charge$description,
                    diposition = charge$disposition,
                    counts = charge$counts
                )
            }
        ) |>
        bind_rows()
    
    case_df <-
        tibble(
            docket_nr = case$docket_number,
            arrest_date = case$arrest_date,
            disp_date = case$disp_event_date,
            last_action_date = case$last_action_date
        )
    
    if(nrow(charge_df) != 0) {
        case_df <-
            case_df |>
            mutate(charges = list(charge_df))
    }
    
    return(case_df)
}



prior_record_df_new <-
    prior_record_df |>
    mutate(
        charges =
            map(
                charges,
                function(df) {
                    if(!is.null(df)) {
                        df |>
                            mutate(
                                statute = stri_replace_all_regex(statute, "§+", "_"),
                                statute = stri_replace_all_charclass(statute, "\\p{WHITE_SPACE}", "")
                            )
                    } else {
                        tibble()
                    }
                }
            )
    )









start_time <- Sys.time()

# prior_record_df <-
#     pmap(list(list_of_json[1:1000], names(list_of_json[1:1000])), extract_cases) |>
#     bind_rows()
end_time <- Sys.time()
total_time <- end_time - start_time
total_run_time <- 412313 * total_time / 1000
