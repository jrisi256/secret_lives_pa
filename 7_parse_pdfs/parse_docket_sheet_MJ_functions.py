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
    # We also need to drop RRRI, CJES, and JCPS as headers. This can show as a punishment condition.
    headers = [h for h in headers if len(h[1]) > 3 and h[1] != "RRRI" and h[1] != "CJES" and h[1] != "JCPS"]

    standard_headers = [
        "DEFENDANT INFORMATION", "CASE INFORMATION", "STATUS INFORMATION", "CALENDAR EVENTS", "CASE PARTICIPANTS", "CHARGES",
        "DISPOSITION / SENTENCING DETAILS", "ATTORNEY INFORMATION", "DOCKET ENTRY INFORMATION", "BAIL", "CONFINEMENT",
        "CASE FINANCIAL INFORMATION", "PAYMENT PLAN SUMMARY", "DOCKET"
    ]

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

        # Sometimes, the description for a charge in CHARGES will be all capitalized, and it will take up multiple lines.
        # Meaning to the parser, it looks like a new section header. We need to fix that.
        # If the header is not in our standard list of headers AND the prior header is CHARGES, then the header is not really a header.
        if(header not in standard_headers and headers[i - 1][1] == "CHARGES"):
            header = "CHARGES"
        else:
            # Remove the header from the section text.
            section_text = section_text[len(header):].strip()

        # The BAIL section header does not carry over to new pages. To capture the info which overflows onto the next page, set the DOCKET header to the previous substantive header (i.e., BAIL).
        # And then remove the junk from the top of the docket header.
        if re.search("^DOCKET$", header) and "BAIL" in headers[i - 1][1] and i - 2 > 0:
            header = headers[i - 1][1]
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
    split = [line for line in split if line.strip() != ""]
    extracted_info = {}
    i = 0

    # Defendant information follows a straightforward pattern.
    # In MJ dockets, the following pattern holds:
    #   Line 1 is name and sex.
    #   Line 2 is DOB and race.
    #   Line 4 is type of address for each address (e.g., Home, Mailing, Other)
    #   Line 5 is the addresses.
    #   Line 6 is if the defendant has been advised of their right to apply for assignment of counsel.
    #   Line 7 is if the defendant requested a public defender.
    #   Line 8 is if an application has been provided for the appointment of a public defender.
    #   Line 9 is if the defendant has been finger printed.
    while(i < len(split)):
        line = split[i].lower().strip()

        if("name:" in line or "sex:" in line):
            extracted_info["name"] = line.split("name:")[1].split("sex:")[0].strip()
            extracted_info["sex"] = line.split("name:")[1].split("sex:")[1].strip()
            i += 1
        elif("date of birth:" and "race:" in line):
            extracted_info["dob"] = line.split("date of birth:")[1].split("race:")[0].strip()
            extracted_info["race"] = line.split("date of birth:")[1].split("race:")[1].strip()
            i += 1
        elif("address(es):" in line):
            if("advised of his right to apply for assignment of counsel?" in split[i + 1].lower()):
                extracted_info["address_type"] = ""
            else:
                extracted_info["address_type"] = split[i + 1].split()

            if("public defender requested by the defendant?" in split[i + 2].lower()):
                extracted_info["address"] = ""
            else:
                extracted_info["address"] = re.split("\s{2,}", split[i + 2].strip().lower())
            i += 3
        elif("advised of his right to apply for assignment of counsel?" in line):
            extracted_info["counsel"] = line.split("advised of his right to apply for assignment of counsel?")[1].strip()
            i += 1
        elif("public defender requested by the defendant?" in line):
            extracted_info["defender_requested"] = line.split("public defender requested by the defendant?")[1].strip()
            i += 1
        elif("application provided for appointment of public defender?" in line):
            extracted_info["application_provided"] = line.split("application provided for appointment of public defender?")[1].strip()
            i += 1
        elif("has the defendant been fingerprinted?" in line):
            extracted_info["fingerprinted"] = line.split("has the defendant been fingerprinted?")[1].strip()
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
    # In MJ dockets:
    #   Line 1 is judge assigned (optional and potentially multiple lines) issue date.
    #   Line 2 is OTN (or OTN/LOTN) and file date.
    #   Line 3 is arresting agency and arrest date.
    #   Line 4 is complaint number (or document number) and incident number.
    #   Line 5 is disposition and disposition date.
    #   Line 6 is county and township.
    #   Line 7 is case status.
    while(i < len(split)):
        line = split[i].lower().strip()
        
        if("issue date:" in line):
            extracted_info["issue_date"] = line.split("issue date:")[1].strip()
            j = 1

            if("judge assigned" in line):
                extracted_info["judge_assigned"] = line.split("judge assigned:")[1].split("issue date:")[0].strip()
                
                # Check the next line if the judge's name takes up multiple lines.
                while("otn" not in split[i + j].lower() and "file date" not in split[i + j].lower() and "otn/lotn" not in split[i + j]):
                    lookahead_line = split[i + j].lower().strip()
                    extracted_info["judge_assigned"] = extracted_info["judge_assigned"] + " " + lookahead_line
                    j += 1

            i += 1 + (j - 1)
        elif("file date:" in line):
            if(re.search("^otn:", line)):
                extracted_info["otn"] = line.split("otn:")[1].split("file date:")[0].strip()
                extracted_info["file_date"] = line.split("otn:")[1].split("file date:")[1].strip()
            elif("otn/lotn:" in line):
                extracted_info["otn_lotn"] = line.split("otn/lotn:")[1].split("file date:")[0].strip()
                extracted_info["file_date"] = line.split("otn/lotn:")[1].split("file date:")[1].strip()
            i += 1
        elif("arresting agency:" in line or "arrest date:" in line):
            extracted_info["arresting_agency"] = line.split("arresting agency:")[1].split("arrest date:")[0].strip()
            extracted_info["arrest_date"] = line.split("arresting agency:")[1].split("arrest date:")[1].strip()
            i += 1
        elif("complaint no.:" in line or "incident no.:" in line):
            if("complaint no.:" in line):
                extracted_info["complaint_nr"] = line.split("complaint no.:")[1].split("incident no.:")[0].strip()
                extracted_info["incident_nr"] = line.split("complaint no.:")[1].split("incident no.:")[1].strip()
            elif("document no.:" in line):
                extracted_info["document_nr"] = line.split("document no.:")[1].split("incident no.:")[0].strip()
                extracted_info["incident_nr"] = line.split("document no.:")[1].split("incident no.:")[1].strip()
            i += 1
        elif("disposition:" in line or "disposition date:" in line):
            extracted_info["disposition"] = line.split("disposition:")[1].split("disposition date:")[0].strip()
            extracted_info["disposition_date"] = line.split("disposition:")[1].split("disposition date:")[1].strip()
            i += 1
        elif("county:" in line or "township:" in line):
            extracted_info["county"] = line.split("county:")[1].split("township:")[0].strip()
            extracted_info["township"] = line.split("county:")[1].split("township:")[1].strip()
            i += 1
        elif("case status:" in line):
            extracted_info["case_status"] = line.split("case status:")[1].strip()
            i += 1
        # Junk line. Keep moving.
        else:
            i += 1
                
    return extracted_info

# Extracts status information from the STATUS INFORMATION section.
# Args:
#   text(str): The text containing the status information.
# Return:
#   dict: A dictionary containing the status information.
def extract_status_information(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0
    status_nr = -1
    status_idx = "status_nr_" + str(status_nr)

    while(i < len(split)):
        line = split[i].lower()
        
        # If it's not a header row, the end of the document, or an empty line, then it is a status information row.
        if("case status" not in line and "status date" not in line and "processing status" not in line and "printed:" not in line and "recent entries made" not in line and "administrative office of penn" not in line and "docket sheet information should" not in line and "comply with the provi" not in line and "set forth in 18" not in line and "district judge" not in line and line.strip() != ""):
            status_nr += 1
            status_idx = "status_nr_" + str(status_nr)
            extracted_info[status_idx] = {}
            extracted_info[status_idx]["case_status"] = line[:35].strip()
            extracted_info[status_idx]["status_date"] = line[35:56].strip()
            extracted_info[status_idx]["processing_status"] = line[56:].strip()
        
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
        if(re.search(r"\d{2}/\d{2}/\d{4}", line) and "printed:" not in line):
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
        elif("case calendar" not in line and "event type" not in line and "printed:" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply" not in line and "set forth" not in line and line.strip() != ""):
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
        if("participant type" not in line and "printed:" not in line and "recent entries" not in line and "administrative" not in line and "docket sheet" not in line and "comply with the" not in line and "set forth in" not in line and "magisterial district judge" not in line and line != ""):
            participant_nr += 1
            participant_idx = "participant_nr_" + str(participant_nr)
            extracted_info[participant_idx] = {}

            extracted_info[participant_idx]["participant_type"] = line[:45].strip()
            extracted_info[participant_idx]["name"] = line[45:].strip()
        
        i += 1
    
    return(extracted_info)

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
        line = split[i].lower()

        # Skip blank lines, column header line, and junk lines.
        if("offense dt." in line or line.strip() == "" or "reflected on these docket sheets" in line or "inaccurate or delayed data" in line or "docket sheet information should" in line or "not comply with the" in line or "liability as set forth" in line or "printed:" in line or "magisterial district judge" in line):
            i += 1
        # The § character indicates a new charge.
        elif("§" in line):
            charge_nr += 1
            charge_nr_idx = "charge_nr_" + str(charge_nr)
            extracted_info[charge_nr_idx] = {}

            # Each charge adheres to the following pattern.
            extracted_info[charge_nr_idx]["nr"] = line[:17].strip()
            extracted_info[charge_nr_idx]["charge"] = line[17:45].strip()
            extracted_info[charge_nr_idx]["grade"] = line[45:53].strip()
            extracted_info[charge_nr_idx]["description"] = line[53:108].strip()
            extracted_info[charge_nr_idx]["offense_date"] = line[108:121].strip()
            extracted_info[charge_nr_idx]["disposition"] = line[121:].strip()
            i += 1
        # If the line is not a header line, a blank line, a new charge, or a junk line, then it is the description from the previous charge overflowing onto a new line.
        else:
            extracted_info[charge_nr_idx]["description"] = extracted_info[charge_nr_idx]["description"] + " " + line.strip()
            i += 1
    
    return(extracted_info)

# Extracts the disposition / sentencing details from the DISPOSITION / SENTENCING DETAILS section.
# Args:
#   text(str): The text containing the disposition and sentencing details.
# Return:
#   dict: A dictionary containing the extracted information.
def extract_disp_sent(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    i = 0
    disposition_block = False
    offense_block = False
    penalty_block = False

    # Offense block.
    offense_nr = -1
    offense_nr_idx = "offense_nr_" + str(offense_nr)
    
    # Penalty block.
    penalty_nr = -1
    penalty_nr_idx = "penalty_nr_" + str(penalty_nr)

    while(i < len(split)):
        line = split[i].lower()

        if("case disposition" in line):
            disposition_block = True
            offense_block = False
            penalty_block = False
        elif("offense disposition" in line):
            offense_block = True
            disposition_block = False
            penalty_block = False
        elif("penalty type" in line):
            penalty_block = True
            disposition_block = False
            offense_block = False

        # As long as we are not on a column header, a junk line, or the end of the page, we are in the disposition block.
        if("condition text:" in line):
            extracted_info["condition_text"] = line.split("condition text:")[1].strip()
        elif(disposition_block and "case disposition" not in line and line.strip() != "" and "reflected on these" not in line and "inaccurate or delayed" not in line and "docket sheet info" not in line and "not comply with" not in line and "liability as set" not in line and "printed:" not in line and "magisterial district judge" not in line):
            extracted_info["case_disposition"] = line[:69].strip()
            extracted_info["disposition_date"] = line[69:103].strip()
            extracted_info["defendant_present"] = line[103:].strip()
        # As long as we are not on a column header, a junk line, or the end of the page, we are in the offense block.
        elif(offense_block and "offense disposition" not in line and line.strip() != "" and "reflected on these" not in line and "inaccurate or delayed" not in line and "docket sheet info" not in line and "not comply with" not in line and "liability as set" not in line and "printed:" not in line and "magisterial district judge" not in line):
            # If we find a number, that is the offense sequence number. It is a new offense.
            if(re.search("[0-9]+", line)):
                offense_nr += 1
                offense_nr_idx = "offense_nr_" + str(offense_nr)
                extracted_info[offense_nr_idx] = {}

                extracted_info[offense_nr_idx]["offense_seq"] = line[:14].strip()
                extracted_info[offense_nr_idx]["description"] = line[14:80].strip()
                extracted_info[offense_nr_idx]["offense_disposition"] = line[80:].strip()
            # If we do not find a number, but we are still in the offense block, the description must have overflowed onto a new line.
            else:
                extracted_info[offense_nr_idx]["description"] = extracted_info[offense_nr_idx]["description"] + " " + line.strip()
        # As long as we are not on a column header, a junk line, or the end of the page, we are in the offense block.
        elif(penalty_block and "penalty type" not in line and line.strip() != "" and "reflected on these" not in line and "inaccurate or delayed" not in line and "docket sheet info" not in line and "not comply with" not in line and "liability as set" not in line and "printed:" not in line and "magisterial district judge" not in line):
            penalty_nr += 1
            penalty_nr_idx = "penalty_nr_" + str(penalty_nr)
            extracted_info[penalty_nr_idx] = {}

            extracted_info[penalty_nr_idx]["penalty_type"] = line[:41].strip()
            extracted_info[penalty_nr_idx]["penalty_date"] = line[41:58].strip()
            extracted_info[penalty_nr_idx]["program_type"] = line[58:83].strip()
            extracted_info[penalty_nr_idx]["start_date"] = line[83:97].strip()
            extracted_info[penalty_nr_idx]["end_date"] = line[97:111].strip()
            extracted_info[penalty_nr_idx]["period"] = line[111:].strip()

        i += 1
    
    return(extracted_info)

# Extract attorney information from the ATTORNEY INFORMATION section.
# Args:
#   text(str): The text containing the attorney information.
# Return:
#   dict: A dictionary containing the attorney information.
def extract_attorney_info(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    i = 0
    i2 = 0

    # Split each line into two sides.
    lefthand_lines = [line[:69].strip().lower() for line in split]
    lefthand_lines_clean = [line for line in lefthand_lines if line.strip() != ""]
    righthand_lines = [line[69:].strip().lower() for line in split]
    righthand_lines_clean = [line for line in righthand_lines if line.strip() != ""]
    
    # Indices for the lawyers.
    lawyer_nr = -1
    lawyer_idx = "lawyer_nr_" + str(lawyer_nr)

    # Use this to signal we are in an address block.
    address_block = False
    
    while(i < len(lefthand_lines_clean)):
        l_line = lefthand_lines_clean[i].strip().lower()
        
        if("name:" in l_line or ""):
            # New lawyer.
            lawyer_nr += 1
            lawyer_idx = "lawyer_nr_" + str(lawyer_nr)
            extracted_info[lawyer_idx] = {}

            # Extract name and type.
            extracted_info[lawyer_idx]["name"] = l_line.split("name:")[1].strip()
            extracted_info[lawyer_idx]["type"] = lefthand_lines_clean[i - 1].strip()
        elif("representing:" in l_line):
            extracted_info[lawyer_idx]["representing"] = l_line.split("representing:")[1].strip()
        elif("counsel status:" in l_line):
            extracted_info[lawyer_idx]["counsel_status"] = l_line.split("counsel status:")[1].strip()
        elif("supreme court no.:" in l_line):
            extracted_info[lawyer_idx]["supreme_court_nr"] = l_line.split("supreme court no.:")[1].strip()
        # Some strange situations where phone number comes before name. See ds_Blair_MJ_24102_CR_0000701_2010.
        elif("phone no.:" in l_line):
            if(lawyer_idx == "lawyer_nr_-1"):
                # New lawyer.
                lawyer_nr += 1
                lawyer_idx = "lawyer_nr_" + str(lawyer_nr)
                extracted_info[lawyer_idx] = {}

            extracted_info[lawyer_idx]["phone_nr"] = l_line.split("phone no.:")[1].strip()
        elif("address:" in l_line):
            extracted_info[lawyer_idx]["address"] = l_line.split("address:")[1].strip()

            # As long as the lawyer has an address, enter the address block.
            if(extracted_info[lawyer_idx]["address"] != ""):
                address_block = True
        # As long as we are not at the end of the page or on a blank line AND we are in the address block, collect the data and add it to the address.
        elif(l_line != "" and "reflected on these docket sheets" not in l_line and "inaccurate or delayed data" not in l_line and "docket sheet information should" not in l_line and "not comply with the" not in l_line and "liability as set forth" not in l_line and "printed:" not in l_line and "magisterial district judge" not in l_line and address_block):
            extracted_info[lawyer_idx]["address"] = extracted_info[lawyer_idx]["address"] + "|" + l_line

            # If we find a the city + state + zip code, then the address is over.
            if(re.search("[A-Za-z]+,\s*[A-Za-z]{2}\s*[0-9]{5}", l_line)):
                address_block = False

        i += 1

    while(i2 < len(righthand_lines_clean)):
        r_line = righthand_lines_clean[i2].strip().lower()

        if("name:" in r_line):
            # New lawyer.
            lawyer_nr += 1
            lawyer_idx = "lawyer_nr_" + str(lawyer_nr)
            extracted_info[lawyer_idx] = {}

            # Extract name and type.
            extracted_info[lawyer_idx]["name"] = r_line.split("name:")[1].strip()
            extracted_info[lawyer_idx]["type"] = righthand_lines_clean[i2 - 1].strip()
        elif("representing:" in r_line):
            extracted_info[lawyer_idx]["representing"] = r_line.split("representing:")[1].strip()
        elif("counsel status:" in r_line):
            extracted_info[lawyer_idx]["counsel_status"] = r_line.split("counsel status:")[1].strip()
        elif("supreme court no.:" in r_line):
            extracted_info[lawyer_idx]["supreme_court_nr"] = r_line.split("supreme court no.:")[1].strip()
        elif("phone no.:" in r_line):
            extracted_info[lawyer_idx]["phone_nr"] = r_line.split("phone no.:")[1].strip()
        elif("address:" in r_line):
            extracted_info[lawyer_idx]["address"] = r_line.split("address:")[1].strip()

            # As long as the lawyer has an address, enter the address block.
            if(extracted_info[lawyer_idx]["address"] != ""):
                address_block = True
        # As long as we are not at the end of the page or on a blank line AND we are in the address block, collect the data and add it to the address.
        elif(r_line != "" and "reflected on these docket sheets" not in r_line and "inaccurate or delayed data" not in r_line and "docket sheet information should" not in r_line and "not comply with the" not in r_line and "liability as set forth" not in r_line and "printed:" not in r_line and "magisterial district judge" not in r_line and address_block):
            extracted_info[lawyer_idx]["address"] = extracted_info[lawyer_idx]["address"] + "|" + r_line

            # If we find a the city + state + zip code, then the address is over.
            if(re.search("[A-Za-z]+,\s*[A-Za-z]{2}\s*[0-9]{5}", r_line)):
                address_block = False

        i2 += 1
    
    return(extracted_info)

# Extracts docket entry information from the DOCKET ENTRY INFORMATION section.
# Args:
#   text(str): The text containing the docket entry information.
# Return:
#   dict: A dictionary containing the docket entry information.
def extract_docket_entry_information(text:str) -> dict[str, str | list]:
    split = text.split("\n")
    extracted_info = {}
    
    # Line counter.
    i = 0
    docket_entry_nr = -1
    docket_entry_idx = "docket_entry_" + str(docket_entry_nr)

    while(i < len(split)):
        line = split[i].lower()
        
        # If we find a date on the line (that is not at the end of the document), then it is a calendar event.
        if(re.search(r"\d{2}/\d{2}/\d{4}", line) and "printed:" not in line):
            docket_entry_nr += 1
            docket_entry_idx = "docket_entry_" + str(docket_entry_nr)
            extracted_info[docket_entry_idx] = {}

            extracted_info[docket_entry_idx]["filed_date"] = line[:22].strip()
            extracted_info[docket_entry_idx]["entry"] = line[22:68].strip()
            extracted_info[docket_entry_idx]["filer"] = line[68:107].strip()
            extracted_info[docket_entry_idx]["applies_to"] = line[107:].strip()

        # If we do not find a date, but it is not the end of the document nor is it the header row or an empty row, then it is an overflow row.
        elif("filed date" not in line and "applies to" not in line and "printed:" not in line and "recent entries made" not in line and "administrative office of penn" not in line and "docket sheet information should" not in line and "comply with the prov" not in line and "as set forth in" not in line and "magisterial district judge" not in line and line.strip() != ""):
            extracted_info[docket_entry_idx]["filed_date"] = extracted_info[docket_entry_idx]["filed_date"] + " " + line[:22].strip()
            extracted_info[docket_entry_idx]["entry"] = extracted_info[docket_entry_idx]["entry"] + " " + line[22:68].strip()
            extracted_info[docket_entry_idx]["filer"] = extracted_info[docket_entry_idx]["filer"] + " " + line[68:107].strip()
            extracted_info[docket_entry_idx]["applies_to"] = extracted_info[docket_entry_idx]["applies_to"] + " " + line[107:].strip()
        
        i += 1
    
    return(extracted_info)

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

    # Initialize bail depositor information.
    bail_dict["depositor_info"] = {}
    bail_depositor_block = False
    bail_depositor_nr = -1
    bail_depositor_idx = "bail_depositor_nr_" + str(bail_depositor_nr)
    
    while(i < len(split)):
        line = split[i].lower()

        if("nebbia status:" in line):
            bail_dict["nebbia_status"] = line.split("nebbia status:")[1].strip()
        elif("bail action" in line):
            bail_block = True
            surety_block = False
            bail_depositor_block = False
        elif("surety type" in line):
            surety_block = True
            bail_block = False
            bail_depositor_block = False
        elif("depositor name" in line):
            bail_depositor_block = True
            bail_block = False
            surety_block = False

        # If we are in the bail section, and we are not at the end of page nor are we on the header row or on a blank line... collect the bail data.
        if(bail_block and "printed:" not in line and "recent entries made" not in line and "administrative office of" not in line and "docket sheet info" not in line and "comply with the" not in line and "set forth in" not in line and "bail action type" not in line and "commonwealth of penn" not in line and "bail set:" not in line and "bail posted:" not in line and "bail depositor(s):" not in line and "magisterial district judge" not in line and line.strip() != ""):
            if("bail action reason:" in line):
                bail_dict["bail_info"][bail_idx]["bail_action_reason"] = line.split("bail action reason:")[1].strip()
            # If the bail date is blank, the bail action overflowed onto the next line.
            elif(line[37:60].strip() == ""):
                bail_dict["bail_info"][bail_idx]["bail_action"] = bail_dict["bail_info"][bail_idx]["bail_action"] +  " " + line[:37].strip()
                bail_dict["bail_info"][bail_idx]["bail_type"] = bail_dict["bail_info"][bail_idx]["bail_type"] + " " + line[60:85].strip()
            # Otherwise, continue collecting the bail information as normal.
            else:
                # Initialize starting values.
                bail_nr += 1
                bail_idx = "bail_nr_" + str(bail_nr)
                bail_dict["bail_info"][bail_idx] = {}

                # Set values for bail.
                bail_dict["bail_info"][bail_idx]["bail_action"] = line[:37].strip()
                bail_dict["bail_info"][bail_idx]["date"] = line[37:60].strip()
                bail_dict["bail_info"][bail_idx]["bail_type"] = line[60:85].strip()
                bail_dict["bail_info"][bail_idx]["originating_court"] = line[85:115].strip()
                bail_dict["bail_info"][bail_idx]["percentage"] = line[115:131].strip()
                bail_dict["bail_info"][bail_idx]["amount"] = line[131:].strip()
        # If we are in the surety section, and we are not at the end of page nor are we on the header row or on a blank line... collect the surety data.
        elif(surety_block and "printed:" not in line and "recent entries made" not in line and "administrative office of" not in line and "docket sheet info" not in line and "comply with the" not in line and "set forth in" not in line and "surety type" not in line and "commonwealth of penn" not in line and "bail set:" not in line and "bail posted:" not in line and "bail depositor(s):" not in line and "magisterial district judge" not in line and line.strip() != ""):
            # If the surety type is blank, the surety overflowed onto the next line.
            if(line[:37].strip() == ""):
                # This is annoying because sometimes the name flows all the way up to the security type. I am not certain there is way to distinguish them.
                bail_dict["surety_info"][surety_idx]["surety_name"] = bail_dict["surety_info"][surety_idx]["surety_name"] +  " " + line[37:100].strip()
                bail_dict["surety_info"][surety_idx]["security_type"] = bail_dict["surety_info"][surety_idx]["security_type"] +  " " + line[106:131].strip()
            # Otherwise, continue collecting the surety information as normal.
            else:
                # Initialize starting values.
                surety_nr += 1
                surety_idx = "surety_nr_" + str(surety_nr)
                bail_dict["surety_info"][surety_idx] = {}

                # Set values for surety.
                bail_dict["surety_info"][surety_idx]["surety_type"] = line[:37].strip()
                bail_dict["surety_info"][surety_idx]["surety_name"] = line[37:69].strip()
                bail_dict["surety_info"][surety_idx]["posting_status"] = line[69:89].strip()
                bail_dict["surety_info"][surety_idx]["posting_date"] = line[89:106].strip()
                bail_dict["surety_info"][surety_idx]["security_type"] = line[106:131].strip()
                bail_dict["surety_info"][surety_idx]["security_amount"] = line[131:].strip()
        # If we are in the bail depositor section, and we are not at the end of page nor are we on the header row or on a blank line... collect the depositor data.
        elif(bail_depositor_block and "printed:" not in line and "recent entries made" not in line and "administrative office of" not in line and "docket sheet info" not in line and "comply with the" not in line and "set forth in" not in line and "depositor name" not in line and "commonwealth of penn" not in line and "bail set:" not in line and "bail posted:" not in line and "bail depositor(s):" not in line and "magisterial district judge" not in line and line.strip() != ""):
            # Initialize values.
            bail_depositor_nr += 1 
            bail_depositor_idx = "bail_depositor_nr_" + str(bail_depositor_nr)
            bail_dict["depositor_info"][bail_depositor_idx] = {}

            # Set values for depositor.
            bail_dict["depositor_info"][bail_depositor_idx]["depositor_name"] = line[:65].strip()
            bail_dict["depositor_info"][bail_depositor_idx]["depositor_amount"] = line[65:].strip()

        i += 1
    
    return(bail_dict)

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
        if("confinement" not in line and "end date" not in line and "printed:" not in line and "recent entries made" not in line and "administrative office of penn" not in line and "docket sheet info" not in line and "comply with the provisions" not in line and "set forth in" not in line and "magisterial district judge" not in line and "case confinement" not in line and line != "" and re.search("\d{2}/\d{2}/\d{4}", line)):
            confinement_nr += 1
            confinement_idx = "confinement_nr_" + str(confinement_nr)
            extracted_info[confinement_idx] = {}

            extracted_info[confinement_idx]["confinement_location"] = line[:48].strip()
            extracted_info[confinement_idx]["confinement_type"] = line[48:78].strip()
            extracted_info[confinement_idx]["confinement_reason"] = line[78:117].strip()
            extracted_info[confinement_idx]["confinement_date"] = line[117:133].strip()
            extracted_info[confinement_idx]["confinement_end_date"] = line[133:].strip()
        
        i += 1

    return(extracted_info)

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
    
    while(i < len(split)):
        line = split[i].lower().strip()

        header_line1 = "assessment amt" in line or "adjustment amt" in line or "payment amt" in line or "non-monetary" in line

        if("case balance:" in line and "next payment amt:" in line):
            case_financial_dict["case_balance"] = line.split("case balance:")[1].split("next payment amt:")[0].strip()
            case_financial_dict["next payment amt"] = line.split("next payment amt")[1].strip()
        elif("last payment amt:" in line and "next payment due date:" in line):
            case_financial_dict["last_payment_amt"] = line.split("last payment amt:")[1].split("next payment due date:")[0].strip()
            case_financial_dict["next_payment_due_date"] = line.split("next payment due date:")[1].strip()
        elif("reflected on these docket" not in line and "liability for inaccurate" not in line and "docket sheet information" not in line and "who do not comply" not in line and "liability as set forth" not in line and "printed:" not in line and "magisterial district judge" not in line and line != "" and not header_line1):
            fee_nr += 1
            fee_idx = "fee_nr_" + str(fee_nr)
            case_financial_dict[fee_idx] = {}

            case_financial_dict[fee_idx]["description"] = line[:52].strip()
            case_financial_dict[fee_idx]["amount"] = line[52:73].strip()
            case_financial_dict[fee_idx]["adjusted_amount"] = line[73:94].strip()
            case_financial_dict[fee_idx]["non_monetary_amount"] = line[94:112].strip()
            case_financial_dict[fee_idx]["payment_amount"] = line[112:130].strip()
            case_financial_dict[fee_idx]["balance"] = line[130:].strip()

        i += 1
    
    return(case_financial_dict)

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
    payment_plan_participant_block = False
    payment_plan_history_block = False
    payment_nr = -1
    payment_idx = "payment_nr_" + str(payment_nr)
    
    while(i < len(split)):
        line = split[i].lower()

        if("payment plan no." in line):
            payment_plan_info_block = True
            payment_plan_participant_block = False
            payment_plan_history_block = False
        elif("responsible participant" in line):
            payment_plan_participant_block = True
            payment_plan_info_block = False
            payment_plan_history_block = False
        elif("payment plan history:" in line):
            payment_plan_history_block = True
            payment_plan_info_block = False
            payment_plan_participant_block = False

        if(payment_plan_info_block and "payment plan no." not in line and "responsible participant" not in line and "payment plan history:" not in line and "these docket" not in line and "any liability" not in line and "docket sheet info" not in line and "who do not comply" not in line and "liability as" not in line and "printed:" not in line and "magisterial district judge" not in line and line.strip() != ""):
            payment_plan_dict["payment_plan_nr"] = line[:42].strip()
            payment_plan_dict["payment_plan_freq"] = line[42:62].strip()
            payment_plan_dict["next_due_date"] = line[62:93].strip()
            payment_plan_dict["active"] = line[93:112].strip()
            payment_plan_dict["next_due_amount"] = line[112:135].strip()
            payment_plan_dict["overdue_amount"] = line[135:].strip()
        elif(payment_plan_participant_block and "payment plan no." not in line and "responsible participant" not in line and "payment plan history:" not in line and "these docket" not in line and "any liability" not in line and "docket sheet info" not in line and "who do not comply" not in line and "liability as" not in line and "printed:" not in line and "magisterial district judge" not in line and line.strip() != ""):
            payment_plan_dict["responsible_participant"] = line.strip()
        elif(payment_plan_history_block and "payment plan no." not in line and "responsible participant" not in line and "payment plan history:" not in line and "these docket" not in line and "any liability" not in line and "docket sheet info" not in line and "who do not comply" not in line and "liability as" not in line and "printed:" not in line and "magisterial district judge" not in line and line.strip() != ""):
            payment_nr += 1
            payment_idx = "payment_nr_" + str(payment_nr)
            payment_plan_dict[payment_idx] = {}

            payment_plan_dict[payment_idx]["payment_date"] = line[:42].strip()
            payment_plan_dict[payment_idx]["applied_date"] = line[42:63].strip()
            payment_plan_dict[payment_idx]["transaction_type"] = line[63:77].strip()
            payment_plan_dict[payment_idx]["payor"] = line[77:106].strip()
            payment_plan_dict[payment_idx]["participant_role"] = line[106:133].strip()
            payment_plan_dict[payment_idx]["amount"] = line[133:].strip()

        i += 1
    
    return(payment_plan_dict)

def extract_all(pdf_path: str) -> dict[str, str | dict]:
    # Join together all pages and lines into one string.
    text = extract_text_from_pdf(pdf_path)

    # Partition the text by sections.
    sections = extract_sections(text)

    defendant_info = (
        # The second argument in get() is the default value returned if the key is not found in the dictionary.
        extract_defendant_information(sections.get("DEFENDANT INFORMATION", ""))
        if "DEFENDANT INFORMATION" in sections
        else None
    )

    case_info = (
        extract_case_information(sections.get("CASE INFORMATION", ""))
        if "CASE INFORMATION" in sections
        else None
    )

    status_info = (
        extract_status_information(sections.get("STATUS INFORMATION", ""))
        if "STATUS INFORMATION" in sections
        else None
    )

    calendar_events = (
        extract_calendar_events(sections.get("CALENDAR EVENTS", ""))
        if "CALENDAR EVENTS" in sections
        else None
    )

    case_participants = (
        extract_case_participants(sections.get("CASE PARTICIPANTS", ""))
        if "CASE PARTICIPANTS" in sections
        else None
    )

    charges = (
        extract_charges(sections.get("CHARGES", ""))
        if "CHARGES" in sections
        else None
    )

    disp_sent_details = (
        extract_disp_sent(sections.get("DISPOSITION / SENTENCING DETAILS", ""))
        if "DISPOSITION / SENTENCING DETAILS" in sections
        else None
    )

    attorney_info = (
        extract_attorney_info(sections.get("ATTORNEY INFORMATION", ""))
        if "ATTORNEY INFORMATION" in sections
        else None
    )

    docket_entry_info = (
        extract_docket_entry_information(sections.get("DOCKET ENTRY INFORMATION", ""))
        if "DOCKET ENTRY INFORMATION" in sections
        else None
    )

    bail = (
        extract_bail(sections.get("BAIL", ""))
        if "BAIL" in sections
        else None
    )

    confinement = (
        extract_confinement(sections.get("CONFINEMENT", ""))
        if "CONFINEMENT" in sections
        else None
    )

    case_financial_info = (
        extract_case_financial_info(sections.get("CASE FINANCIAL INFORMATION", ""))
        if "CASE FINANCIAL INFORMATION" in sections
        else None
    )

    payment_plan = (
        extract_payment_plan_summary(sections.get("PAYMENT PLAN SUMMARY", ""))
        if "PAYMENT PLAN SUMMARY" in sections
        else None
    )

    return(
        {
            "defendant_info": defendant_info,
            "case_info": case_info,
            "status_info": status_info,
            "calendar_events": calendar_events,
            "case_participants": case_participants,
            "charges": charges,
            "disp_sent_details": disp_sent_details,
            "attorney_info": attorney_info,
            "docket_entry_info": docket_entry_info,
            "bail": bail,
            "confinement": confinement,
            "case_financial_info": case_financial_info,
            "payment_plan": payment_plan
        }
    )