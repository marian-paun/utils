#!/bin/sh

output=$( nice -n 10 
echo "{";
echo "  \"Soundtracks\": {\"size\": $(du -sm /volume1/Audio/Music/Soundtrack | cut -f1)},";
echo "  \"Classical\": {\"size\": $(du -sm /volume1/Audio/Music/Classical | cut -f1)},";
echo "  \"Various\": {\"size\": $(du -sm /volume1/Audio/Music/Various | cut -f1)},";
echo "  \"Audiobooks\": {\"size\": $(du -sm /volume1/Audio/Audiobooks | cut -f1)},";
echo "  \"Podcasts\": {\"size\": $(du -sm /volume1/Audio/podcasts | cut -f1)},";
echo "  \"Movies\": {\"size\": $(du -sm /volume1/Video/Ready/Movies | cut -f 1)},";
echo "  \"TV\": {\"size\": $(du -sm /volume1/Video/Ready/TV | cut -f 1)},";
echo "  \"Training\": {\"size\": $(du -sm /volume1/Video/Ready/Training | cut -f 1)},";
echo "  \"Documentaries\": {\"size\": $(du -sm /volume1/Video/Ready/Documentaries | cut -f 1)},";
echo "  \"Documentation\": {\"size\": $(du -sm /volume1/Media/Documentation | cut -f 1)},";
echo "  \"Magazines\": {\"size\": $(du -sm /volume1/Media/Magazines | cut -f 1)},";
echo "  \"Photo\": {\"size\": $(du -sm /volume1/PhotoGallery/ | cut -f 1)}";
echo "}";
)
#/opt/bin/mosquitto_pub -h 192.168.1.111 -t "homeassistant/sensor/Astor/Media" -m "$output"
#/opt/bin/mosquitto_pub --unix /tmp/mosquitto.sock -t "homeassistant/sensor/Astor/Media" -m "$output"
/opt/bin/mosquitto_pub -h oramicro1.alpine-blues.ts.net -t "homeassistant/sensor/Astor/Media" -m "$output"
echo $output
