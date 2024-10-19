import json

import pdfplumber


import re
import json
from collections import defaultdict

def extract_text_from_pdf(pdf_path):
    pages = pdfplumber.open(pdf_path).pages
    alltext = "\n".join([page.extract_text(keep_blank_chars=True, layout=True) for page in pages])

    return alltext

def extract_sections(text):
    # Regular expression to find section headers
    section_header_pattern = re.compile(r'^\s*[A-Z\s\/\-]{4,}\s*$', re.MULTILINE)
    
    # Find all section headers
    headers = [(match.start(), match.group().strip()) for match in section_header_pattern.finditer(text)]
    
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
        section_text = section_text[len(header):].strip()
        
        # Add to dictionary
        sections[header] = section_text
    
    return sections