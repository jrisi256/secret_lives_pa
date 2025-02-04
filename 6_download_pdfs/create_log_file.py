import os
import sys
import pandas as pd
import numpy as np

# Initialize paths.
csv_path = "/home/joe/Documents/secret_lives_pa/output/pdf_download_list/"

# Intialize names for files.
arguments = sys.argv
pdf_log_file_old = arguments[1]
pdf_log_file_new = arguments[2]
download_links_file = "pdf_download_links.csv"
criminal_cases_file = "criminal_pdf_links.csv.gz"
lt_cases_file = "lt_pdf_links.csv.gz"

# If the old log file does not exist, create an empty log file and read initial starting links.
if(not os.path.exists(csv_path + pdf_log_file_old)):

    # Create empty log file.
    csv_log_df = pd.DataFrame({"file_name": [], "link": [], "status_code":[]})
    csv_log_df.to_csv(csv_path + pdf_log_file_old, index = False)

    # Read in criminal cases.
    criminal_cases_df = pd.read_csv(
        csv_path + criminal_cases_file,
        compression = "gzip",
        dtype = {"file_name": str, "link": str, "successfully_scraped": bool}
    )
    
    # Read in landlord-tenant cases.
    lt_cases_df = pd.read_csv(
        csv_path + lt_cases_file,
        compression = "gzip",
        dtype = {"file_name": str, "link": str, "successfully_scraped": bool}
    )

    # Combine cases.
    cases_df = pd.concat([criminal_cases_df, lt_cases_df], axis = 0)
    cases_df.to_csv(csv_path + download_links_file, index = False)

# If the log file does exist, read in the log file and existing links.
else:
    csv_log_df = pd.read_csv(
        csv_path + pdf_log_file_old,
        dtype = {"file_name": str, "link": str, "status_code": float}
    )

    cases_df = pd.read_csv(
        csv_path + download_links_file,
        dtype = {"file_name": str, "link": str, "successfully_scraped": bool}
    )

# If it's not an empty log file, update our links using the results of the old log file, and create the new log file.
if(len(csv_log_df) != 0):

    # Update download links.
    merged_df = pd.merge(cases_df, csv_log_df, on = ["file_name", "link"], how = "outer")
    merged_df = merged_df.assign(successfully_scraped = np.where(merged_df["status_code"] == 200, True, merged_df["successfully_scraped"]))
    merged_df = merged_df.drop(columns = ["status_code"])
    merged_df.to_csv(csv_path + download_links_file, index = False)

    # Create new empty log file.
    csv_log_df_new = pd.DataFrame({"file_name": [], "link": [], "status_code":[]})
    csv_log_df_new.to_csv(csv_path + pdf_log_file_new, index = False)
