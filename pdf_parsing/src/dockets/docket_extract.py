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
possible_statuses = ["Scheduled", "Completed", "Continued", "Cancelled"]

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
]
# ATTORNEY INFORMATION section
attorney_titles = [
    "District Attorney",
    "Private",
    "Public Defender",
    "Assistant District Attorney",
    "Court Appointed",
]


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

        # Add to dictionary
        sections[header] = section_text

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
        - "counsel_advised" (str or None): Whether the defendant was advised of their right to apply for assignment of counsel.
        - "defender_requested" (str or None): Whether the defendant requested a public defender.
        - "application_provided" (str or None): Whether an application was provided for the appointment of a public defender.
        - "was_fingerprinted" (str or None): Whether the defendant has been fingerprinted.
    """
    # Define regular expressions to extract the required information
    dob_pattern = r"Date of Birth:\s*([\d/]+)"
    race_pattern = r"Race:\s*(\w+)"
    sex_pattern = r"Sex:\s*(\w+)"
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
        "counsel_advised": counsel,
        "defender_requested": defender_requested,
        "application_provided": application_provided,
        "was_fingerprinted": fingerprinted,
    }

    # Print the extracted information
    return extracted_info


def extract_charges_MC(text: str) -> dict:
    """Extracts the charges from the CHARGES section for PDFs with _MC_ in name."""
    pattern = re.compile(
        r"(?P<Seq>\d+)\s+(?P<Orig_Seq>\d+)\s+(?P<Grade>\w*)\s+(?P<Statute>\d+\s§\s\d+(?:\s§§\s\w*\**)?|\d+\s§\s\d+)\s+(?P<Statute_Description>.+?)\s+(?P<Offense_Dt>\d{2}/\d{2}/\d{4})\s+(?P<OTN>\w+\s\d+-\d+)",
        re.MULTILINE,
    )
    matches = pattern.findall(text)
    return pd.DataFrame(
        matches,
        columns=[
            "Seq",
            "Orig Seq",
            "Grade",
            "Statute",
            "Statute Description",
            "Offense Dt.",
            "OTN",
        ],
    ).to_json(orient="records")


def extract_charges_MJ(text: str) -> dict:
    """Extracts the charges from the CHARGES section for PDFs with _MJ_ in name."""
    pattern = re.compile(
        r"(?P<Num>\d)(?P<Charge>\d+\s§\s\d+(?:\s§§\s\w*\**)?(?:\s\w*\s*)?)\s+(?P<Grade>\w*)\s+(?P<Description>.+?)\s+(?P<Offense_Dt>\d{2}/\d{2}/\d{4})\s+(?P<Disposition>.+)",
        re.MULTILINE,
    )
    matches = pattern.findall(text)
    return pd.DataFrame(
        matches,
        columns=["#", "Charge", "Grade", "Description", "Offense Dt.", "Disposition"],
    ).to_json(orient="records")


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

    return case_status, arrest_date, status_df.to_json(orient="records")


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
        judges.append(judge)
    # Initialize an empty DataFrame
    events_df = pd.DataFrame(
        list(zip(start_datetimes, event_types, rooms, judges, statuses)),
        columns=["start_datetime", "event_type", "room", "judge", "status"],
    )

    return events_df.to_json(orient="records")


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
    return pd.DataFrame({"role": roles, "name": names}).to_json(orient="records")


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
    ).to_json(orient="records")


def extract_attorney_information(text: str) -> dict:
    """Extracts the attorney information from ATTORNEY INFORMATION section."""
    lines = [line.strip() for line in text.strip().split("\n") if line.strip()]
    titles = []
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
            raise ValueError(f"Unknown attorney title in {lines[0]}")
        stop_mark += 1
    if len(lines) == 1:
        return pd.DataFrame({"title": titles, "name": [""] * len(titles)})
    names = [name.strip() for name in lines[1].split("Name:") if len(name.strip())]
    return pd.DataFrame({"title": titles, "name": names}).to_json(orient="records") 


def extract_bail(text: str) -> dict[str, str]:
    """Extracts the bail information from the BAIL section."""
    lines = text.strip().split("\n")
    bail_set_pattern = re.compile(r"Bail Set:\s+Nebbia Status:\s*(\w+)")
    action_pattern = re.compile(
        r"(\w+)\s+(\d{2}/\d{2}/\d{4})\s+(\w+)\s+(.+?)\s+(\$[\d,\.]+|\d+\.\d+%?\s*\$[\d,\.]+|\$0\.00)"
    )

    nebbia_status = None
    actions = []

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

    return {"nebbia_status": nebbia_status, "actions": actions}


def extract_all(pdf_path: str) -> dict[str, str | dict]:
    """Extracts all relevant information from a PDF file."""
    text = extract_text_from_pdf(pdf_path)
    sections = extract_sections(text)
    defendant_info = (
        extract_defendant_information(sections.get("DEFENDANT INFORMATION", ""))
        if "DEFENDANT INFORMATION" in sections
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
        else None
    )
    attorney_info = (
        extract_attorney_information(sections.get("ATTORNEY INFORMATION", ""))
        if "ATTORNEY INFORMATION" in sections
        else None
    )
    bail_info = extract_bail(sections.get("BAIL", "")) if "BAIL" in sections else None
    if "_MC_" in pdf_path:
        charges = (
            extract_charges_MC(sections.get("CHARGES", ""))
            if "CHARGES" in sections
            else None
        )
    elif "_MJ_" in pdf_path:
        charges = (
            extract_charges_MJ(sections.get("CHARGES", ""))
            if "CHARGES" in sections
            else None
        )
    else:
        charges = None
    return {
        "defendant_info": defendant_info,
        "case_status": case_status,
        "arrest_date": arrest_date,
        "status_info": status_info,
        "calendar_events": calendar_events,
        "case_participants": case_participants,
        "docket_entries": docket_entries,
        "attorney_info": attorney_info,
        "bail_info": bail_info,
        "charges": charges,
    }
