import os
import sys
import pandas as pd
import numpy as np
from dotenv import load_dotenv, dotenv_values
from zenrows import ZenRowsClient
import requests
from multiprocessing.pool import ThreadPool
import threading

# Intialize lock on threads.
csv_writer_lock = threading.Lock()

# Initialize paths.
csv_path = "/home/joe/Documents/secret_lives_pa/output/pdf_download_list/"
pdf_path = "/home/joe/Documents/secret_lives_pa/output/pdf_download_list/pdfs/"

# Intialize names for files.
arguments = sys.argv
pdf_log_file = arguments[1]
download_links_file = "pdf_download_links.csv"

# Read in the download links.
cases_df = pd.read_csv(
        csv_path + download_links_file,
        dtype = {"file_name": str, "link": str, "successfully_scraped": bool}
    )

# Only keep links/cases which have not been scraped yet.
cases_df = cases_df[cases_df["successfully_scraped"] == False]

# Load API key.
load_dotenv()
apikey = os.getenv("ZENROWS_API_KEY")

# Download a PDF.
def download_pdf(file_name, url, key = apikey):

    # Request PDF using ZenRows API to avoid being blocked.
    response = requests.get(
        "https://api.zenrows.com/v1/",
        params = {
            "url": url,
            "apikey": key
        }
    )

    # Save PDF.
    with open(pdf_path + file_name, 'wb') as f:
        f.write(response.content)

    # Return status code (in case request failed).
    return(response.status_code)

# Visit a URL, download the PDF, record the status code, write to log file.
def visit_url(file_name, url):

    # Download the PDF for the docket.
    print("Downloading file: " + file_name)
    print("url: " + url)
    status_code = download_pdf(file_name, url)
    print("Status code: " + str(status_code) + "\n")

    # Convert results of download into a Pandas data frame.
    print("Saving results")
    result = {
        "file_name": [file_name],
        "link": [url],
        "status_code": [status_code]
    }
    df = pd.DataFrame(result)

    # Save results to .csv (using the lock so it is thread safe).
    with csv_writer_lock:
        df.to_csv(csv_path + pdf_log_file, index = False, mode = "a", header = False)
    print("Saved results\n")

# Start downloading the PDFs.
nr_workers = arguments[2]
pool = ThreadPool(nr_workers)
results = pool.starmap(visit_url, zip(cases_df["file_name"], cases_df["link"]))
pool.close()
pool.join()