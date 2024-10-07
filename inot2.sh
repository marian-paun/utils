#!/bin/bash

# Define the directory to watch
watch_dir="/mnt/Astor.Audio/Music/Soundtrack/playing/"
source_dir="/mnt/Astor.Audio/Music/Soundtrack/"

# Define the action to perform (replace this with your actual command)
action_cmd="echo 'A file was deleted!'"

# Use inotifywait to monitor the directory for deletions
while inotifywait -e delete --monitor "$watch_dir"; do
  # Execute the defined action
  echo $(ls -t "$sourcedir" | tail -1);
#  mv "$sourcedir$action2";
done
