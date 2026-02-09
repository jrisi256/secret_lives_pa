#!/bin/bash

# Target directory.
TARGET_DIR="$1"

echo "Starting to move PDFs to $TARGET_DIR..."

# Find all .pdf files in subdirectories and move them to the current directory.
# -type f: looks for files
# -iname: case-insensitive search for ".pdf"
# -not -path "./.": skips files already in the root to avoid "same file" errors
# {} + tells the script to operate in batch mode.
find "$TARGET_DIR" -mindepth 2 -type f -iname "*.pdf" -exec mv -t "$TARGET_DIR" {} +

echo "Done! All PDFs have been moved to the main directory."