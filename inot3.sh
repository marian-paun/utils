#!/bin/sh

# Define the directory to monitor for deletions
watch_dir="/volume1/Audio/Music/Soundtrack/playing"

# Define the directory containing the "backup" files
source_dir="/volume1/Audio/Music/Soundtrack"

# Function to find the oldest file
get_oldest_file() {
  local dir="$1"
  find "$dir" -type f -print0 | xargs -0 -I {} stat -c '%Y %n' {} | sort -n | head -n 1 | cut -d ' ' -f2
}

# Use inotifywait to monitor the directory
while true; do
  inotifywait -e delete "$watch_dir";
  # Find the oldest file in the source directory
  oldest_file="$(get_oldest_file "$source_dir")"
  echo "$oldest_file"

  # Check if a file was found
  if [ -z "$oldest_file" ]; then
    echo "No file found in source directory."
    continue
  fi

  # Move the oldest file to the monitored directory
#  mv "$source_dir/$oldest_file" "$watch_dir"
#  echo "Moved '$oldest_file' from source to monitored directory."
done
