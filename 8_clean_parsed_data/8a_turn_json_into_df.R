library(here)
library(purrr)
library(stringr)
library(rrapply)
library(jsonlite)

out_dir <- here("output", "pdf_parse_list")

ds_mj_dir <-
    here(
        "output", "pdf_parse_list", "json",
        "json_ds_MJ_CR_Allegheny_Blair_Centre_Dauphin_Erie_Montgomery"
    )

cs_mj_dir <-
    here(
        "output", "pdf_parse_list", "json",
        "json_cs_MJ_CR_Allegheny_Blair_Centre_Dauphin_Erie_Montgomery"
    )

################################################################################
# Read in JSON files.
################################################################################
list_of_files_ds_mj <- list.files(ds_mj_dir)
list_of_files_cs_mj <- list.files(cs_mj_dir)

list_of_json_ds_mj <-
    map(
        list_of_files_ds_mj,
        function(file, path) {read_json(file.path(path, file))},
        path = ds_mj_dir
    )

list_of_json_cs_mj <-
    map(
        list_of_files_cs_mj,
        function(file, path) {read_json(file.path(path, file))},
        path = cs_mj_dir
    )

names_ds_mj <- str_replace(list_of_files_ds_mj, ".json", "")
names_cs_mj <- str_replace(list_of_files_cs_mj, ".json", "")

list_of_json_ds_mj <- list_of_json_ds_mj |> set_names(names_ds_mj)
list_of_json_cs_mj <- list_of_json_cs_mj |> set_names(names_cs_mj)

################################################################################
# Flatten JSON files into a data frame.
################################################################################
########################################## Main data frame for the docket sheet.
flattened_json_ds_mj <-
    rrapply(
        list_of_json_ds_mj,
        condition = function(x, .xname, .xparents) {
            (.xparents[2] == "case_info" && .xparents[3] == "case_status") |
                (.xparents[2] == "case_info" && .xparents[3] == "disposition_date") |
                (.xparents[2] == "case_participants" && .xparents[4] == "name") |
                (.xparents[2] == "charges" && .xparents[4] == "description") |
                (.xparents[2] == "attorney_info" && .xparents[4] == "name") |
                (.xparents[2] == "defendant_info" & .xparents[3] == "address_type") |
                (.xparents[2] == "defendant_info" & .xparents[3] == "address") |
                .xname %in%
                c(
                    "sex", "dob", "race", "counsel", "defender_requested",
                    "application_provided", "fingerprinted", "issue_date",
                    "file_date", "arrest_date", "judge_assigned", "county",
                    "township", "participant_type", "nr", "charge", "grade",
                    "offense_date", "disposition", "type", "representing",
                    "counsel_status", "supreme_court_nr", "bail_action", "date",
                    "bail_type", "originating_court", "percentage", "amount",
                    "confinement_location", "confinement_type",
                    "confinement_reason", "confinement_date",
                    "confinement_end_date"
                )
        },
        how = "melt"
    )

saveRDS(flattened_json_ds_mj, file.path(out_dir, "flattened_json_ds_mj.rds"))

####################################### Calendar events + docket status updates.
flattened_json_ds_mj_calendar_docket <-
    rrapply(
        list_of_json_ds_mj,
        condition = function(x, .xname) {
            .xname %in%
                c(
                    "event_type", "start_date", "judge", "filed_date", "entry",
                    "filer"
                )
        },
        how = "melt"
    )

saveRDS(
    flattened_json_ds_mj_calendar_docket,
    file.path(out_dir, "flattened_json_ds_mj_calendar_docket.rds")
)

########################################### Main data frame for court summaries.
flattened_json_cs_mj <-
    rrapply(
        list_of_json_cs_mj,
        condition = function(x, .xname) {
            .xname %in%
                c(
                    "dob", "eyes", "sex", "hair", "race", "docket_number",
                    "arrest_date", "disp_event_date", "last_action_date",
                    "statute", "grade", "description", "disposition", "counts"
                )
        },
        how = "melt"
    )

saveRDS(flattened_json_cs_mj, file.path(out_dir, "flattened_json_cs_mj.rds"))
