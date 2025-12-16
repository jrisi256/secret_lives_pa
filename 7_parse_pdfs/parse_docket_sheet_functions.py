import re
import json
import pandas as pd
import pdfplumber

# Extract text from PDF.
# Args:
#   pdf_path (str): File path to the PDF.
# Returns:
#   string: A single string which is the concatenated version of all pages and lines in the PDF.
def extract_text_from_pdf(pdf_path: str) -> str:
    # Open up the PDF and read in each page.
    pages = pdfplumber.open(pdf_path).pages
    # List comprehension. Structure is expression FOR x IN y.
    # Execute expression on each x in y.
    # Here we extract the text from each page. Then we separate each text element with the new line character.
    alltext = "\n".join([page.extract_text(keep_blank_chars=True, layout=True, x_density = 3.9, y_density = 13) for page in pages])
    return alltext

# Extracts sections from the document text.
# Args:
#   text (str): The text of the document.
# Returns:
#   dict: A dictionary containing the extracted sections with the section headers as keys.
def extract_sections(text: str) -> dict[str, str]:
    # Find lines that contain 4 or more upper-case characters and/or slashes and/or hyphens (and are bookended by white space).
    # These will be the section headers.
    section_header_pattern = re.compile(r"^\s*[A-Z\s\/\-]{4,}\s*$", re.MULTILINE)

    # Find all section headers and their starting character index.
    matches = re.finditer(section_header_pattern, text)

    # Iterate through each match and find the starting character index as well as the section header.
    headers = [(match.start(), match.group().strip()) for match in matches]
    # Drop any potential headers that are just empty whitespace or are only 3 non-white space characters.
    # We need to drop the 3 non-white space character headers because there are some acronyms that are all capital lettrs
    # and are surrounded only by white space in the CASE FINANCIAL INFORMATION section. E.g., OAG and PSP.
    # We also need to drop RRRI as a header. This can show as a punishment condition.
    headers = [h for h in headers if len(h[1]) > 3 and h[1] != "RRRI"]

    # Dictionary to store sections
    sections = {}

    # Iterate over headers and extract sections.
    for i in range(len(headers)):
        start_index = headers[i][0]
        header = headers[i][1]
        # Set the end index to be the start index of the next section header (or the end of the text file).
        end_index = headers[i + 1][0] if i + 1 < len(headers) else len(text)

        # Extract section text.
        section_text = text[start_index:end_index].strip()

        # Remove the header from the section text.
        section_text = section_text[len(header):].strip()

        # Sometimes, section headers do not carry over to new pages. To capture the information which overflows onto the next page, set the criminal docket header to the previous substantive header.
        # And then remove the junk from the top of the criminal docket header.
        if "CRIMINAL DOCKET" in header and i - 2 > 0:
            header = headers[i-2][1]
            section_text_list = [line for line in section_text.split("\n") if line.strip() != ""]
            section_text = "\n".join(section_text_list[5:])

        # Reduce different versions of the same header to a single version
        if "ATTORNEY INFORMATION" in header:
            header = "ATTORNEY INFORMATION"
        elif "BAIL INFORMATION" in header:
            header = "BAIL"
            
        # Add the current section header to our dictionary of sections.
        # setdefault searches for the key in your dictionary if it exists.
        # If it does exist, it returns the value associated with the key. If it does not exist, the key is inserted with the provided default value.
        sections.setdefault(header, "")

        # Add the section text to the dictionary under the header key.
        sections[header] += f"\n{section_text}"

    return sections

# Extracts the defendant's information from the DEFENDANT INFORMATION section.
# Args:
#   text (str): The text containing the defendant's information.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_defendant_information(text: str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    i = 0

    # Defendant information follows a straightforward pattern.
    # In CP dockets, there is only one line which contains defendant DOB and address.
    while(i < len(split)):
        line = split[i].lower().strip()
        if("date of birth:" in line and "city/state/zip:" in line):
            extracted_info["dob"] = line.split("date of birth:")[1].split("city/state/zip:")[0].strip()
            extracted_info["address"] = line.split("date of birth:")[1].split("city/state/zip:")[1].strip()
            i += 1
        # Line is a junk line. Keep moving on.
        else:
            i += 1
        
    return extracted_info

# Extracts the case information from the CASE INFORMATION section.
# Args:
#   text(str): The text containing the case information.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_case_information(text: str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    i = 0

    # Case information follows a straightforward pattern.
    # In CP dockets:
    #   Line 1 (Optional and potentially multiple lines) is cross court docket numbers.
    #   Line 2 is judge assigned, date filed, and initiation date.
    #   Line 3 is OTN, LOTN, and originating docket number.
    #   Line 4 is initial and final issuing authority.
    #   Line 5 is arresting agency (potentially multiple lines) and arresting officer.
    #   Line 6 is complaint/citation number and incident number.
    #   Line 7 is county and township.
    #   Line 8 + 9 is case local number type and case local number.
    while(i < len(split)):
        line = split[i].lower().strip()
        
        if("cross court docket nos:" in line):
            extracted_info["cross_court_docket_nrs"] = [item.strip() for item in line.replace("cross court docket nos:", "").split(",")]
            j = 1

            # Check the next line for more docket numbers.
            while("judge assigned" not in split[i + j].lower() and "date filed" not in split[i + j].lower() and "initiation date" not in split[i + j].lower()):
                lookahead_line = split[i + j].lower().strip()
                extracted_info["cross_court_docket_nrs"].extend([item.strip() for item in lookahead_line.replace("cross court docket nos:", "").split(",")])
                j += 1
            
            # Drop white space only entries.
            extracted_info["cross_court_docket_nrs"] = [item for item in extracted_info["cross_court_docket_nrs"] if item != ""]
            i += 1 + (j - 1)
        elif("judge assigned:" in line or "date filed:" in line or "initiation date:" in line):
            extracted_info["judge"] = line.split("judge assigned:")[1].split("date filed:")[0].strip()
            extracted_info["date_filed"] = line.split("judge assigned:")[1].split("date filed:")[1].split("initiation date:")[0].strip()
            extracted_info["initiation_date"] = line.split("judge assigned:")[1].split("date filed:")[1].split("initiation date:")[1].strip()
            i += 1
        elif("otn:" in line or "lotn:" in line or "originating docket no:" in line):
            extracted_info["otn"] = line.split("lotn:")[0].split("otn:")[1].strip()
            extracted_info["lotn"] = line.split("lotn:")[1].split("originating docket no:")[0].strip()
            extracted_info["originating_docket_nr"] = line.split("lotn:")[1].split("originating docket no:")[1].strip()
            i += 1
        elif("initial issuing authority:" in line or "final issuing authority:" in line):
            extracted_info["initial_issuing_authority"] = line.split("initial issuing authority:")[1].split("final issuing authority:")[0].strip()
            extracted_info["final_issuing_authority"] = line.split("initial issuing authority:")[1].split("final issuing authority:")[1].strip()
            j = 1

            # Check the next line to see if initial issuing authority and/or final issuing authority spilled over into the next line.
            while("arresting agency:" not in split[i + j].lower() and "arresting officer:" not in split[i + j].lower()):
                lookahead_line = split[i + j].lower()
                extracted_info["initial_issuing_authority"] = extracted_info["initial_issuing_authority"] + " " + lookahead_line[:66].strip()
                extracted_info["final_issuing_authority"] = extracted_info["final_issuing_authority"] + " " + lookahead_line[66:].strip()
                j += 1

            i += 1 + (j - 1)
        elif("arresting agency" in line or "arresting officer" in line):
            extracted_info["arresting_agency"] = line.split("arresting agency:")[1].split("arresting officer:")[0].strip()
            extracted_info["arresting_officer"] = line.split("arresting agency:")[1].split("arresting officer:")[1].strip()
            j = 1

            # Check the next line to see if arresting agency spilled over onto the next line.
            while("complaint/citation no.:" not in split[i + j].lower() and "incident number:" not in split[i + j].lower()):
                lookahead_line = split[i + j].lower().strip()
                extracted_info["arresting_agency"] = extracted_info["arresting_agency"] + " " + lookahead_line
                j += 1

            i += 1 + (j - 1)
        elif("complaint/citation no.:" in line or "incident number:" in line):
            extracted_info["complaint_citation_nr"] = line.split("complaint/citation no.:")[1].split("incident number:")[0].strip()
            extracted_info["incident_nr"] = line.split("complaint/citation no.:")[1].split("incident number:")[1].strip()
            i += 1
        elif("county:" in line or "township:" in line):
            extracted_info["county"] = line.split("county:")[1].split("township:")[0].strip()
            extracted_info["township"] = line.split("county:")[1].split("township:")[1].strip()
            i += 1
        elif("case local number type(s)" in line or "case local number(s)" in line):
            # Move on to the next line because that is where this information will be stored.
            extracted_info["case_local_number_type"] = []
            extracted_info["case_local_number"] = []
            j = 1

            while(i + j < len(split)):
                lookahead_line = split[i + j].lower().strip()
                case_local_number_type = lookahead_line[:34].strip()
                case_local_number = lookahead_line[34:].strip()
                extracted_info["case_local_number_type"].append(case_local_number_type)
                extracted_info["case_local_number"].append(case_local_number)
                j += 1
            
            i += 1 + (j - 1)

        # Junk line. Keep moving.
        else:
            i += 1
                
    return extracted_info

# Extracts the charges from the CHARGES section.
# Args:
#   text(str): The text containing the charges information.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_charges(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    charge_nr = -1
    charge_nr_idx = "charge_nr_" + str(charge_nr)
    i = 0

    while(i < len(split)):
        line = split[i].lower().strip()

        # Skip blank lines, column header line, and junk lines.
        if(("seq." in line and "orig seq." in line and "statute" in line and "grade" in line) or line == "" or "reflected on these docket sheets" in line or "assume any liability for inaccurate" in line or "docket sheet information should" in line or "who does not comply" in line or "liability as set forth" in line or "cpcms" in line):
            i+=1
        # The § character indicates a new charge.
        elif("§" in line):
            charge_nr += 1
            charge_nr_idx = "charge_nr_" + str(charge_nr)
            extracted_info[charge_nr_idx] = {}

            # Each charge adheres to the following pattern.
            extracted_info[charge_nr_idx]["seq"] = line[:11].strip()
            extracted_info[charge_nr_idx]["orig_seq"] = line[11:22].strip()
            extracted_info[charge_nr_idx]["grade"] = line[22:31].strip()
            extracted_info[charge_nr_idx]["statute"] = line[31:56].strip()
            extracted_info[charge_nr_idx]["description"] = line[56:102].strip()
            extracted_info[charge_nr_idx]["offense_date"] = line[102:118].strip()
            extracted_info[charge_nr_idx]["otn"] = line[118:].strip()
            i += 1
        # If the line is not a header line, a blank line, a new charge, or a junk line, then it is the description from the previous charge overflowing onto a new line.
        else:
            extracted_info[charge_nr_idx]["description"] = extracted_info[charge_nr_idx]["description"] + " " + line.strip()
            i += 1
    
    return(extracted_info)

# Extracts the sentencing and disposition information from the DISPOSITION/SENTENCING section.
# Args:
#   text(str): The text containing the disposition and sentencing information.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_sentencing(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0

    # Possible punishments.
    punishments = "^confinement$|^probation$|^ipp$|^ard$|^ard\s*-\s*dui$|^drug court$"

    # Counters for specific elements of the dictionary.
    case_event_nr = -1
    case_event_idx = "case_event_nr_" + str(case_event_nr)
    offense_nr = -1
    offense_idx = "offense_nr_" + str(offense_nr)
    sentence_nr = -1
    sentence_idx = "sentence_nr_" + str(sentence_nr)
    punish_nr = -1
    punish_idx = "punish_nr_" + str(punish_nr)
    linked_sentences = False
    punish_start_date = False
    link_nr = ""
    
    while(i < len(split)):
        line = split[i].lower().strip()
        disp_date = line[60:98].strip()
        
        # If you see a date on a line that does not have: 1) a name, 2) a hour/day/week/month/year (indicating a punishment), or 3) printed: (end of page),
        # then it is the case event/disposition date/final disposition line (2nd element).
        if(re.search(r"^\d{2}/\d{2}/\d{4}$", disp_date) and not re.search("^[A-Za-z'\-]+\s*,\s*[A-Za-z\-]+", line) and not re.search("hour|day|week|month|year", line) and not re.search("printed:", line)):
            case_event_nr += 1
            case_event_idx = "case_event_nr_" + str(case_event_nr)
            extracted_info[case_event_idx] = {}

            # Reset offense index.
            offense_nr = -1
            offense_idx = "offense_nr_" + str(offense_nr)

            extracted_info[case_event_idx]["case_event"] = line[:60].strip()
            extracted_info[case_event_idx]["disposition_date"] = line[60:98].strip()
            extracted_info[case_event_idx]["final_disposition"] = line[98:].strip()

            # This line has the case disposition and if the defendant was present.
            previous_line = split[i - 1].lower().strip()
            extracted_info[case_event_idx]["disposition"] = re.sub("defendant.*present", "", previous_line).strip()
            if(re.search(r"defendant was present", previous_line)):
                extracted_info[case_event_idx]["defendant_present"] = True
            elif(re.search(r"defendant was not present", previous_line)):
                extracted_info[case_event_idx]["defendant_present"] = False
            else:
                extracted_info[case_event_idx]["defendant_present"] = None
        # The § character indicates the line where the offense is laid out (3rd element).
        elif(re.search(r"§", line) and not linked_sentences):
            offense_nr += 1
            offense_idx = "offense_nr_" + str(offense_nr)
            
            # Reset sentence index.
            sentence_nr = - 1
            sentence_idx = "sentence_nr_" + str(sentence_nr)

            # Reset punishment flag (ran into an issue where the description is multiple lines).
            # If you transition into a new offense straight from a punishment, the flag will not have been reset.
            # Parser will think this is a punishment condition.
            punish_start_date = False

            extracted_info[case_event_idx][offense_idx] = {}
            extracted_info[case_event_idx][offense_idx]["offense_description"] = line[:61].strip()
            extracted_info[case_event_idx][offense_idx]["offense_disposition"] = line[61:100].strip()
            extracted_info[case_event_idx][offense_idx]["grade"] = line[100:110].strip()
            extracted_info[case_event_idx][offense_idx]["offense_section"] = line[110:].strip()
        # If you see a date and a name, this is the line with the judge who handed down the sentence (4th element).
        elif(re.search(r"\d{2}/\d{2}/\d{4}", line) and re.search("^[A-Za-z'\-]+\s*,\s*[A-Za-z'\-]+", line)):
            sentence_nr += 1
            sentence_idx = "sentence_nr_" + str(sentence_nr)
            extracted_info[case_event_idx][offense_idx][sentence_idx] = {}

            # Reset punishment index.
            punish_nr = -1
            punish_idx = "punish_nr_" + str(punish_nr)
            punish_start_date = False

            extracted_info[case_event_idx][offense_idx][sentence_idx]["sentencing_judge"] = line[:60].strip()
            extracted_info[case_event_idx][offense_idx][sentence_idx]["sentencing_date"] = line[60:100].strip()
            extracted_info[case_event_idx][offense_idx][sentence_idx]["credit_for_time_served"] = line[100:].strip()
        # If you find hour, day, week, month or year and a date or a punishment from the list of punishments, this is the first line of the sentence length (5th element).
        # Unfortunately, not every punishment has a start date.
        elif(re.search(r"hour|day|week|month|year", line) and (re.search(r"\d{2}/\d{2}/\d{4}", line) or re.search(punishments, line[:60].strip()))):
            # Move the punishment counter up 1 and initialize the punishment dictionary.
            punish_nr += 1
            punish_idx = "punish_nr_" + str(punish_nr)

            # Because the nested hierarchy is not always respected, you can sometimes get a punishment without a sentence.
            if(sentence_idx == "sentence_nr_-1"):
                sentence_nr = 0
                sentence_idx = "sentence_nr_" + str(sentence_nr)
                extracted_info[case_event_idx][offense_idx][sentence_idx] = {}

            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx] = {}
            
            # Signal we are in the punishment block.
            punish_start_date = True
            
            # Set initial conditions to blank and extract other information.
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_type"] = line[:60].strip()
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_start_date"] = line[101:].strip()
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_conditions"] = ""
        
            if(re.search(r"min of", line)):
                extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["min_punishment"] = line[60:101].strip()
            elif(re.search(r"max of", line)):
                extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["max_punishment"] = line[60:101].strip()
            # Sometimes a punishment will not be given a minimum or maximum but just the length
            else:
                extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment"] = line[60:101].strip()
        # Sometimes, the punishment will just be 'no further penalty' or 'merged'.
        elif(re.search("no further penalty|merged", line)):
            # Move the punishment counter up 1 and initialize the punishment dictionary.
            punish_nr += 1
            punish_idx = "punish_nr_" + str(punish_nr)

            # Because the nested hierarchy is not always respected, you can sometimes get a punishment without a sentence.
            if(sentence_idx == "sentence_nr_-1"):
                sentence_nr = 0
                sentence_idx = "sentence_nr_" + str(sentence_nr)
                extracted_info[case_event_idx][offense_idx][sentence_idx] = {}

            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx] = {}
            
            # Signal we are in the punishment block.
            punish_start_date = True

            # Extract information.
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_conditions"] = ""
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_type"] = line
        # If you find the phrase of "min of" and you already found the punishment start date, then this is the 2nd line of the sentence length (5th element).
        elif(punish_start_date and re.search(r"min of", line)):
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["min_punishment"] = line
        # If you find the phrase of "max of" and you already found the punishment start date, then this is the 2nd line of the sentence length (5th element).
        elif(punish_start_date and re.search(r"max of", line)):
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["max_punishment"] = line
        # Signal we are in the linked sentences block.
        elif(re.search(r"linked sentences", line)):
            linked_sentences = True
            # We are no longer in the punishment block.
            punish_start_date = False
        # If we are still in the punishment block, and we have not reached the linked sentences yet, then we are on punishment conditions.
        elif(punish_start_date and not linked_sentences):
            extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_conditions"] = extracted_info[case_event_idx][offense_idx][sentence_idx][punish_idx]["punishment_conditions"] + "|" + line
        # Found a new linked sentence.
        elif(re.search(r"link \d+", line)):
            link_nr = re.findall(r"link \d+", line)[0]
            extracted_info[link_nr] = ""
        # If we are in the linked sentences block, just capture the information.
        elif(linked_sentences):
            extracted_info[link_nr] = extracted_info[link_nr] + "|" + line
        
        i += 1

    return(extracted_info)

# Extracts confinement information from the CONFINEMENT INFORMATION section.
# Args:
#   text(str): The text containing the case information.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_confinement(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    confinement_nr = -1
    confinement_idx = "confinement_nr_" + str(confinement_nr)
    
    # Line counter.
    i = 0

    while(i < len(split)):
        line = split[i].lower().strip()

        # Capture confinement information.
        if("confinement" not in line and "known as of" not in line and "cpcms" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set forth" not in line and line != ""):
            confinement_nr += 1
            confinement_idx = "confinement_nr_" + str(confinement_nr)
            extracted_info[confinement_idx] = {}

            extracted_info[confinement_idx]["confinement_date"] = line[:19].strip()
            extracted_info[confinement_idx]["confinement_type"] = line[19:55].strip()
            extracted_info[confinement_idx]["confinement_location"] = line[55:89].strip()
            extracted_info[confinement_idx]["confinement_reason"] = line[89:122].strip()
            extracted_info[confinement_idx]["in_custody"] = line[122:].strip()
        
        i += 1

    return(extracted_info)

# Extracts status information from the STATUS INFORMATION section.
# Args:
#   text(str): The text containing the status information.
# Return:
#   dict: A dictionary containing the status information.
def extract_status(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0
    status_nr = -1
    status_idx = "status_nr_" + str(status_nr)

    while(i < len(split)):
        line = split[i].lower().strip()
        
        if("case status:" in line):
            extracted_info["case_status"] = line.split("case status:")[1].split("status date")[0].strip()
        if("arrest date:" in line):
            extracted_info["arrest_date"] = line.split("arrest date:")[1].strip()
        if("complaint date:" in line):
            extracted_info["complaint_date"] = line.split("complaint date:")[1].strip()
        if(re.search(r"\d{2}/\d{2}/\d{4}", line) and "arrest date" not in line and "complaint date" not in line and "cpcms" not in line):
            status_nr += 1
            status_idx = "status_nr_" + str(status_nr)
            extracted_info[status_idx] = {}
            extracted_info[status_idx]["status_date"] = line[:20].strip()
            extracted_info[status_idx]["processing_status"] = line[20:].strip()
        
        i += 1
    
    return(extracted_info)

# Extracts calendar events from the CALENDAR EVENTS section.
# Args:
#   text(str): The text containing the calendar events information.
# Return:
#   dict: A dictionary containing the calendar events information.
def extract_calendar_events(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0
    event_nr = -1
    event_idx = "event_nr_" + str(event_nr)

    while(i < len(split)):
        line = split[i].lower()
        
        # If we find a date on the line (that is not at the end of the document), then it is a calendar event.
        if(re.search(r"\d{2}/\d{2}/\d{4}", line) and "printed" not in line):
            event_nr += 1
            event_idx = "event_nr_" + str(event_nr)
            extracted_info[event_idx] = {}

            extracted_info[event_idx]["event_type"] = line[:37].strip()
            extracted_info[event_idx]["start_date"] = line[37:49].strip()
            extracted_info[event_idx]["start_time"] = line[49:65].strip()
            extracted_info[event_idx]["room"] = line[65:90].strip()
            extracted_info[event_idx]["judge"] = line[90:127].strip()
            extracted_info[event_idx]["schedule_status"] = line[127:].strip()

        # If we do not find a date, but it is not the end of the document nor is it the header row or an empty row, then it is an overflow row.
        elif("case calendar" not in line and "event type" not in line and "cpcms" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set forth" not in line and line != ""):
            extracted_info[event_idx]["event_type"] = extracted_info[event_idx]["event_type"] + " " + line[:37].strip()
            extracted_info[event_idx]["start_date"] = extracted_info[event_idx]["start_date"] + " " + line[37:49].strip()
            extracted_info[event_idx]["start_time"] = extracted_info[event_idx]["start_time"] + " " + line[49:65].strip()
            extracted_info[event_idx]["room"] = extracted_info[event_idx]["room"] + " " + line[65:90].strip()
            extracted_info[event_idx]["judge"] = extracted_info[event_idx]["judge"] + " " + line[90:127].strip()
            extracted_info[event_idx]["schedule_status"] = extracted_info[event_idx]["schedule_status"] + " " + line[127:].strip()
        
        i += 1
    
    return(extracted_info)

# Extracts case participants from the CASE PARTICIPANTS section.
# Args:
#   text(str): The text containing the case participants.
# Return:
#   dict: A dictionary containing the case participant information.
def extract_case_participants(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0
    participant_nr = -1
    participant_idx = "participant_nr_" + str(participant_nr)

    while(i < len(split)):
        line = split[i].lower().strip()
        
        # If it is not the end of the document nor is it the header row or an empty row, then it is a case participant.
        if("participant" not in line and "cpcms" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set fort" not in line and line != ""):
            participant_nr += 1
            participant_idx = "participant_nr_" + str(participant_nr)
            extracted_info[participant_idx] = {}

            extracted_info[participant_idx]["participant_type"] = line[:45].strip()
            extracted_info[participant_idx]["name"] = line[45:].strip()
        
        i += 1
    
    return(extracted_info)

# Extract attorney information from the ATTORNEY INFORMATION section.
# Args:
#   text(str): The text containing the attorney information.
# Return:
#   dict: A dictionary containing the attorney information.
def extract_attorney_info(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    i = 0

    # Split each line into the prosecutor side and the defense side.
    prosecutor_lines = [line[:67].strip().lower() for line in split]
    prosecutor_nr = -1
    prosecutor_idx = "prosecutor_nr_" + str(prosecutor_nr)
    defense_lines = [line[67:].strip().lower() for line in split]
    defense_nr = -1
    defense_idx = "defense_nr_" + str(defense_nr)
    attorney_dict = {}
    attorney_dict["prosecutors"] = {}
    attorney_dict["defense"] = {}

    # Use these to signal what section of the prosecutor text we are in.
    prosecutor_name_block = False
    prosecutor_scNr_block = False
    prosecutor_phoneNr_block = False
    prosecutor_address_block = False
    
    # Use these to signal what section of the defense text we are in.
    defense_name_block = False
    defense_scNr_block = False
    defense_repStatus_block = False
    defense_phoneNr_block = False
    defense_address_block = False
    defense_representing_block = False
    
    while(i < len(split)):
        p_line = prosecutor_lines[i].strip().lower()
        d_line = defense_lines[i].strip().lower()
        
        # Prosecutor information.
        if("name:" in p_line):
            prosecutor_name_block = True
            prosecutor_scNr_block = False
            prosecutor_phoneNr_block = False
            prosecutor_address_block = False
            prosecutor_nr += 1
            prosecutor_idx = "prosecutor_nr_" + str(prosecutor_nr)
            attorney_dict["prosecutors"][prosecutor_idx] = {}
            attorney_dict["prosecutors"][prosecutor_idx]["name"] = p_line.split("name:")[1].strip()
        elif("supreme court no:" in p_line):
            prosecutor_scNr_block = True
            prosecutor_name_block = False
            prosecutor_phoneNr_block = False
            prosecutor_address_block = False
            attorney_dict["prosecutors"][prosecutor_idx]["supreme_court_nr"] = p_line.split("supreme court no:")[1].strip()
        elif("phone number(s):" in p_line):
            prosecutor_phoneNr_block = True
            prosecutor_name_block = False
            prosecutor_address_block = False
            prosecutor_scNr_block = False
            attorney_dict["prosecutors"][prosecutor_idx]["phone_nr"] = p_line.split("phone number(s):")[1].strip()
        elif("address:" in p_line):
            prosecutor_address_block = True
            prosecutor_name_block = False
            prosecutor_scNr_block = False
            prosecutor_phoneNr_block = False
            attorney_dict["prosecutors"][prosecutor_idx]["address"] = p_line.split("address:")[1].strip()
        elif("cpcms" not in p_line and "recent entries" not in p_line and "administrative" not in p_line and "docket sheet" not in p_line and "comply" not in p_line and "set fort" not in p_line and "commonwealth" not in p_line and "pennsylvania" not in p_line and "these reports" not in p_line and "information" not in p_line):
            if(prosecutor_name_block):
                attorney_dict["prosecutors"][prosecutor_idx]["name"] = attorney_dict["prosecutors"][prosecutor_idx]["name"] + "|" + p_line
            elif(prosecutor_scNr_block):
                attorney_dict["prosecutors"][prosecutor_idx]["supreme_court_nr"] = attorney_dict["prosecutors"][prosecutor_idx]["supreme_court_nr"] + "|" + p_line
            elif(prosecutor_phoneNr_block):
                attorney_dict["prosecutors"][prosecutor_idx]["phone_nr"] = attorney_dict["prosecutors"][prosecutor_idx]["phone_nr"] + "|" + p_line
            elif(prosecutor_address_block):
                attorney_dict["prosecutors"][prosecutor_idx]["address"] = attorney_dict["prosecutors"][prosecutor_idx]["address"] + "|" + p_line

        # Defense information.
        if("name:" in d_line):
            defense_name_block = True
            defense_scNr_block = False
            defense_phoneNr_block = False
            defense_address_block = False
            defense_repStatus_block = False
            defense_representing_block = False
            defense_nr += 1
            defense_idx = "defense_nr_" + str(defense_nr)
            attorney_dict["defense"][defense_idx] = {}
            attorney_dict["defense"][defense_idx]["name"] = d_line.split("name:")[1].strip()
        elif("supreme court no:" in d_line):
            defense_scNr_block = True
            defense_name_block = False
            defense_phoneNr_block = False
            defense_address_block = False
            defense_repStatus_block = False
            defense_representing_block = False
            attorney_dict["defense"][defense_idx]["supreme_court_nr"] = d_line.split("supreme court no:")[1].strip()
        elif("rep. status:" in d_line):
            defense_repStatus_block = True
            defense_scNr_block = False
            defense_name_block = False
            defense_phoneNr_block = False
            defense_address_block = False
            defense_representing_block = False
            attorney_dict["defense"][defense_idx]["rep_status"] = d_line.split("rep. status:")[1].strip()
        elif("phone number(s):" in d_line):
            defense_phoneNr_block = True
            defense_name_block = False
            defense_address_block = False
            defense_scNr_block = False
            defense_repStatus_block = False
            defense_representing_block = False
            attorney_dict["defense"][defense_idx]["phone_nr"] = d_line.split("phone number(s):")[1].strip()
        elif("address:" in d_line):
            defense_address_block = True
            defense_name_block = False
            defense_scNr_block = False
            defense_phoneNr_block = False
            defense_repStatus_block = False
            defense_representing_block = False
            attorney_dict["defense"][defense_idx]["address"] = d_line.split("address:")[1].strip()
        elif("representing:" in d_line):
            defense_representing_block = True
            defense_repStatus_block = False
            defense_scNr_block = False
            defense_name_block = False
            defense_phoneNr_block = False
            defense_address_block = False
            attorney_dict["defense"][defense_idx]["representing"] = d_line.split("representing:")[1].strip()
        elif("cpcms" not in d_line and "recent entries" not in d_line and "administrative" not in d_line and "docket sheet" not in d_line and "comply" not in d_line and "set fort" not in d_line and "commonwealth" not in d_line and "pennsylvania" not in d_line and "these reports" not in d_line and "information" not in d_line and "printed" not in d_line):
            if(defense_name_block):
                attorney_dict["defense"][defense_idx]["name"] = attorney_dict["defense"][defense_idx]["name"] + "|" + d_line
            elif(defense_scNr_block):
                attorney_dict["defense"][defense_idx]["supreme_court_nr"] = attorney_dict["defense"][defense_idx]["supreme_court_nr"] + "|" + d_line
            elif(defense_phoneNr_block):
                attorney_dict["defense"][defense_idx]["phone_nr"] = attorney_dict["defense"][defense_idx]["phone_nr"] + "|" + d_line
            elif(defense_address_block):
                attorney_dict["defense"][defense_idx]["address"] = attorney_dict["defense"][defense_idx]["address"] + "|" + d_line
            elif(defense_repStatus_block):
                attorney_dict["defense"][defense_idx]["rep_status"] = attorney_dict["defense"][defense_idx]["rep_status"] + "|" + d_line
            elif(defense_representing_block):
                attorney_dict["defense"][defense_idx]["representing"] = attorney_dict["defense"][defense_idx]["representing"] + "|" + d_line

        i += 1
    
    return(attorney_dict)

# Extract bail information from the BAIL / BAIL INFORMATION section.
# Args:
#   text(str): The text containing the bail information.
# Return:
#   dict: A dictionary containing the bail information.
def extract_bail(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    i = 0
    bail_dict = {}

    # Initialize bail information.
    bail_dict["bail_info"] = {}
    bail_block = False
    bail_nr = -1
    bail_idx = "bail_nr_" + str(bail_nr)

    # Initialize surety information.
    bail_dict["surety_info"] = {}
    surety_block = False
    surety_nr = -1
    surety_idx = "surety_nr_" + str(surety_nr)
    
    while(i < len(split)):
        line = split[i].lower()

        if("nebbia status:" in line):
            bail_dict["nebbia_status"] = line.split("nebbia status:")[1].strip()
        elif("bail action" in line):
            bail_block = True
            surety_block = False
        elif("surety type" in line):
            surety_block = True
            bail_block = False

        if(bail_block and "cpcms" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set fort" not in line and "bail action" not in line and "court case" not in line and "commonwealth" not in line and line.strip() != ""):
            # If the bail date is blank, the bail action overflowed onto the next line.
            if(line[38:65].strip() == ""):
                bail_dict["bail_info"][bail_idx]["bail_action"] = bail_dict["bail_info"][bail_idx]["bail_action"] +  " " + line[:38].strip()
            # Otherwise, continue collecting the surety information as normal.
            else:
                # Initialize starting values.
                bail_nr += 1
                bail_idx = "bail_nr_" + str(bail_nr)
                bail_dict["bail_info"][bail_idx] = {}

                # Set values for bail.
                bail_dict["bail_info"][bail_idx]["bail_action"] = line[:38].strip()
                bail_dict["bail_info"][bail_idx]["date"] = line[38:65].strip()
                bail_dict["bail_info"][bail_idx]["bail_type"] = line[65:88].strip()
                bail_dict["bail_info"][bail_idx]["originating_court"] = line[88:118].strip()
                bail_dict["bail_info"][bail_idx]["percentage"] = line[118:132].strip()
                bail_dict["bail_info"][bail_idx]["amount"] = line[132:].strip()
        elif(surety_block and "cpcms" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set fort" not in line and "surety type" not in line and "court case" not in line and "commonwealth" not in line and line.strip() != ""):
            # If the surety type is blank, the surety name overflowed onto the next line.
            if(line[:27].strip() == ""):
                bail_dict["surety_info"][surety_idx]["surety_name"] = bail_dict["surety_info"][surety_idx]["surety_name"] +  " " + line[27:54].strip()
            # Otherwise, continue collecting the surety information as normal.
            else:
                # Initialize starting values.
                surety_nr += 1
                surety_idx = "surety_nr_" + str(surety_nr)
                bail_dict["surety_info"][surety_idx] = {}

                # Set values for surety.
                bail_dict["surety_info"][surety_idx]["surety_type"] = line[:38].strip()
                bail_dict["surety_info"][surety_idx]["surety_name"] = line[38:65].strip()
                bail_dict["surety_info"][surety_idx]["posting_status"] = line[65:88].strip()
                bail_dict["surety_info"][surety_idx]["posting_date"] = line[88:105].strip()
                bail_dict["surety_info"][surety_idx]["security_type"] = line[105:133].strip()
                bail_dict["surety_info"][surety_idx]["security_amount"] = line[133:].strip()

        i += 1
    
    return(bail_dict)

# Extract case financial information from the CASE FINANCIAL INFORMATION section.
# Args:
#   text(str): The text containing the case financial information.
# Return:
#   dict: A dictionary containing the case financial information.
def extract_case_financial_info(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    i = 0
    case_financial_dict = {}
    fee_nr = -1
    fee_idx = "fee_nr_" + str(fee_nr)
    case_financial_block = False
    
    while(i < len(split)):
        line = split[i].lower()

        if(re.search(r"costs\/fees$|restitution$|fines$", line.strip())):
            case_financial_block = True

        header_line1 = "assessment" in line or "payments" in line or "adjustments" in line or "non monetary" in line or "balance" in line
        header_line2 = "defendant" in line and "payments" in line

        if(not re.search(r"costs\/fees$|restitution$|fines$", line.strip()) and case_financial_block and "reflected on these docket sheets" not in line and "assume any liability for inaccurate" not in line and "docket sheet information should" not in line and "who does not comply" not in line and "liability as set forth" not in line and "assessment is subrogated" not in line and "cpcms" not in line and line.strip() != "" and not header_line1 and not header_line2):
            # If the first part is not blank but every other part is blank, then the description overflowed onto the next line.
            if(line[:62].strip() != "" and line[62:83].strip() == "" and line[83:99].strip() == "" and line[99:116].strip() == "" and line[116:133].strip() == "" and line[133:].strip() == ""):
                case_financial_dict[fee_idx]["description"] = case_financial_dict[fee_idx]["description"] + " " + line.strip()
            else:
                fee_nr += 1
                fee_idx = "fee_nr_" + str(fee_nr)
                case_financial_dict[fee_idx] = {}

                case_financial_dict[fee_idx]["description"] = line[:60].strip()
                case_financial_dict[fee_idx]["assessment"] = line[60:78].strip()
                case_financial_dict[fee_idx]["payment"] = line[78:99].strip()
                case_financial_dict[fee_idx]["adjustment"] = line[99:116].strip()
                case_financial_dict[fee_idx]["non_monetary_payment"] = line[116:133].strip()
                case_financial_dict[fee_idx]["balance"] = line[133:].strip()

        i += 1
    
    return(case_financial_dict)

# Extract related cases from the RELATED CASES section.
# Args:
#   text(str): The text containing the related cases.
# Return:
#   dict: A dictionary containing the related cases.
def extract_related_cases(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    i = 0
    related_cases_dict = {}
    related_case_nr = -1
    related_case_idx = "related_case_nr_" + str(related_case_nr)
    
    while(i < len(split)):
        line = split[i].lower()

        if("related docket no" not in line and "reflected on these docket sheets" not in line and "assume any liability for inaccurate" not in line and "docket sheet information should" not in line and "who does not comply" not in line and "liability as set forth" not in line and "cpcms" not in line and line.strip() != ""):
            # If only the relation reason column has an entry and every other column is empty, then the reason column overflowed on to the next line.
            if(line[114:].strip() != "" and line[:43].strip() == "" and line[43:89].strip() == "" and line[89:114].strip() == ""):
                related_cases_dict[related_case_idx]["relation_reason"] = related_cases_dict[related_case_idx]["relation_reason"] + " " + line.strip()
            # If the related court and relation reason columns are blank, it is a bold line categorizing the related cases together.
            # I do not really think we need this information.
            elif(line[89:114].strip() != "" and line[114:].strip() != ""):
                related_case_nr += 1
                related_case_idx = "related_case_nr_" + str(related_case_nr)
                related_cases_dict[related_case_idx] = {}

                related_cases_dict[related_case_idx]["related_docket_nr"] = line[:43].strip()
                related_cases_dict[related_case_idx]["related_case_caption"] = line[43:89].strip()
                related_cases_dict[related_case_idx]["related_court"] = line[89:114].strip()
                related_cases_dict[related_case_idx]["relation_reason"] = line[114:].strip()

        i += 1
    
    return(related_cases_dict)

# Extract payment plan summary from the PAYMENT PLAN SUMMARY section.
# Args:
#   text(str): The text containing the payment plan summary.
# Return:
#   dict: A dictionary containing the payment plan summary.
def extract_payment_plan_summary(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    i = 0
    payment_plan_dict = {}
    payment_plan_info_block = False
    payment_plan_history_block = False
    payment_nr = -1
    payment_idx = "payment_nr_" + str(payment_nr)
    
    while(i < len(split)):
        line = split[i].lower()

        if("payment plan no" in line or "responsible participant" in line):
            payment_plan_info_block = True
            payment_plan_history_block = False
        elif("payment plan history:" in line):
            payment_plan_info_block = False
            payment_plan_history_block = True

        if(payment_plan_info_block and "payment plan no" not in line and "responsible participant" not in line and "reflected on these docket sheets" not in line and "assume any liability for inaccurate" not in line and "docket sheet information should" not in line and "who does not comply" not in line and "liability as set forth" not in line and "cpcms" not in line and line.strip() != ""):
            # If there is a date or a payment plan ID, then it is the first line of the payment plan information.
            if(re.search(r"\d{2}/\d{2}/\d{4}", line) or re.search(r"\d{2}-\d{4}-\w+", line)):
                payment_plan_dict["payment_plan_nr"] = line[:41].strip()
                payment_plan_dict["payment_plan_freq"] = line[41:74].strip()
                payment_plan_dict["next_due_date"] = line[74:98].strip()
                payment_plan_dict["active"] = line[98:133].strip()
                payment_plan_dict["overdue_amount"] = line[133:].strip()
            else:
                payment_plan_dict["participant"] = line[:98].strip()
                payment_plan_dict["suspended"] = line[98:133].strip()
                payment_plan_dict["next_due_amount"] = line[133:].strip()
                
        elif(payment_plan_history_block and "payment plan no" not in line and "responsible participant" not in line and "on these docket sheets" not in line and "assume any liability for inaccurate" not in line and "docket sheet information should" not in line and "who does not comply" not in line and "liability as set forth" not in line and "cpcms" not in line and "payment plan history:" not in line and line.strip() != ""):
            payment_nr += 1
            payment_idx = "payment_nr_" + str(payment_nr)
            payment_plan_dict[payment_idx] = {}

            payment_plan_dict[payment_idx]["receipt_date"] = line[:82].strip()
            payment_plan_dict[payment_idx]["payor_name"] = line[82:110].strip()
            payment_plan_dict[payment_idx]["participant_role"] = line[110:132].strip()
            payment_plan_dict[payment_idx]["amount_paid"] = line[132:].strip()

        i += 1
    
    return(payment_plan_dict)

def extract_all(pdf_path: str) -> dict[str, str | dict]:
    # Join together all pages and lines into one string.
    text = extract_text_from_pdf(pdf_path)

    # Partition the text by sections.
    sections = extract_sections(text)

    case_info = (
        extract_case_information(sections.get("CASE INFORMATION", ""))
        if "CASE INFORMATION" in sections
        else None
    )

    defendant_info = (
        # The second argument in get() is the default value returned if the key is not found in the dictionary.
        extract_defendant_information(sections.get("DEFENDANT INFORMATION", ""))
        if "DEFENDANT INFORMATION" in sections
        else None
    )
    
    charges = (
        extract_charges(sections.get("CHARGES", ""))
        if "CHARGES" in sections
        else None
    )

    sentencing = (
        extract_sentencing(sections.get("DISPOSITION SENTENCING/PENALTIES", ""))
        if "DISPOSITION SENTENCING/PENALTIES" in sections
        else None
    )

    confinement = (
        extract_confinement(sections.get("CONFINEMENT INFORMATION", ""))
        if "CONFINEMENT INFORMATION" in sections
        else None
    )

    status_info = (
        extract_status(sections.get("STATUS INFORMATION", ""))
        if "STATUS INFORMATION" in sections
        else None
    )

    calendar_events = (
        extract_calendar_events(sections.get("CALENDAR EVENTS", ""))
        if "CALENDAR EVENTS" in sections
        else None
    )

    participants = (
        extract_case_participants(sections.get("CASE PARTICIPANTS", ""))
        if "CASE PARTICIPANTS" in sections
        else None
    )

    attorneys = (
        extract_attorney_info(sections.get("ATTORNEY INFORMATION", ""))
        if "ATTORNEY INFORMATION" in sections
        else None
    )

    bail = (
        extract_bail(sections.get("BAIL", ""))
        if "BAIL" in sections
        else None
    )

    case_financial_info = (
        extract_case_financial_info(sections.get("CASE FINANCIAL INFORMATION", ""))
        if "CASE FINANCIAL INFORMATION" in sections
        else None
    )

    payment_plan_summary = (
        extract_payment_plan_summary(sections.get("PAYMENT PLAN SUMMARY", ""))
        if "PAYMENT PLAN SUMMARY" in sections
        else None
    )

    related_cases = (
        extract_related_cases(sections.get("RELATED CASES", ""))
        if "RELATED CASES" in sections
        else None
    )

    return(
        {
            "case_info": case_info,
            "related_cases": related_cases,
            "status_info": status_info,
            "calendar_events": calendar_events,
            "confinement": confinement,
            "defendant_info": defendant_info,
            "participants": participants,
            "bail": bail,
            "charges": charges,
            "sentencing": sentencing,
            "attorneys": attorneys,
            "payment_plan_summary": payment_plan_summary,
            "case_financial_info": case_financial_info            
        }
    )