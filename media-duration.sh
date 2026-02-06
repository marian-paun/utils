#! /bin/sh

function duration () {
  # Try to determine number of CPUs, default to 2 if unable
  num_cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)

  /usr/bin/find "$1" -type f -regex '.*\.\(mkv\|avi\|mp4\|mov\|mp3\|m4a\|m4b\|opus\)$' -print0 |
  /usr/bin/xargs -0 -n1 -P "$num_cores" sh -c '
    duration=$(/opt/bin/ffprobe -v quiet -of csv=p=0 -show_entries format=duration "$1")
    if [ -n "$duration" ]; then
        printf "%.0f\n" "$duration"
    fi
  ' sh |
  awk '{sum += $1} END {printf "%.2f\n", sum/3600}'
  }

output=$(
echo "{"
echo "  \"Soundtracks\": $(duration /volume1/Audio/Music/Soundtrack),"
echo "  \"Movies\": $(duration /volume1/Video/Ready/Movies),"
echo "  \"TV\": $(duration /volume1/Video/Ready/TV),"
echo "  \"Training\": $(duration /volume1/Video/Ready/Training),"
echo "  \"Documentaries\": $(duration /volume1/Video/Ready/Documentaries),"
echo "  \"Soundtracks\": $(duration /volume1/Audio/Music/Soundtrack),"
echo "  \"Classical\": $(duration /volume1/Audio/Music/Classical),"
echo "  \"Various\": $(duration /volume1/Audio/Music/Various),"
echo "  \"Audiobooks\": $(duration /volume1/Audio/Audiobooks),"
echo "  \"Podcasts\": $(duration /volume1/Audio/podcast)"
echo "}";
)

echo $output
/opt/bin/mosquitto_pub -h oramicro1.alpine-blues.ts.net -t "homeassistant/sensor/Astor/Media/Duration" -m "$output"
