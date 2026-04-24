#!/bin/sh

DB_PATH="/var/lib/jellyfin/data/playback_reporting.db"
MQTT_TOPIC="homeassistant/sensor/Media_Stats"

JSON_PAYLOAD=$(/usr/bin/sqlite3 "$DB_PATH" "SELECT json_object('PlayMinutes', CAST(MIN(MAX(ROUND(SUM(PlayDuration) / 60.0, 0), 0), 60) AS INTEGER)) FROM PlaybackActivity WHERE DateCreated >= datetime('now', '-60 minutes')")

/usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "${JSON_PAYLOAD}"
echo "$JSON_PAYLOAD"
