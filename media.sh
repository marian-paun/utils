#!/bin/sh

get_size() {
    du -sm $1 2>/dev/null | cut -f1 || echo "0"
}

output=$(
echo "{";
echo "  \"Soundtracks\": \"$(get_size /volume1/Audio/Music/Soundtrack)\",";
echo "  \"Classical\": \"$(get_size /volume1/Audio/Music/Classical)\",";
echo "  \"Various\": \"$(get_size /volume1/Audio/Music/Various)\",";
echo "  \"Audiobooks\": \"$(get_size /volume1/Audio/Audiobooks)\",";
echo "  \"Podcasts\": \"$(get_size /volume1/Audio/podcasts)\",";
echo "  \"Movies\": \"$(get_size /volume1/Video/Ready/Movies)\",";
echo "  \"TV\": \"$(get_size /volume1/Video/Ready/TV)\",";
echo "  \"Training\": \"$(get_size /volume1/Video/Ready/Training)\",";
echo "  \"Documentaries\": \"$(get_size /volume1/Video/Ready/Documentaries)\",";
echo "  \"Documentation\": \"$(get_size /volume1/Media/Documentation)\",";
echo "  \"Magazines\": \"$(get_size /volume1/Media/Magazines)\",";
echo "  \"Photo\": \"$(get_size /volume1/PhotoGallery)\"}";
)

/opt/bin/mosquitto_pub -h oramicro2.alpine-blues.ts.net -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "homeassistant/sensor/Astor/Media" -m "$output"
echo "$output"
