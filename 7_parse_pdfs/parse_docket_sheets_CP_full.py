import re
import os
import sys
import csv
import json
import logging
import pdfplumber
import pandas as pd
from datetime import datetime
from parse_docket_sheet_CP_functions import extract_all

arguments = sys.argv

# Initialize paths and file names.
# Argument 1 is the root path of our files e.g., ~/secret_lives_pa/output/pdf_parse_list/ or /media/joe/T7 Shield/
# Argument 2 is the chunk of PDFs you want parsed e.g., Montgomery_ds_CP_CR_chunkList.csv
path_to_progress_file = arguments[1] + "progress_files/"
path_to_json = arguments[1] + "json/"
path_to_logs = arguments[1] + "log_files/"
os.makedirs(path_to_progress_file, exist_ok = True)
os.makedirs(path_to_json, exist_ok = True)
os.makedirs(path_to_logs, exist_ok = True)

target_county = arguments[2].split("_")[0]
path_to_pdfs = arguments[1] + "pdfs/" + target_county + "/"
pdfs_to_parse = arguments[1] + "pdf_chunk_lists/" + arguments[2]
progress_file = path_to_progress_file + "progress-" + arguments[2]
log_file = path_to_logs + "log_file_" + arguments[2].removesuffix(".csv") + "_" + datetime.now().strftime("%Y_%m_%d_%H_%M_%S") + ".txt"

# Configure the logger.
logging.basicConfig(filename = log_file, level = logging.INFO, filemode = "w+")

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

    try:
        result_dictionary = extract_all(path_to_pdfs + row.file_name)
        logging.info("Successfully parsed.")
    except Exception as e:
        logging.error(f"Error in parsing. The error is {e}")
        successfully_parsed_var = False
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": False, "time_stamp": timestamp}])
        progress_row.to_csv(progress_file, index = False, mode = "a", header = False)

    # Create name of JSON based on the name of the PDF we are parsing.
    filename = path_to_json + row.file_name.replace(".pdf", ".json")

    # Save dictionary as a JSON file and log successful progress in the progress file.
    if(successfully_parsed_var):
        # Log successful parsing.
        progress_row = pd.DataFrame([{"file_name": row.file_name, "successfully_parsed": True, "time_stamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}])
        progress_row.to_csv(progress_file, index = False, mode = "a", header = False)
        
        # Save results.
        with open(filename, "w") as json_file:
            json.dump(result_dictionary, json_file, indent = 4)