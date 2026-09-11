#!/usr/bin/env python3
import os
import unicodedata
import re
import sys

def clean_name(name):
    # Remove emojis/symbols (Unicode category 'So')
    cleaned = ''.join(c for c in name if unicodedata.category(c) != 'So')
    # Collapse multiple spaces
    cleaned = re.sub(r' +', ' ', cleaned)
    # Fix spaces before extensions
    cleaned = re.sub(r'(\s+)(\.[^.]+$)', r'\2', cleaned)
    return cleaned.strip()

def main():
    target_dir = sys.argv[1] if len(sys.argv) > 1 else '.'

    for filename in os.listdir(target_dir):
        file_path = os.path.join(target_dir, filename)

        # Skip directories
        if not os.path.isfile(file_path):
            continue

        new_name = clean_name(filename)
        if new_name == filename:
            continue  # No changes needed

        new_path = os.path.join(target_dir, new_name)
        base, ext = os.path.splitext(new_name)
        counter = 1

        # Handle duplicates
        while os.path.exists(new_path):
            new_name = f"{base}_{counter}{ext}"
            new_path = os.path.join(target_dir, new_name)
            counter += 1

        os.rename(file_path, new_path)
        print(f"Renamed: {filename} → {new_name}")

if __name__ == "__main__":
    main()