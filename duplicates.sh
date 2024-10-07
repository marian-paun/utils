#!/bin/bash

# specify the folder to search for duplicates in
folder=$1

# create an associative array to store files by size and inode number
declare -A files

# loop through each file and add it to the array
while IFS= read -r -d '' file; do
  key=$(stat -c%s -- "$file")_$(stat -c%i -- "$file")
  files[$key]+="$file"$'\0'
done < <(find "$folder" -type f -print0)

# loop through each array element and compare the files
for key in "${!files[@]}"; do
  # split the array element into files with the same size and inode number
  readarray -d '' files_arr <<< "${files[$key]}"
  n=${#files_arr[@]}
  if [ $n -gt 1 ]; then
    # compare each pair of files
    for ((i=0; i<n-1; i++)); do
      for ((j=i+1; j<n; j++)); do
        # print the names of the duplicate files
        printf "Duplicate files found: %s and %s
" "${files_arr[$i]}" "${files_arr[$j]}"
      done
    done
  fi
done
