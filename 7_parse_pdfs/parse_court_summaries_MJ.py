import sys
import os
import json
import pdfplumber
import pandas as pd
import re
import logging
import csv
from datetime import datetime

arguments = sys.argv

# Initialize paths.
path_to_progress_file = "/home/joe/Documents/secret_lives_pa/output/pdf_sample/progress_files/"
path_to_pdfs = "/home/joe/Documents/secret_lives_pa/output/pdf_sample/pdfs/"
path_to_json = "/home/joe/Documents/secret_lives_pa/output/pdf_sample/json/"
path_to_logs = "/home/joe/Documents/secret_lives_pa/output/pdf_sample/log_files/"

# Initialize file names.
pdfs_to_parse = arguments[1] + arguments[2]
progress_file = path_to_progress_file + "progress-" + arguments[2]
log_file = path_to_logs + "log_file_" + datetime.now().strftime("%Y_%m_%d_%H_%M_%S") + ".txt"

# Configure the logger.
logging.basicConfig(filename = log_file, level = logging.INFO, filemode = "w+")

# List of all counties in PA.
counties = [
            "adams", "allegheny", "armstrong", "beaver", "bedford", "berks",
            "blair", "bradford", "bucks", "butler", "cambria", "cameron",
            "carbon", "centre", "chester", "clarion", "clearfield", "clinton",
            "columbia", "crawford", "cumberland", "dauphin", "delaware", "elk",
            "erie", "fayette", "forest", "franklin", "fulton", "greene",
            "huntingdon", "indiana", "jefferson", "juniata", "lackawanna",
            "lancaster", "lawrence", "lebanon", "lehigh", "luzerne", "lycoming",
            "mckean", "mercer", "mifflin", "monroe", "montgomery", "montour",
            "northampton", "northumberla", "perry", "philadelphia", "pike",
            "potter", "schuylkill", "snyder", "somerset", "sullivan",
            "susquehanna", "tioga", "union", "venango", "warren", "washington",
            "wayne", "westmoreland", "wyoming", "york"
            ]

# Declare functions.
def extract_poi(lines_arg):
    poi_dict = {}

    # Beginning part of every court summary in court of common pleas has a block of text with person information.
    # Organizations do not have date of birth so we need another way to identify the beginning of the POI information.
    try:
        poi_start_index = [i for i, x in enumerate(lines) if "DOB:" in x][0]
    except Exception as e:
        # Search through the lines until we come to the first line which does not contain the key phrases and is not an empty line.
        for i, line in enumerate(lines):
            if(re.search("magisterial\s+district\s+court", line.lower()) is None and re.search("public\s+court\s+summary", line.lower()) is None and line.strip() != ""):
                poi_start_index = i
                break

    poi_end_index = [i for i,x in enumerate(lines) if "court:" in x.lower()][0]
    poi = lines[poi_start_index:poi_end_index]

    # Name, DOB, and Sex appear on the first line. Very rarely they do not (such as when it's an organization who is the defendant).
    if("DOB:" in poi[0] and "Sex:" in poi[0]):
        poi_dict["name"] = poi[0].split("DOB:")[0].strip()
        poi_dict["dob"] = poi[0].split("DOB:")[1].split("Sex:")[0].strip()
        poi_dict["sex"] = poi[0].split("DOB:")[1].split("Sex:")[1].strip()
    # If DOB and sex do not appear, the name should still appear.
    else:
        poi_dict["name"] = poi[0].strip()

    # Location and Eye Color appear on the second line unless it's an organization (like above).
    if("Eyes:" in poi[1]):
        poi_dict["home_location"] = poi[1].split("Eyes:")[0].strip().lower()
        poi_dict["eyes"] = poi[1].split("Eyes:")[1].strip()
    # If eye color does not appear, the home location still should.
    else:
        poi_dict["home_location"] = poi[1].strip()

    # For organizations, the personal information will only be 3 lines.
    if(len(poi) > 3):
        # Hair color is on the third line.
        poi_dict["hair"] = poi[2].split("Hair:")[1].strip()

        # Race is on the fourth line.
        poi_dict["race"] = poi[3].split("Race:")[1].strip()

        # On the fifth line, if the person has an alias, their aliases will be listed here.
        # If they do not have any aliases, the PDF immediately starts the criminal history.
        poi_dict["alias"] = ""
        if(len(poi) > 4):
            poi_dict["alias"] = poi[4].split("Aliases:")[1].strip()

    return poi_dict, poi_end_index
def extract_punishment(p_idx, p_lines):
    # Initialize starting values
    loop_through_punishment = True
    punishment_nr = -1
    punishment_nr_idx = "punishment_nr_" + str(punishment_nr)
    punishment_dict = {}

    while(loop_through_punishment):
        # If the current line is the last line, exit out of the function.
        if(p_idx < len(p_lines)):
            cur_p_line = p_lines[p_idx].lower()
        else:
            break

        # If the current line has processing status, court, county, statewide, otn:, otn/lotn:, or a case status, then it is a new case.
        # This means we've reached the end of punishments.
        if("processing status:" in cur_p_line or "court:" in cur_p_line or "county:" in cur_p_line or "statewide" in cur_p_line or "otn:" in cur_p_line or "otn/lotn:" in cur_p_line or cur_p_line in counties or cur_p_line in ["active", "inactive", "closed", "adjudicated"]):
            break
        # If the line is only whitespace, or if it has reached the bottom-of-the-page text, ignore it.
        elif(cur_p_line.strip() == "" or "printed:" in cur_p_line or re.search("recent\s+entries\s+made\s+in\s+the", cur_p_line) or re.search("system\s+of\s+the\s+commonwealth\s+of", cur_p_line) or re.search("should\s+not\s+be\s+used\s+in\s+place", cur_p_line) or re.search("employers\s+who\s+do\s+not\s+comply", cur_p_line) or re.search("may\s+be\s+subject\s+to\s+civil", cur_p_line) or re.search("please\s+note\s+that\s+if\s+the", cur_p_line) or re.search("court\s+case\s+management\s+system\s+for\s+this\s+offense", cur_p_line) or re.search("is\s+charged\s+in\s+order\s+to", cur_p_line) or re.search("public\s+court\s+summary", cur_p_line) or "dob:" in cur_p_line or "eyes:" in cur_p_line or " hair:" in cur_p_line or "race:" in cur_p_line):
            p_idx += 1
            continue
        # If we have not hit a new case, then the line is a punishment.
        else:
            program_type = cur_p_line[:55].strip()
            sentence_date = cur_p_line[55:88].strip()
            sentence_length = cur_p_line[88:137].strip()
            program_period = cur_p_line[137:].strip()

            # This indicates the punishment line is an overflow line that is still describing the previous punishment's sentence length.
            if(program_type == "" and sentence_date == "" and program_period == "" and punishment_nr_idx != -1):
                punishment_dict[punishment_nr_idx]["sentence_length"] = punishment_dict[punishment_nr_idx]["sentence_length"] + " " + sentence_length
            # This indicates the punishment line is an overflow line that is still describing the previous punishment's program type.
            elif(sentence_length == "" and sentence_date == "" and program_period == "" and punishment_nr_idx != -1):
                punishment_dict[punishment_nr_idx]["program_type"] = punishment_dict[punishment_nr_idx]["program_type"] + " " + program_type
            else:
                punishment_nr += 1
                punishment_nr_idx = "punishment_nr_" + str(punishment_nr)
                punishment_dict[punishment_nr_idx] = {}

                punishment_dict[punishment_nr_idx]["program_type"] = program_type
                punishment_dict[punishment_nr_idx]["sentence_date"] = sentence_date
                punishment_dict[punishment_nr_idx]["sentence_length"] = sentence_length
                punishment_dict[punishment_nr_idx]["program_period"] = program_period

        # Move on to the next line.
        p_idx += 1

    return punishment_dict, p_idx
def extract_cases(c_idx, c_lines):
    # Set initial values.
    case_nr = -1
    case_nr_idx = "case_nr_" + str(case_nr)
    charge_nr = -1
    charge_nr_idx = "charge_nr_" + str(charge_nr)
    punishment_nr = -1
    punishment_nr_idx = "punishment_nr_" + str(punishment_nr)

    loop_through_cases = True
    statewide_flag = False
    current_court_county = ""
    current_case_status = ""

    line_increment_c = c_idx
    case_dict = {}

    while(loop_through_cases):
        # If the current line is the last line, exit out of the function.
        if(c_idx < len(c_lines)):
            cur_c_line = c_lines[c_idx].lower().strip()
        else:
            break
        
        # Set the court/county for this set of cases.
        if("court:" in cur_c_line or "county:" in cur_c_line or cur_c_line in counties):
            # Clean up the line.
            if("court:" in cur_c_line):
                new_court_county = cur_c_line.split("court:")[1].strip()
            elif("county:" in cur_c_line):
                new_court_county = cur_c_line.split("county:")[1].strip()
            elif(cur_c_line in counties):
                new_court_county = cur_c_line

            # Check if the new county/court is different from our current county/court. If it is, update the current court/county.
            if(new_court_county != current_court_county):
                current_court_county = new_court_county

        # Set the case status for this set of cases and check that it is different from the previous case status.
        if(("closed" == cur_c_line or "inactive" == cur_c_line or "active" == cur_c_line or "adjudicated" == cur_c_line) and cur_c_line != current_case_status):
            current_case_status = cur_c_line

        # I believe statewide cases are always at the end of the PDF so once this is turned on, it stays on.
        # I.e., all subsequent cases will always be statewide.
        if("statewide" == cur_c_line):
            statewide_flag = True

        # When we encounter processing status/otn, we are on a new case.
        # 1st line is Docket number, processing status, and OTN.
        # 2nd line is arrest date, processing location, and disposition event date.
        # 3rd line is last action and last action date.
        # 4th line is next action and next action date.
        # 5th line (optional) is bail type, bail amount, and bail status.
        # After that, each subsequent line is a prior charge.
        if("processing status:" in cur_c_line or "otn:" in cur_c_line or "otn/lotn:" in cur_c_line):
            line_increment_c += 1

            case_nr += 1
            case_nr_idx = "case_" + str(case_nr)
            case_dict[case_nr_idx] = {}

            charge_nr = -1
            charge_nr_idx = "charge_nr_" + str(charge_nr)

            case_dict[case_nr_idx]["court_or_county"] = current_court_county
            case_dict[case_nr_idx]["case_status"] = current_case_status
            case_dict[case_nr_idx]["statewide"] = statewide_flag
            
            # Sometimes a case may not have a processing status.
            if("processing status:" not in cur_c_line):
                if("otn/lotn:" in cur_c_line):
                    case_dict[case_nr_idx]["docket_number"] = cur_c_line.split("otn/lotn:")[0].strip().lower()
                    case_dict[case_nr_idx]["otn_lotn"] = cur_c_line.split("otn/lotn:")[1].strip().lower()
                elif("otn:" in cur_c_line):
                    case_dict[case_nr_idx]["docket_number"] = cur_c_line.split("otn:")[0].strip().lower()
                    case_dict[case_nr_idx]["otn"] = cur_c_line.split("otn:")[1].strip().lower()
            else:
                if("otn/lotn:" in cur_c_line):
                    case_dict[case_nr_idx]["docket_number"] = cur_c_line.split("processing status:")[0].strip()
                    case_dict[case_nr_idx]["proc_status"] = cur_c_line.split("processing status:")[1].split("otn/lotn:")[0].strip().lower()
                    case_dict[case_nr_idx]["otn_lotn"] = cur_c_line.split("processing status:")[1].split("otn/lotn:")[1].strip().lower()
                elif("otn:" in cur_c_line):
                    case_dict[case_nr_idx]["docket_number"] = cur_c_line.split("processing status:")[0].strip()
                    case_dict[case_nr_idx]["proc_status"] = cur_c_line.split("processing status:")[1].split("otn:")[0].strip().lower()
                    case_dict[case_nr_idx]["otn"] = cur_c_line.split("processing status:")[1].split("otn:")[1].strip().lower()
        elif("arrest date:" in cur_c_line):
            line_increment_c += 1
            case_dict[case_nr_idx]["arrest_date"] = cur_c_line[:42].split("arrest date:")[1].strip().lower()
            case_dict[case_nr_idx]["case_location"] = cur_c_line[42:88].strip().lower()
            case_dict[case_nr_idx]["disp_event_date"] = cur_c_line[88:].split("disp. event date:")[1].strip().lower()
        elif("last action:" in cur_c_line):
            line_increment_c += 1
            case_dict[case_nr_idx]["last_action"] = cur_c_line.split("last action:")[1].split("last action date:")[0].strip().lower()
            case_dict[case_nr_idx]["last_action_date"] = cur_c_line.split("last action:")[1].split("last action date:")[1].strip().lower()
        elif("next action:" in cur_c_line):
            line_increment_c += 1
            case_dict[case_nr_idx]["next_action"] = cur_c_line.split("next action:")[1].split("next action date:")[0].strip().lower()
            case_dict[case_nr_idx]["next_action_date"] = cur_c_line.split("next action:")[1].split("next action date:")[1].strip().lower()
        elif("bail type:" in cur_c_line):
            line_increment_c += 1
            case_dict[case_nr_idx]["bail_type"] = cur_c_line.split("bail type:")[1].split("bail amount:")[0].strip().lower()
            case_dict[case_nr_idx]["bail_amount"] = cur_c_line.split("bail type:")[1].split("bail amount:")[1].split("bail status:")[0].strip().lower()
            case_dict[case_nr_idx]["bail_status"] = cur_c_line.split("bail type:")[1].split("bail amount:")[1].split("bail status:")[1].strip().lower()
        elif("§" in cur_c_line):
            line_increment_c += 1
            charge_nr += 1
            charge_nr_idx = "charge_nr_" + str(charge_nr)
            case_dict[case_nr_idx][charge_nr_idx] = {}

            case_dict[case_nr_idx][charge_nr_idx]["statute"] = cur_c_line[:31].strip()
            case_dict[case_nr_idx][charge_nr_idx]["grade"] = cur_c_line[31:42].strip()
            case_dict[case_nr_idx][charge_nr_idx]["description"] = cur_c_line[42:88].strip()
            case_dict[case_nr_idx][charge_nr_idx]["disposition"] = cur_c_line[88:130].strip()
            case_dict[case_nr_idx][charge_nr_idx]["counts"] = cur_c_line[130:].strip()
        elif(re.search("program\s+type", cur_c_line)):
            # Start at the next line because that is whre the punishment starts.
            punishment_tuple = extract_punishment(c_idx + 1, c_lines)
            punishment_dict, line_increment_c = punishment_tuple
            case_dict[case_nr_idx].update(punishment_dict)
        # If the line does not contain any of the above characters, it's a junk line, and we can skip it.
        else:
            line_increment_c += 1

        c_idx = line_increment_c
    
    return case_dict, c_idx

# Check if the PDF progress file exists.
if(os.path.exists(progress_file)):
    # If it does exist, use the progress file (keeping only PDFs that have never been parsed successfully).
    pdf_parse_table_df = pd.read_csv(
        progress_file,
        dtype = {"file_name": str, "successfully_parsed": bool}
    )

    # Drop all observations which have at least one entry indicating the file was successfully parsed.
    pdf_parse_table_df = pdf_parse_table_df.groupby('file_name').filter(lambda x: (~x['successfully_parsed']).all())
else:
    # If it does not exist, it is our first time parsing these PDFs. Use the original file.
    pdf_parse_table_df = pd.read_csv(
        pdfs_to_parse,
        dtype = {"file_name": str, "successfully_parsed": bool}
    )

    # Create progress file.
    with open(progress_file, "w") as file:
        writer = csv.writer(file)
        writer.writerow(["file_name", "successfully_parsed", "time_stamp"])

for row in pdf_parse_table_df.itertuples():
    logging.info(f"Parsing... {row.file_name}")
    successfully_parsed_var = True

    # Read in the PDF
    pdf = pdfplumber.open(path_to_pdfs + row.file_name)

    # Concatenate all pages into one page, so to speak.
    pages = pdf.pages
    page_list = [page.extract_text(layout = True, x_density = 3.9, y_density = 13).split("\n") for page in pages]
    lines = [line for page in page_list for line in page]

    # Extract POI.
    try:
        poi_tuple = extract_poi(lines)
        poi_dict, current_line_index = poi_tuple
        logging.info("Successfully extracted POI.")
    except Exception as e:
        logging.error(f"Error in extracting POI. The error is {e}")
        successfully_parsed_var = False
        progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": False, "time_stamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}])
        progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
        break 

    # Set-up dictionary for court summary/criminal background data.
    ch_dict = {}

    # Loop through the rest of the lines and capture information about an individual's criminal history.
    while(current_line_index < len(lines)):
        try:
            result_tuple = extract_cases(current_line_index, lines)
            logging.info("Successfully extracted cases.")
        except Exception as e:
            logging.error(f"Error in extracting cases. The error is {e}")
            successfully_parsed_var = False
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": False, "time_stamp": timestamp}])
            progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
            break

        ch_dict, new_line_index = result_tuple
        
        current_line_index = new_line_index

    # Update personal demographics with criminal background.
    logging.info("Finished this file.\n")
    poi_dict.update(ch_dict)

    # Create name of JSON based on the name of the PDF we are parsing.
    filename = path_to_json + row.file_name.replace(".pdf", ".json")

    # Save dictionary as a JSON file and log successful progress in the progress file.
    if(successfully_parsed_var):
        # Log successful parsing.
        progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": True, "time_stamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}])
        progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
        
        # Save results.
        with open(filename, "w") as json_file:
            json.dump(poi_dict, json_file, indent = 4)