# Run this file to quickly process a single docket PDF file
# Run as python process_pdf.py <fname.pdf>
# The output will be on screen, and in a file <fname.json>

import json
import os
import sys
import pathlib

sys.path.append(str(pathlib.Path(__file__).parent.parent))

from docket_extract import extract_all


def main(fname: str) -> None:
    if not fname.lower().endswith(".pdf"):
        raise ValueError("File must be a PDF file")
    if  not os.path.exists(fname):
        raise FileNotFoundError("File does not exist")
    extract = extract_all(fname)
    print(extract)
    filename = "test.json"
    with open(filename, "w") as json_file:
	json.dump(extract, filename, indent = 4)   
   # with open(fname.replace(".pdf", ".json"), "w") as f:
   #     f.write(json.dumps(extract, indent=4))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise ValueError("Usage: python process_pdf.py <fname.pdf>")

    main(sys.argv[1])