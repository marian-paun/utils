#!/bin/sh

DB_PATH="/volume1/home/emby/data/playback_reporting.db"
MQTT_TOPIC="homeassistant/sensor/Media_Stats"

JSON_PAYLOAD=$(/opt/bin/sqlite3 "$DB_PATH" <<EOF
SELECT json_object(
    'PlayMinutes', CAST(MIN(MAX(ROUND(SUM(MIN(pa.PlayDuration, bi.RunTimeTicks)) / 600000000.0, 0), 0), 60) AS INTEGER)
)
FROM PlaybackActivity pa
JOIN BaseItem bi ON pa.ItemId = bi.Id
WHERE DateCreated >= datetime('now', '-60 minutes');
EOF
)

/opt/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "${JSON_PAYLOAD}"
echo "$JSON_PAYLOAD"
