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

# Initialize paths and file names.
# Argument 1 is the root path of our files e.g., ~/secret_lives_pa/output/pdf_parse_list/ or /media/joe/T7 Shield/
# Argument 2 is the chunk of PDFs you want parsed e.g., Montgomery_CP_cs.csv
path_to_progress_file = arguments[1] + "progress_files/"
path_to_json = arguments[1] + "json/"
path_to_logs = arguments[1] + "log_files/"
os.makedirs(path_to_progress_file, exist_ok = True)
os.makedirs(path_to_json, exist_ok = True)
os.makedirs(path_to_logs, exist_ok = True)

target_county = arguments[2].split("_")[0]
path_to_pdfs = arguments[1] + "pdfs/" + target_county + "/"
pdfs_to_parse = arguments[1] + arguments[2]
progress_file = path_to_progress_file + "progress-" + arguments[2]
log_file = path_to_logs + "log_file_" + arguments[2].removesuffix(".csv") + "_" + datetime.now().strftime("%Y_%m_%d_%H_%M_%S") + ".txt"

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
    poi_start_index = [i for i, x in enumerate(lines_arg) if "DOB:" in x][0]
    poi_end_index = [i for i,x in enumerate(lines_arg) if "closed" in x.lower() or "inactive" in x.lower() or "active" in x.lower() or "adjudicated" in x.lower()][0]
    poi = lines_arg[poi_start_index:poi_end_index]

    # Name, DOB, and Sex appear on the first line.
    poi_dict["name"] = poi[0].split("DOB:")[0].strip()
    poi_dict["dob"] = poi[0].split("DOB:")[1].split("Sex:")[0].strip()
    poi_dict["sex"] = poi[0].split("DOB:")[1].split("Sex:")[1].strip()

    # Location and Eye Color appear on the second line.
    poi_dict["home_location"] = poi[1].split("Eyes:")[0].strip().lower()
    poi_dict["eyes"] = poi[1].split("Eyes:")[1].strip()

    # Alias and hair color are on the third line, but alias is blank on this line.
    poi_dict["hair"] = poi[2].split("Hair:")[1].strip()

    # The first alias and race are on the fourth line.
    alias = poi[3].split("Race:")[0].strip()
    poi_dict["race"] = poi[3].split("Race:")[1].strip()                          

    # The rest of the aliases are on subsequent lines.
    remainder_alias = poi[4:len(poi)]
    remainder_alias = [element.strip() for element in remainder_alias]
    remainder_alias.append(alias)
    poi_dict["alias"] = remainder_alias

    return poi_dict, poi_end_index
def extract_sqncs_and_sntncs(s_idx, s_lines, cur_docket_nr):
    # Initialize starting values.
    loop_through_sqncs_and_sntncs = True
    seq_nr = -1
    seq_nr_idx = "seq_" + str(seq_nr)
    sentence_nr = -1
    sentence_nr_idx = "sentence_" + str(sentence_nr)
    seq_dict = {}

    while(loop_through_sqncs_and_sntncs):

        # If the current line is the last line, exit out of the function.
        if(s_idx < len(s_lines)):
            cur_s_line = s_lines[s_idx].lower().strip()
        else:
            break

        # If the current line is a new set of case statuses or a new county, the function is completed.
        if((("closed" == cur_s_line or "inactive" == cur_s_line or "active" == cur_s_line or "adjudicated" == cur_s_line or cur_s_line in counties) and "continued" not in cur_s_line)):
            break
        elif("proc status: " in cur_s_line):
            # If the previous line has continued, we need to investigate.
            if("continued" in s_lines[s_idx - 1].lower().strip()):
                # Check and see if the current docket # equals the docket # of our current case. If so, we can skip this line since we already collected this info.
                cur_line_docket_number = cur_s_line.split("proc status:")[0].strip()
                if(cur_line_docket_number == cur_docket_nr):
                    s_idx += 1
                    continue
                # If the current docket # does not equal the docket # of out current case, it is a new case whose data we need to collect. Break out of this function.
                else:
                    break
            # If we have proc. status in the current line, and we do not have continued on the previous line, this is a new case. Exit the function.
            else:
                break
        # When we encounter §, it marks the beginning of a new sequence. We can split on the space between entries to capture the info.
        elif("§" in cur_s_line):
            # Reset the sentence counter because we are on a new sequence of charges.
            sentence_nr = -1
            sentence_nr_idx = "sentence_" + str(sentence_nr)
            
            seq_nr += 1
            seq_nr_idx = "seq_" + str(seq_nr)
            seq_dict[seq_nr_idx] = {}
            
            # You can think of the PDF as a fixed-width data table. Hopefully, each of these values is always contained within these lengths.
            seq_dict[seq_nr_idx]["seq_num"] = cur_s_line[:11].strip()
            seq_dict[seq_nr_idx]["statute"] = cur_s_line[11:48].strip()
            seq_dict[seq_nr_idx]["grade"] = cur_s_line[48:54].strip()
            seq_dict[seq_nr_idx]["description"] = cur_s_line[54:95].strip()
            seq_dict[seq_nr_idx]["disposition"] = cur_s_line[95:].strip()

        # When we encounter "min:" or "max:", we begin capturing the sentenced punishments.
        elif("min:" in cur_s_line or "max:" in cur_s_line or re.search(r"\d{2}/\d{2}/\d{4}", cur_s_line)):
            sentence_nr += 1
            sentence_nr_idx = "sentence_" + str(sentence_nr)
            seq_dict[seq_nr_idx][sentence_nr_idx] = {}

            # You can think of the PDF as a fixed-width data table. Hopefully, each of these values is always contained within these lengths.
            seq_dict[seq_nr_idx][sentence_nr_idx]["sentence_date"] = cur_s_line[:17].strip()
            seq_dict[seq_nr_idx][sentence_nr_idx]["sentence_type"] = cur_s_line[17:43].strip()
            seq_dict[seq_nr_idx][sentence_nr_idx]["program_period"] = cur_s_line[43:74].strip()
            seq_dict[seq_nr_idx][sentence_nr_idx]["sentence_length"] = cur_s_line[74:].strip()
            
        # Move on to the next line.
        s_idx += 1

    return seq_dict, s_idx
def extract_closed_cases(c_idx, c_lines):
    # Initialize starting values.
    loop_through_closed_cases = True
    closed_dict = {}
    case_nr = -1
    case_nr_idx = "case_" + str(case_nr)
    line_increment_c = c_idx
    
    while(loop_through_closed_cases):
        
        # If we are on the last line of the PDF, we have finished all closed cases.
        if(c_idx < len(c_lines)):
            cur_c_line = c_lines[c_idx].lower().strip()
        else:
            loop_through_closed_cases = False
            continue

        # If the current line has a case status, we have finished all closed cases.
        if(("inactive" == cur_c_line or "active" == cur_c_line or "adjudicated" == cur_c_line) and "continued" not in cur_c_line):
            loop_through_closed_cases = False
        # Check if the current line is a new county.
        elif(cur_c_line in counties):
            line_increment_c += 1
            county = cur_c_line
        # If we are not on a new county or new case status, then we are on a new case.
        # 1st line: Docket Number, Proc. Status, DC Number, and OTN Number.
        # 2nd line: Arrest date, disposition date, and disposition judge.
        # 3rd line: Defense attorney
        elif("proc status: " in cur_c_line):
            # If the previous line has continued, we need to investigate.
            if("continued" in c_lines[c_idx -1].lower().strip()):
                # Check and see if the current docket # equals the docket # in our dictionary. If so, we can skip this line since we already collected this info.
                # If the current docket # does not equal the docket # in our dictionary, it is new case whose data we need to collect.
                # Also, if this is the first docket # for this set of case statues, then this is also obviously a new case.
                cur_line_docket_number = cur_c_line.split("proc status:")[0].strip()
                if(case_nr != -1 and cur_line_docket_number == closed_dict[case_nr_idx]["docket_number"]):
                    line_increment_c += 1
                    c_idx = line_increment_c
                    continue

            line_increment_c += 1
            case_nr += 1
            case_nr_idx = "case_" + str(case_nr)
            closed_dict[case_nr_idx] = {}
            
            closed_dict[case_nr_idx]["county"] = county
            closed_dict[case_nr_idx]["docket_number"] = cur_c_line.split("proc status:")[0].strip()
            closed_dict[case_nr_idx]["proc_status"] = cur_c_line.split("proc status:")[1].split("dc no:")[0].strip().lower()
            closed_dict[case_nr_idx]["dc_nr"] = cur_c_line.split("proc status:")[1].split("dc no:")[1].split("otn:")[0].strip().lower()
            closed_dict[case_nr_idx]["otn_nr"] = cur_c_line.split("proc status:")[1].split("dc no:")[1].split("otn:")[1].strip().lower()
        elif("arrest dt: " in cur_c_line):
            line_increment_c += 1
            closed_dict[case_nr_idx]["arrest_date"] = cur_c_line.split("arrest dt:")[1].split("disp date:")[0].strip()
            closed_dict[case_nr_idx]["disp_date"] = cur_c_line.split("arrest dt:")[1].split("disp date:")[1].split("disp judge:")[0].strip()
            closed_dict[case_nr_idx]["disp_judge"] = cur_c_line.split("arrest dt:")[1].split("disp date:")[1].split("disp judge:")[1].strip()
        elif("def atty:" in cur_c_line):
            line_increment_c += 1
            closed_dict[case_nr_idx]["def_attorney"] = cur_c_line.split("def atty:")[1].strip()
        # When we encounter §, it marks the beginning of a new sequence.
        elif("§" in cur_c_line):
            result_tuple = extract_sqncs_and_sntncs(c_idx, c_lines, closed_dict[case_nr_idx]["docket_number"])
            sequence_dict, line_increment_c = result_tuple
            closed_dict[case_nr_idx].update(sequence_dict)
        # If the line does not contain any of the above characters, it's a junk line, and we can skip it.
        else:
            line_increment_c += 1

        c_idx = line_increment_c

    return closed_dict, c_idx
def extract_inactive_active_cases(ia_idx, ia_lines):
    # Initialize starting values.
    loop_through_ia_cases = True
    ia_dict = {}
    case_nr = -1
    case_nr_idx = "case_" + str(case_nr)
    line_increment_ia = ia_idx

    while(loop_through_ia_cases):
        # If we are on the last line of the PDF, we have finished all active/inactive/adjudicated cases.
        if(ia_idx < len(ia_lines)):
            cur_ia_line = ia_lines[ia_idx].lower().strip()
        else:
            loop_through_ia_cases = False
            continue

        # If the current line has a case status, we have finished all active/inactive/adjudicated cases.
        if((("closed" == cur_ia_line or "inactive" == cur_ia_line or "active" == cur_ia_line or "adjudicated" in cur_ia_line) and "continued" not in cur_ia_line)):
            loop_through_ia_cases = False
        # Check if the current line is a new county.
        elif(cur_ia_line in counties):
            line_increment_ia += 1
            county = cur_ia_line
        # If we are not on a new county or new case status, then we are on a new case.
        # 1st line: Docket Number, Proc. Status, DC Number, and OTN Number.
        # 2nd line: Arrest date, trial date, legacy number.
        # 3rd line: Last action, last action date, last action room.
        # 4th line: Next action, next action date, next action room.
        # Occasionally, the defense attorney will also be listed (in between the 2nd and 3rd line).
        # Also occasionally, we can get a disposition date and disposition judge on the 5th line.
        elif("proc status: " in cur_ia_line):
            # If the previous line has continued, we need to investigate.
            if("continued" in ia_lines[ia_idx - 1].lower().strip()):
                # Check and see if the current docket # equals the docket # in our dictionary. If so, we can skip this line since we already collected this info.
                # If the current docket # does not equal the docket # in our dictionary, it is new case whose data we need to collect.
                # Also, if this is the first docket # for this set of case statues, then this is also obviously a new case.
                cur_line_docket_number = cur_ia_line.split("proc status:")[0].strip()
                if(case_nr != -1 and cur_line_docket_number == ia_dict[case_nr_idx]["docket_number"]):
                    line_increment_ia += 1
                    ia_idx = line_increment_ia
                    continue

            line_increment_ia += 1
            case_nr += 1
            case_nr_idx = "case_" + str(case_nr)
            ia_dict[case_nr_idx] = {}

            ia_dict[case_nr_idx]["county"] = county
            ia_dict[case_nr_idx]["docket_number"] = cur_ia_line.split("proc status:")[0].strip()
            ia_dict[case_nr_idx]["proc_status"] = cur_ia_line.split("proc status:")[1].split("dc no:")[0].strip()
            ia_dict[case_nr_idx]["dc_nr"] = cur_ia_line.split("proc status:")[1].split("dc no:")[1].split("otn:")[0].strip()
            ia_dict[case_nr_idx]["otn_nr"] = cur_ia_line.split("proc status:")[1].split("dc no:")[1].split("otn:")[1].strip()
        elif("arrest dt: " in cur_ia_line):
            line_increment_ia += 1
            ia_dict[case_nr_idx]["arrest_date"] = cur_ia_line.split("arrest dt:")[1].split("trial dt:")[0].strip()
            ia_dict[case_nr_idx]["trial_date"] = cur_ia_line.split("trial dt:")[1].split("legacy no:")[0].strip()
            ia_dict[case_nr_idx]["legacy_number"] = cur_ia_line.split("trial dt:")[1].split("legacy no:")[1].strip()
        elif("last action: " in cur_ia_line):
            line_increment_ia += 1
            ia_dict[case_nr_idx]["last_action"] = cur_ia_line.split("last action:")[1].split("last action date:")[0].strip()
            ia_dict[case_nr_idx]["last_action_date"] = cur_ia_line.split("last action:")[1].split("last action date:")[1].split("last action room:")[0].strip()
            ia_dict[case_nr_idx]["last_action_room"] = cur_ia_line.split("last action:")[1].split("last action date:")[1].split("last action room:")[1].strip()
        elif("next action: " in cur_ia_line):
            line_increment_ia += 1
            ia_dict[case_nr_idx]["next_action"] = cur_ia_line.split("next action:")[1].split("next action date:")[0].strip()
            ia_dict[case_nr_idx]["next_action_date"] = cur_ia_line.split("next action:")[1].split("next action date:")[1].split("next action room:")[0].strip()
            ia_dict[case_nr_idx]["next_action_room"] = cur_ia_line.split("next action:")[1].split("next action date:")[1].split("next action room:")[1].strip()
        elif("def atty: " in cur_ia_line):
            line_increment_ia += 1
            ia_dict[case_nr_idx]["def_attorney"] = cur_ia_line.split("def atty:")[1].strip()
        # When we encounter §, it marks the beginning of a new sequence.
        elif("§" in cur_ia_line):
            result_tuple = extract_sqncs_and_sntncs(ia_idx, ia_lines, ia_dict[case_nr_idx]["docket_number"])
            sequence_dict, line_increment_ia = result_tuple
            ia_dict[case_nr_idx].update(sequence_dict)
        elif("disp date:" in cur_ia_line):
            line_increment_ia += 1
            ia_dict[case_nr_idx]["disp_date"] = cur_ia_line.split("disp date:")[1].split("disp judge:")[0].strip()
            ia_dict[case_nr_idx]["disp_judge"] = cur_ia_line.split("disp date:")[1].split("disp judge:")[1].strip()
        # If the line does not contain any of the above characters, it's a junk line, and we can skip it.
        else:
            line_increment_ia += 1

        ia_idx = line_increment_ia

    return ia_dict, ia_idx

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
    cs_dict = {}

    # Loop through the rest of the lines and capture information about an individual's criminal history.
    while(current_line_index < len(lines)):
        cur_line = lines[current_line_index].lower().strip()
        new_line_index = ""
        
        # Check if the current line is a new set of case (statuses).
        if(("closed" in cur_line or "inactive" in cur_line or "active" in cur_line or "adjudicated" in cur_line) and "continued" not in cur_line):
            case_status = cur_line
            cs_dict[case_status] = {}

            # Increment the index by 1 because we want to start parsing the line following the case status line.
            if(case_status == "closed"):
                try:
                    result_tuple = extract_closed_cases(current_line_index + 1, lines)
                    logging.info("Successfully extracted closed cases.")
                except Exception as e:
                    logging.error(f"Error in extracting closed cases. The error is {e}")
                    successfully_parsed_var = False
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": False, "time_stamp": timestamp}])
                    progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
                    break
            elif(case_status == "inactive" or case_status == "active" or case_status == "adjudicated"):
                try:
                    result_tuple = extract_inactive_active_cases(current_line_index + 1, lines)
                    logging.info("Successfully extracted inactive/active/adjudicated cases.")
                except Exception as e:
                    logging.error(f"Error in extracting inactive/active/adjudicated cases. The error is {e}")
                    successfully_parsed_var = False
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": False, "time_stamp": timestamp}])
                    progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
                    break

            cs_dict[case_status], new_line_index = result_tuple
        
        current_line_index = new_line_index

    # Update personal demographics with criminal background.
    logging.info("Finished this file.\n")
    poi_dict.update(cs_dict)

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