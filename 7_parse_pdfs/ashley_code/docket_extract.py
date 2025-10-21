import re
import json

import pandas as pd
import pdfplumber


# Collection  of values for several columns that might need to be updated for additional, rarer instances
# CALENDAR EVENTS
possible_events = [
    "Preliminary Hearing",
    "Plea Court",
    "Parole Hearing",
    "Formal Arraignment",
    "Status Conference",
    "Status",
    "Trial",
    "Bail Revocation",
    "Bail Hearing",
    "Preliminary Arraignment",
]
partial_events = ["Preliminary", "Plea", "Parole", "Formal", "Status", "Bail"]
possible_statuses = ["Scheduled", "Completed", "Continued", "Cancelled", "Moved"]

# DOCKET ENTRY INFORMATION
possible_entries = [
    "Waiver of Counsel",
    "Waived for Court",
    "Case Transferred to Court of Common",
    "Guilty Plea",
    "Waiver of Preliminary Hearing",
    "Commitment Printed - Unable to Post Bail",
    "Criminal Complaint Filed",
    "Release of Prisoner",
    "First Class Summons Issued",
    "First Class Summons Accepted",
    "Summons Issued",
    "Summons Accepted",
    "Certified Summons Issued",
    "Certified Summons Accepted",
    "Docket Transcript Printed",
    "Court of Common Please Review For",
    "Move to Non-Traffic Case",
    "Move to Non-Traffic",
    "Fingerprint Ordered",
    "Fingerprint order Issues",
    "Disposition Cancelled",
    "Commitment Cancelled" # AR added
]
# ATTORNEY INFORMATION section
attorney_titles = [
    "District Attorney",
    "Private",
    "Public Defender",
    "Assistant District Attorney",
    "Court Appointed",
]

# DISPOSITION/SENTENCING DETAILS section
possible_sentencing_events = [
    "ARD - County Open",
    "Guilty Plea",
    "Guilty Plea (Lower Court)",
    "Guilty Plea- Negotiated",
    "Lower Court Proceeding (generic)",
    "Move to Non-Traffic",
    "Proceed to Court",
    "Proceed to Court (Arraignment Waived)",
    "Waived for Court",
    "Waived for Court (Lower Court)"
]
possible_sentencing_events = sorted(possible_sentencing_events, key=len, reverse=True)

possible_sentences = [
    "Confinement",
    "No Further Penalty",
    "Probation",
    "ARD",
    "ARD - DUI"
]

# Begin Parser
def extract_text_from_pdf(pdf_path) -> str:
    """Extracts text from a PDF file."""
    pages = pdfplumber.open(pdf_path).pages
    alltext = "\n".join(
        [page.extract_text(keep_blank_chars=True, layout=True) for page in pages]
    )

    return alltext


def extract_sections(text) -> dict[str, str]:
    """Extracts sections from the document text.

    Args:
        text (str): The text of the document.

    Returns:
        dict: A dictionary containing the extracted sections with the section headers as keys.
    """
    # Regular expression to find section headers
    section_header_pattern = re.compile(r"^\s*[A-Z\s\/\-]{4,}\s*$", re.MULTILINE)

    # Find all section headers
    headers = [
        (match.start(), match.group().strip())
        for match in section_header_pattern.finditer(text)
    ]
    headers = [h for h in headers if len(h[1])]

    # Dictionary to store sections
    sections = {}

    # Iterate over headers and extract sections
    for i in range(len(headers)):
        start_index = headers[i][0]
        header = headers[i][1]
        end_index = headers[i + 1][0] if i + 1 < len(headers) else len(text)

        # Extract section text
        section_text = text[start_index:end_index].strip()

        # Remove the header from the section text
        section_text = section_text[len(header) :].strip()

        # Reduce different versions of the same header to a single version
        if "ATTORNEY INFORMATION" in header:
            header = "ATTORNEY INFORMATION"
        elif "BAIL INFORMATION" in header:
            header = "BAIL"

        # Add to dictionary
        sections.setdefault(header, "")
        sections[header] += f"\n{section_text}"

    return sections


def extract_defendant_information(text: str) -> dict[str, str | None]:
    """Extracts the defendant's information from the DEFENDANT INFORMATION section.

    Args:
        text (str): The text containing the defendant's information.

    Returns:
        dict: A dictionary containing the extracted information with the following keys:
        - "dob" (str or None): The date of birth of the defendant.
        - "race" (str or None): The race of the defendant.
        - "sex" (str or None): The sex of the defendant.
        - "address" (str or None: The addresss of the defendant.
        - "counsel_advised" (str or None): Whether the defendant was advised of their right to apply for assignment of counsel.
        - "defender_requested" (str or None): Whether the defendant requested a public defender.
        - "application_provided" (str or None): Whether an application was provided for the appointment of a public defender.
        - "was_fingerprinted" (str or None): Whether the defendant has been fingerprinted.
    """
    # Define regular expressions to extract the required information
    dob_pattern = r"Date of Birth:\s*([\d/]+)"
    race_pattern = r"Race:\s*(\w+)"
    sex_pattern = r"Sex:\s*(\w+)"
    address_pattern = r"City\/State\/Zip:\s*(([A-Za-z\s]+),\s*([A-Za-z]{2})\s*(\d{5}))" 
    counsel_pattern = (
        r"Advised of His Right to Apply for Assignment of Counsel\?\s*(\w+)"
    )
    defender_requested_pattern = r"Public Defender Requested by the Defendant\?\s*(\w+)"
    application_provided_pattern = (
        r"Application Provided for Appointment of Public Defender\?\s*(\w+)"
    )
    fingerprinted_pattern = r"Has the Defendant Been Fingerprinted\?\s*(\w+)"

    # Extract the information using the regular expressions
    dob_match = re.search(dob_pattern, text, re.IGNORECASE)
    race_match = re.search(race_pattern, text, re.IGNORECASE)
    sex_match = re.search(sex_pattern, text, re.IGNORECASE)
    address_match = re.search(address_pattern, text, re.IGNORECASE)
    counsel_match = re.search(counsel_pattern, text, re.IGNORECASE)
    defender_requested_match = re.search(
        defender_requested_pattern, text, re.IGNORECASE
    )
    application_provided_match = re.search(
        application_provided_pattern, text, re.IGNORECASE
    )
    fingerprinted_match = re.search(fingerprinted_pattern, text, re.IGNORECASE)

    # Get the matched groups
    dob = dob_match.group(1) if dob_match else None
    race = race_match.group(1) if race_match else None
    sex = sex_match.group(1) if sex_match else None
    address = address_match.group(1) if address_match else None
    counsel = counsel_match.group(1) if counsel_match else None
    defender_requested = (
        defender_requested_match.group(1) if defender_requested_match else None
    )
    application_provided = (
        application_provided_match.group(1) if application_provided_match else None
    )
    fingerprinted = fingerprinted_match.group(1) if fingerprinted_match else None

    # Store the extracted information in a dictionary
    extracted_info = {
        "dob": dob,
        "race": race,
        "sex": sex,
        "address": address,
        "counsel_advised": counsel,
        "defender_requested": defender_requested,
        "application_provided": application_provided,
        "was_fingerprinted": fingerprinted,
    }
    # Print the extracted information
    extracted_info 
        
    return extracted_info



def extract_case_information(text: str) -> dict[str, str | None]:
    """Extracts information from the CASE INFORMATION section.

    Args:
        text (str): The text containing case information.

    Returns:
        dict: A dictionary containing the extracted information with the following keys:
        - "judge" (str or None): The name of the judge 
        - "otn" (str or None): The offender tracking number
        - "initial_authority" (str or None): The initial issuing authority
        - "arresting_agency" (str or None): The agency that performed the arrest
        - "complaint_citation_no" (str or None): The complaint AND/OR citation number
        - "file_date" (str or None): The date when the charges were filed
        - "initiation_date" (str or None): The date when the complaint was initiated
        - "issue_date" (str or None): The date when an order was issued by the court
        - "originating_docket_no" (str or None): The original docket number for linking dockets
        - "otn" (str or None): The offense tracking number.
        - "lotn" (str or None): The local offense tracking number
        - "final_authority" (str or None): The final issuing authority
        - "arresting_officer" (str or None): The officer who performed the arrest
        - "incident_no" (str or None): The incident number
        - "township" (str or None): The township in which the arrest occurred
        
    """
    # Define regular expressions to extract the required information
    # otn_pattern = r"OTN(?:/LOTN)?:\s*([a-zA-Z]\s*[A-Z0-9\-]+)(?:/[a-zA-Z]\s*[A-Z0-9\-]+)?"
    judge_assigned_pattern = r"Judge\s*Assigned:\s*([A-Za-z ,.'\-]+)(?=\s+Date Filed|$)"
    intitial_authority_pattern = r"Initial\s*Issuing\s*Authority:\s*([A-Za-z ,.'\-]+)(?=\s+Final Issuing Authority|$)"
    arresting_agency_pattern = r"Arresting Agency:\s*([A-Za-z ]+)(?=\s+Arresting Officer|$)"
    complaint_citation_no_pattern = r"Complaint(?:/Citation)? No\.\s*:\s*([A-Z0-9\-]+)"
    file_date_pattern = r"Date Filed:\s*([\d/]+)"
    initiation_date_pattern = r"Initiation Date:\s*([\d/]+)"
    issue_date_pattern = r"Issue Date:\s*([\d/]+)"
    originating_docket_no_pattern = r"Originating\s*Docket\s*No:\s*([A-Z0-9\-]+)"
    otn_pattern = r"OTN:\s*([A-Za-z]\s*[0-9]+-[0-9])"
    lotn_pattern = r"LOTN:\s*([A-Za-z]\s*[0-9]+-[0-9])"
    final_authority_pattern = r"Final\s*Issuing\s*Authority:\s*([A-Za-z ,.'\-]+)"
    arresting_officer_pattern = r"Arresting\s*Officer:\s*([A-Za-z ,.'\-]+)"
    incident_no_pattern = r"Incident\s*(?:Number)?(?:No\.)?:\s*([A-Z0-9\-]+)(?=\s+County|$)"
    township_pattern = r"Township:\s*([A-Za-z ]+)" 
    
    # Extract the information using the regular expressions
    # otn_match = re.search(otn_pattern, text, re.IGNORECASE)
    judge_assigned_match = re.search(judge_assigned_pattern, text, re.IGNORECASE)
    initial_authority_match = re.search(intitial_authority_pattern, text, re.IGNORECASE)
    arresting_agency_match = re.search(arresting_agency_pattern, text, re.IGNORECASE)
    complaint_citation_no_match = re.search(complaint_citation_no_pattern, text, re.IGNORECASE)
    file_date_match = re.search(file_date_pattern, text, re.IGNORECASE)
    initiation_date_match = re.search(initiation_date_pattern, text, re.IGNORECASE)
    issue_date_match = re.search(issue_date_pattern, text, re.IGNORECASE)
    originating_docket_no_match = re.search(originating_docket_no_pattern, text, re.IGNORECASE)
    otn_match = re.search(otn_pattern, text, re.IGNORECASE)
    lotn_match = re.search(lotn_pattern, text, re.IGNORECASE)
    final_authority_match = re.search(final_authority_pattern, text, re.IGNORECASE)
    arresting_officer_match = re.search(arresting_officer_pattern, text, re.IGNORECASE)
    incident_no_match = re.search(incident_no_pattern, text, re.IGNORECASE)
    township_match = re.search(township_pattern, text, re.IGNORECASE)
    
    # Get the matched groups
    # otn = otn_match.group(1) if otn_match else None
    judge_assigned = judge_assigned_match.group(1) if judge_assigned_match else None
    initial_authority = initial_authority_match.group(1) if initial_authority_match else None
    arresting_agency = arresting_agency_match.group(1).strip() if arresting_agency_match else None
    complaint_citation_no = complaint_citation_no_match.group(1) if complaint_citation_no_match else None
    file_date = file_date_match.group(1) if file_date_match else None
    initiation_date = initiation_date_match.group(1) if initiation_date_match else None
    issue_date = issue_date_match.group(1) if issue_date_match else None
    originating_docket_no = originating_docket_no_match.group(1) if originating_docket_no_match else None
    otn = otn_match.group(1) if otn_match else None
    lotn = lotn_match.group(1) if lotn_match else None
    final_authority = final_authority_match.group(1) if final_authority_match else None
    arresting_officer = arresting_officer_match.group(1).strip() if arresting_officer_match else None
    incident_no = incident_no_match.group(1) if incident_no_match else None
    township = township_match.group(1).strip() if township_match else None
    
    # Store the extracted information in a dictionary
    extracted_case_info = {
        "judge_assigned": judge_assigned,
        "initial_authority": initial_authority,
        "arresting_agency": arresting_agency,
        "complaint_citation_no": complaint_citation_no,
        "file_date": file_date,
        "initiation_date": initiation_date,
        "issue_date": issue_date,
        "originating_docket_no": originating_docket_no,
        "otn": otn, 
        "lotn": lotn,
        "final_authority": final_authority,
        "arresting_officer": arresting_officer,
        "incident_no": incident_no,
        "township": township
    }
    # Print the extracted information
    extracted_case_info 
        
    return extracted_case_info
    
    

def extract_charges_MC(text: str) -> dict:
    """Extracts the charges from the CHARGES section for PDFs with _MC_ or _CP- in name.
    Args:
        text (str): The text containing charge information.

    Returns:
        dict: A dictionary containing the extracted information with the following keys:
        - "seq" (str or None): The sequence of the charge within a judicial proceeding
        - "orig_seq" (str or None): The original sequence of the charge within a judicial proceeding
        - "grade" (str or None): The offense grade to indicate the severity of the charge
        - "statute" (str or None): The statute violated
        - "statute_description" (str or None): The description of the statute violated
        - "offense_date" (str or None): The date when the offense occurred
        - "OTN" (str or None): The offense tracking number
    
    """
    pattern = re.compile(
        r"(?P<seq>\d+)\s+(?P<orig_seq>\d+)\s+(?P<grade>\w*)\s+(?P<statute>\d+\s§\s\d+(?:\s§§\s\w*\**)?|\d+\s§\s\d+)\s+(?P<statute_description>.+?)\s+(?P<offense_date>\d{2}/\d{2}/\d{4})\s+(?P<OTN>\w+\s\d+-\d+)",
        re.MULTILINE,
    )
    matches = pattern.findall(text)
    return pd.DataFrame(
        matches,
        columns=[
            "seq",
            "orig_seq",
            "grade",
            "statute",
            "statute_description",
            "offense_date",
            "OTN",
        ],
    ).to_dict(orient="records")


def extract_sentencing_disposition(text: str) -> dict:
    """Extracts sentencing decisions from the DISPOSITION SENTENCING/PENALTIES section.
    Args:
        text (str): The text containing disposition information for sentencing and penalties.

    Returns:
        dict: A dictionary containing the extracted information with the following keys:
        - "seq" (str or None): The sequence of the charge within a judicial proceeding
        - "description" (str or None): The description of the offense
        - "disposition" (str or None): The disposition for the given offense
        - "grade" (str or None): The offense grade to indicate the severity of the charge
        - "statute" (str or None): The statute violated
        - "sentencing_judge" (str or None): The judge who issued the sentence
        - "sentence_date" (str or None): The date when the sentence was issued
        - "credit_time_served" (str or None): Any number of days that the defendant has already served for their sentence
    
    """
    disposition = []
    current_disposition = None
    current_charge = None

    def line_starts_disposition(line):
    # Matches if line begins with a known disposition keyword
        return any(line.startswith(keyword) for keyword in possible_sentencing_events)

    def get_disposition(line):
        return next((kw for kw in possible_sentencing_events if line.startswith(kw)), None)

    def get_presence(line):
        if "Defendant Was Present" in line:
            return "Defendant Was Present"
        if "Defendant Was Not Present" in line:
            return "Defendant Was Not Present"
        return None

    def get_event_type(line):
        date_match = re.search(r"\d{2}/\d{2}/\d{4}", line)
        if date_match:
            return line[:date_match.start()].strip()
        return None

    def get_date(line):
        match = re.search(r"\d{2}/\d{2}/\d{4}", line)
        return match.group() if match else None

    def get_final_status(line):
        if "Final Disposition" in line:
            return "Final"
        elif "Not Final" in line:
            return "Not Final"
        return None

    def is_charge_line(line):
        return re.match(r"^\d+\s*/", line) is not None

    def is_judge_line(line):
        return re.match(r"^[A-Z][a-z]+, [A-Z][a-z]+", line) is not None

    def extract_judge(line):
        return line.strip()

    def extract_judge_date(line):
        match = re.search(r"\d{2}/\d{2}/\d{4}", line)
        return match.group() if match else None
    
    def is_condition_line(line):
        return (
            line.startswith("That")
            or "Pay" in line
            or "Costs" in line
            or "Defendant is" in line
            or "Recieve" in line
        )


    lines = text.splitlines()
    for line in lines:
        line = line.strip()
        if not line:
            continue

        # --- Start of new disposition ---
        if line_starts_disposition(line):
            if current_disposition:
                disposition.append(current_disposition)
            current_disposition = {
                "disposition": get_disposition(line),
                "defendant_presence": get_presence(line),
                "event_information": {
                    "event_type": get_event_type(line),
                    "disposition_date": get_date(line),
                    "final_disposition": get_final_status(line),
                    "charges": []
                }
            }
            current_charge = None
            continue

        # --- Charge line ---
        if is_charge_line(line):
            parts = line.split()
            seq = parts[0]

            # Look for event keyword inside this charge line
            event_in_charge = next((kw for kw in possible_sentencing_events if kw in line), None)

            # Detect grade (F, F1, M, M1, S, etc.)
            grade_idx = None
            for i, token in enumerate(parts):
                if re.match(r"^[FSM]\d?$", token):  # F3, M1, S, etc.
                    grade_idx = i
                    break

            description = None
            offense_disposition = None
            grade = None
            statute = None

            if grade_idx and grade_idx >= 2:
                if event_in_charge:
                    before, after = line.split(event_in_charge, 1)
                    description = before.split("/", 1)[-1].strip()
                    grade = parts[grade_idx]
                    statute = " ".join(parts[grade_idx + 1:]).strip()
                    offense_disposition = event_in_charge.strip()
                else:
                    description = " ".join(parts[2:grade_idx])
                    grade = parts[grade_idx]
                    statute = " ".join(parts[grade_idx + 1:]).strip()
            else:
                description = " ".join(parts[2:])
                offense_disposition = event_in_charge

            charge = {
                "seq": seq,
                "description": description.strip() if description else None,
                "offense_disposition": offense_disposition,
                "grade": grade,
                "statute": statute,
                "sentencing_judge": None,
                "sentence_date": None,
                "sentences": [],
                "conditions": []
            }

            current_disposition["event_information"]["charges"].append(charge)
            current_charge = charge
            continue

        # --- Sentencing judge ---
        if is_judge_line(line) and current_charge:
            current_charge["sentencing_judge"] = extract_judge(line)
            current_charge["sentence_date"] = extract_judge_date(line)
            continue

        # --- Sentence line ---
        if any(word in line for word in possible_sentences) and current_charge:
            parts = line.split()

            # Sentence type
            sentence_in_charge = next((kw for kw in possible_sentences if kw in line), None)

            # Sentence length
            sentence_length = None
            for token in parts:
                match = re.match(r"(\d+(?:\.\d{2})?)\s*(Months?|Days?)", token)
                if match:
                    sentence_length = match.group()
                    break

            # Sentence date
            sentence_date = next((t for t in parts if re.match(r"\d{2}/\d{2}/\d{4}", t)), None)

            current_charge["sentences"].append({
                "sentence": sentence_in_charge,
                "sentence_length": sentence_length,
                "sentence_date": sentence_date
            })
            continue

        # --- Condition line ---
        if is_condition_line(line) and current_charge:
            current_charge["conditions"].append(line.strip())
            continue

    # --- Add last disposition ---
    if current_disposition:
        disposition.append(current_disposition)

    return pd.DataFrame(disposition).to_dict(orient="records")




def extract_confinement(text: str) -> dict:
    """Extracts confinement information from the CONFINEMENT INFORMATION section.
    Args:
        text (str): The text containing confinement information.
    Returns:
        dict: A dictionary containing the extracted information with the following keys:
        - "seq" (str or None): The sequence of the charge within a judicial proceeding
        - "orig_seq" (str or None): The original sequence of the charge within a judicial proceeding
        - "grade" (str or None): The offense grade to indicate the severity of the charge
        - "statute" (str or None): The statute violated
        - "statute_description" (str or None): The description of the offense
        - "offense_date" (str or None): The date when the offense occurred
        - "OTN" (str or None): The offense tracking number. 
        
    """
    pattern = re.compile(
        r"(?P<seq>\d+)\s+(?P<orig_seq>\d+)\s+(?P<grade>\w*)\s+(?P<statute>\d+\s§\s\d+(?:\s§§\s\w*\**)?|\d+\s§\s\d+)\s+(?P<statute_description>.+?)\s+(?P<offense_date>\d{2}/\d{2}/\d{4})\s+(?P<OTN>\w+\s\d+-\d+)",
        re.MULTILINE,
    )
    matches = pattern.findall(text)
    return pd.DataFrame(
        matches,
        columns=[
            "Confinement Known As Of",
            "Confinement Type",
            "Destination Location",
            "Confinement Reason",
            "Still in Custody",
        ],
    ).to_dict(orient="records")


def extract_status_information(text: str) -> tuple[str | None, dict]:
    """Extract the case status from the STATUS INFORMATION section

    Args:
        text (str): The section containing the case status information.

    Returns:
        tuple: A tuple containing the case status and a DataFrame with the status information.
    """
    case_status_pattern = r"Case Status\s*:\s*(\w+)|Case Status\s+(\w+)"
    case_status_match = re.search(case_status_pattern, text)
    if case_status_match:
        case_status = (
            case_status_match.group(1)
            if case_status_match.group(1)
            else case_status_match.group(2)
        )
    else:
        case_status = None
    if case_status == "Status":
        case_status = text.split("\n")[1].strip().split()[0]

    arrest_date_pattern = r"Arrest Date\s*:\s*(\d{2}/\d{2}/\d{4})"
    arrest_date_match = re.search(arrest_date_pattern, text)
    if arrest_date_match:
        arrest_date = arrest_date_match.group(1)
    else:
        arrest_date = None

    # Remove the case status line from the text
    text = re.sub(case_status_pattern, "", text)
    if arrest_date:
        text = re.sub(arrest_date, "", text)

    # Extract the status date and processing status
    status_pattern = r"(\d{2}/\d{2}/\d{4})\s+(.+)"
    status_matches = re.findall(status_pattern, text)

    # Create a DataFrame
    status_df = pd.DataFrame(
        status_matches, columns=["status_date", "processing_status"]
    )
    status_df["processing_status"] = status_df["processing_status"].str.strip()

    return case_status, arrest_date, status_df.to_dict(orient="records")


def extract_calendar_events(text: str) -> dict:
    """
    Extracts calendar events from the CALENDAR EVENTS section.

    Args:
        text (str): The text containing the calendar events.

    Returns:
        dict: A DataFrame containing the extracted events with the following columns:
        - "event_type" (str): The type of the event.
        - "start_datetime" (str): The start date and time of the event.
        - "room" (str): The room where the event is scheduled.
        - "judge" (str): The judge assigned to the event.
        - "status" (str): The status of the event.
    """
    # Split the text into lines
    lines = text.split("\n")

    # Define a pattern to match datetime
    datetime_pattern = re.compile(r"\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}\s*(AM|PM|am|pm)")

    # Find lines that contain a datetime and keep their indices
    datetime_indices = [
        i for i, line in enumerate(lines) if datetime_pattern.search(line)
    ]

    # Create a list of start_datetimes
    start_datetimes = [
        datetime_pattern.search(lines[i]).group() for i in datetime_indices
    ]
    # Remove the datetime from lines that contain them
    for i in datetime_indices:
        lines[i] = datetime_pattern.sub("", lines[i])

    # Initialize a list to store event types
    event_types = []

    # Search for event types in lines noted in datetime_indices
    for i in datetime_indices:
        event_type = next(
            (event for event in possible_events + partial_events if event in lines[i]),
            None,
        )
        if event_type:
            lines[i] = lines[i].replace(event_type, "").strip()
        if event_type in partial_events and i + 1 < len(lines) and lines[i + 1].strip():
            continuation = lines[i + 1].strip().split()[0].strip()
            if event_type + " " + continuation in possible_events:
                event_type = event_type + " " + continuation
            lines[i + 1] = lines[i + 1].replace(continuation, "").strip()
        event_types.append(event_type)

    # Initialize a list to store statuses
    statuses = []

    # Search for statuses in lines noted in datetime_indices
    for i in datetime_indices:
        status = next((stat for stat in possible_statuses if stat in lines[i]), None)
        statuses.append(status)
        if status:
            lines[i] = lines[i].replace(status, "").strip()

    # Initialize a list to store rooms
    rooms = []

    # Define a pattern to match room
    room_pattern = re.compile(r"(\b\d+\b|\b[A-Z]\d+\b|Courtroom: \w+-\d+-\d+)")

    # Search for rooms in lines noted in datetime_indices
    for i in datetime_indices:
        room_match = room_pattern.search(lines[i])
        room = room_match.group() if room_match else None
        rooms.append(room)
        if room:
            lines[i] = lines[i].replace(room, "").strip()

    # Initialize a list to store judges
    judges = []
    # Search for judges in lines noted in datetime_indices
    for i in datetime_indices:
        judge = lines[i].strip()
        if i + 1 < len(lines) and lines[i + 1].strip():
            cline = lines[i + 1].strip()
            if len(cline.split()) <= 3:
                judge += " " + cline
        judges.append(judge if judge else None)
    # Initialize an empty DataFrame
    events_df = pd.DataFrame(
        list(zip(start_datetimes, event_types, rooms, judges, statuses)),
        columns=["start_datetime", "event_type", "room", "judge", "status"],
    )

    return events_df.to_dict(orient="records")


def extract_case_participants(text) -> dict:
    """Extracts the case participants from the CASE PARTICIPANTS section."""
    text = text.strip().split("\n")
    roles, names = [], []
    for line in text[1:]:
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            role, name = parts
            roles.append(role.strip())
            names.append(name.strip())
    return pd.DataFrame({"role": roles, "name": names}).to_dict(orient="records")


def extract_docket_entry(text: str, defendant_name: str) -> dict:
    """Extracts the docket entries from the DOCKET ENTRY INFORMATION section.

    Args:
        text (str): The text containing the docket entry information.
        defendant_name (str): The name of the defendant.

    Returns:
        dict: A DataFrame containing the extracted docket entries with the following columns:
        - "date" (str): The date of the entry.
        - "entry" (str): The type of the entry.
        - "applies_to" (str): The party to which the entry applies.
        - "filer" (str): The party who filed the entry.
    """
    lines = text.strip().split("\n")[1:]
    if "," in defendant_name:
        defendant_name = (
            f"{defendant_name.split(',')[1]} {defendant_name.split(',')[0]}".strip()
        )
    def_string = f"{defendant_name}, Defendant"
    applies_to, dates, entries, filers = [], [], [], []
    for line in lines:
        line = line.strip()
        if len(line.split()) < 5:
            continue
        if line.endswith(def_string):
            applies_to.append(def_string)
            line = line.replace(def_string, "").strip()
        else:
            applies_to.append("")
        date_match = re.search(r"\d{2}/\d{2}/\d{4}", line)
        if date_match:
            dates.append(date_match.group())
            line = line.replace(date_match.group(), "").strip()
        else:
            dates.append("")
        for entry in possible_entries:
            if entry in line:
                entries.append(entry)
                line = line.replace(entry, "").strip()
                break
        else:
            entries.append("")
        filers.append(line)
    return pd.DataFrame(
        {"date": dates, "entry": entries, "applies_to": applies_to, "filer": filers}
    ).to_dict(orient="records")


def extract_entries(text: str) -> dict:
    """Alternative docket entry format in "ENTRIES" sections.
    
    Returns:
        dict: Containing the extracted docket entries with the following columns:
        - "filed_date" (str)
        - "document_date" (str)
        - "filed_by" (str)
        - "entry_text" (str)
    """
    if not text:
        return []
    
    pattern = r"(\d+)\s+(\d{2}/\d{2}/\d{4})\s+(\d{2}/\d{2}/\d{4})?\s+(.*?)\n\s+(.*?)\n\s+(.*?)\n"
    matches = re.findall(pattern, text, re.DOTALL)
    cp_filed_dates = []
    document_dates = []
    names = []
    second_rows = []
    third_rows = []
    for match in matches:
        _, cp_filed_date, document_date, name, second_row, third_row = match
        cp_filed_dates.append(cp_filed_date)
        document_dates.append(document_date)
        names.append(name)
        second_rows.append(second_row)
        third_rows.append(third_row)
    entry_texts = []

    # Third row if second row is a continuation of the name
    # which happens in some cases - if not the third row will be next entry and have a date
    # Might be brittle?
    for i, (rowa, rowb) in enumerate(zip(second_rows, third_rows)):
        date_pattern = re.compile(r"\d{2}/\d{2}/\d{4}")
        if not date_pattern.search(rowb):
            names[i] = names[i].strip() + " " + rowa.strip()
            entry_texts.append(rowb.strip())
        else:
            names[i] = names[i].strip()
            entry_texts.append(rowa.strip())

    return pd.DataFrame(
        {
            "filed_date": cp_filed_dates,
            "document_date": document_dates,
            "filed_by": names,
            "entry_text": entry_texts,
        }
    ).to_dict(orient="records")


def extract_attorney_information(text: str) -> dict:
    """Extracts the attorney information from ATTORNEY INFORMATION section."""
    if not text.strip():
        return []
    lines = [line.strip() for line in text.strip().split("\n") if line.strip()]
    if not lines:
        return []
    titles = []
    names = []
    stop_mark = -1
    while True:
        for title in attorney_titles:
            if lines[0].startswith(title):
                titles.append(title)
                lines[0] = lines[0][len(title) :].strip()
                stop_mark = -1
                break
        if not len(lines[0]):
            break
        if stop_mark >= 1:
            if len(lines[0].split("Name:")) == 0:
                raise ValueError(f"Unknown attorney title in {lines[0]}")
            else:
                names = [
                    name.strip()
                    for name in lines[0].split("Name:")
                    if len(name.strip())
                ]
                for title in attorney_titles:
                    if lines[1].startswith(title):
                        titles.append(title)
                        lines[1] = lines[1][len(title) :].strip()
                if len(titles) < len(names):
                    titles += [""] * (len(names) - len(titles))
                break
        stop_mark += 1
    if len(lines) == 1:
        return pd.DataFrame({"title": titles, "name": [""] * len(titles)})
    if not len(names):
        names = [name.strip() for name in lines[1].split("Name:") if len(name.strip())]
    if len(titles) != len(names):
        print(f"[WARNING] Mismatch: titles={len(titles)}, names={len(names)}")
    max_len = max(len(titles), len(names))
    titles += [""] * (max_len - len(titles))
    names += [""] * (max_len - len(names))
    return pd.DataFrame({"title": titles, "name": names}).to_dict(orient="records")


def extract_bail(text: str) -> dict[str, str]:
    """Extracts the bail information from the BAIL section."""
    lines = text.strip().split("\n")
    bail_set_pattern = re.compile(r"Bail Set:\s+Nebbia Status:\s*(\w+)") 
    action_pattern = re.compile(
        r"(Set|Revoke and Forfeit|Change Bail Type)\s+(\d{2}/\d{2}/\d{4})\s+(\w+)\s+(.+?)\s+(\$[\d,\.]+|\d+\.\d+%?\s*\$[\d,\.]+|\$0\.00)"
    )
    surety_pattern = re.compile(
        r"(Self|Other)\s*([A-Za-z ,.'\-]+)\s*(Posted|Not Posted)\s*(\d{2}/\d{2}/\d{4})\s*([A-Za-z ]+?)\s+\$(\d{1,3}(?:,\d{3})*\.\d{2})"
    )

    nebbia_status = None
    actions = []
    surety = []

    for line in lines:
        bail_set_match = bail_set_pattern.search(line)
        if bail_set_match:
            nebbia_status = bail_set_match.group(1)
        action_match = action_pattern.search(line)
        if action_match:
            action_type = action_match.group(1)
            action_date = action_match.group(2)
            bail_type = action_match.group(3)
            originating_court = action_match.group(4).strip()
            amount = action_match.group(5).strip()
            actions.append(
                {
                    "action_type": action_type,
                    "action_date": action_date,
                    "bail_type": bail_type,
                    "originating_court": originating_court,
                    "amount": amount,
                }
            )
        surety_match = surety_pattern.search(line)
        if surety_match:
            surety_type = surety_match.group(1)
            surety_name = surety_match.group(2)
            surety_posting_status = surety_match.group(3)
            surety_posting_date = surety_match.group(4)
            surety_security_type = surety_match.group(5)
            surety_security_amount = surety_match.group(6)
            surety.append(
                {
                    "surety_type": surety_type,
                    "surety_name": surety_name,
                    "surety_posting_status": surety_posting_status,
                    "surety_posting_date": surety_posting_date,
                    "surety_security_type": surety_security_type,
                    "surety_security_amount": surety_security_amount,
                }
            )


    return {"nebbia_status": nebbia_status, "actions": actions, "surety": surety}


def extract_payment_plan_summary(text: str) -> dict:
    """Extract payment plan header, and line items

    Returns:
        dict: Containing the extracted payment plan summary with the following columns:
        - "payment_plan_freq" (str)
        - "next_due_date" (str)
        - "active" (str)
        - "overdue_amt" (float)
        - "suspended" (str)
        - "next_due_amt" (float)
        - "payment_plan_lines" (str)
        where payment_plan_lines are
        - "date" (str)
        - "name" (str)
        - "amount" (float)
    """
    pattern = re.compile(
        r"Payment Plan No\s+Payment Plan Freq\.\s+Next Due Date\s+Active\s+Overdue Amt\s+\n" + \
        r"\s+Responsible Participant\s+Suspended\s+Next Due Amt\n" + \
        r"\s+\d+-\d+-\w\d+\s+(?P<payment_plan_freq>\w+)\s+(?P<next_due_date>\d{2}/\d{2}/\d{4})\s+(?P<active>(Yes|No))\s+\$(?P<overdue_amt>[\d,]+\.\d{2})\s+\n" + \
        r"[\s\w,]+(?P<suspended>(Yes|No))\s+\$(?P<next_due_amt>[\d,]+\.\d{2})"
    )

    match = pattern.search(text)
    if match:
        payment_plan_freq = match.group("payment_plan_freq")
        next_due_date = match.group("next_due_date")
        active = match.group("active")
        overdue_amt = float(match.group("overdue_amt").replace(",", ""))
        suspended = match.group("suspended")
        next_due_amt = float(match.group("next_due_amt").replace(",", ""))
    pattern_payment_lines = re.compile(
    r"(?P<date>\d{2}/\d{2}/\d{4})\s+Payment(?:\s+(?P<name>.*?))\s+\$(?P<amount>[\d,]+\.\d{2})"
    )
    lines = text.splitlines()
    dates, names, vals = [], [], []
    for line in lines:
        match_payment = pattern_payment_lines.search(line)
        if match_payment:
            dates.append(match_payment.group("date"))
            name_val = match_payment.group("name") if match_payment.group("name") else ""
            names.append(name_val)
            vals.append(float(match_payment.group("amount").replace(",", "")))

    return {
        "payment_plan_freq": payment_plan_freq,
        "next_due_date": next_due_date,
        "active": active,
        "overdue_amt": overdue_amt,
        "suspended": suspended,
        "next_due_amt": next_due_amt,
        "payment_plan_lines": pd.DataFrame(
            {"date": dates, "name": names, "amount": vals}
            ).to_dict(orient="records")
    }

def extract_case_financial_info(text:str) -> dict: # AR: What I am currently working on 
    """ Extract case financial information, and line items
    
    Returns:
        dict: Containing the extracted case financial information with the following columns:
        - "costs_fees" (str)
        - "assessment" (float)
        - "payments" (float)
        - "adjustments" (float)
        - "non-monetary_payments" (float)
        - "balance" (float)
        
    """
    pattern = re.compile(
    )

def extract_all(pdf_path: str) -> dict[str, str | dict]:
    """Extracts all relevant information from a PDF file."""
    text = extract_text_from_pdf(pdf_path)
    sections = extract_sections(text)
    defendant_info = (
        extract_defendant_information(sections.get("DEFENDANT INFORMATION", ""))
        if "DEFENDANT INFORMATION" in sections
        else None
    )
    extracted_case_info = (
        extract_case_information(sections.get("CASE INFORMATION", ""))
        if "CASE INFORMATION" in sections
        else None
    )
    case_status, arrest_date, status_info = (
        extract_status_information(sections.get("STATUS INFORMATION", ""))
        if "STATUS INFORMATION" in sections
        else (None, None, None)
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
    docket_entries = (
        extract_docket_entry(
            sections.get("DOCKET ENTRY INFORMATION", ""), defendant_info["name"]
        )
        if "DOCKET ENTRY INFORMATION" in sections and defendant_info.get("name")
        else extract_entries(sections.get("ENTRIES") if "ENTRIES" in sections else None)
    )
    attorney_info = (
        extract_attorney_information(sections.get("ATTORNEY INFORMATION", ""))
        if "ATTORNEY INFORMATION" in sections
        else None
    )
    bail_info = (
        extract_bail(sections.get("BAIL", "")) 
        if "BAIL" in sections 
        else None
    )
    charges = (
        extract_charges_MC(sections.get("CHARGES", ""))
        if "CHARGES" in sections
        else None
    )
    sentencing = (
        extract_sentencing_disposition(sections.get("DISPOSITION SENTENCING/PENALTIES", ""))
        if "DISPOSITION SENTENCING/PENALTIES" in sections
        else None
    )
    payment_plan_summary = (
        extract_payment_plan_summary(sections.get("PAYMENT PLAN SUMMARY", ""))
        if "PAYMENT PLAN SUMMARY" in sections
        else None
    )
    return {
        "defendant_info": defendant_info,
        "extracted_case info": extracted_case_info,
        "case_status": case_status,
        "arrest_date": arrest_date,
        "status_info": status_info,
        "calendar_events": calendar_events,
        "case_participants": case_participants,
        "docket_entries": docket_entries,
        "attorney_info": attorney_info,
        "bail_info": bail_info,
        "charges": charges,
        "sentencing": sentencing,
        "payment_plan_summary": payment_plan_summary,
    }


    
