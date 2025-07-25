#!/bin/bash

# Loop through all mp4 files in the current directory
cd /mnt/Astor.Video/Ready/Documentaries/history/
for file in *.mp4; do
  # Extract audio using ffmpeg
  echo "$file"
  ffmpeg -i "$file" -vn -acodec copy -c:a aac "${file%.*}.m4a" && ffmpeg -i "$file" -ss 00:00:01 -vframes 1 "${file%.*}.jpg" && \
  ffmpeg -i "${file%.*}.m4a" -i "${file%.*}.jpg" -map 0:a -map 1:v -c:a copy -c:v mjpeg -id3v2_version 3 -metadata:s:v title="Album" -metadata:s:v artist="" -metadata:s:v comment="" -metadata:s:v genre="" -metadata:s:v picture 0 -y "${file%.*}.m4a" && rm "$file"

done
