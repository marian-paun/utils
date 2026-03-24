#!/bin/sh

# Configuration
DB_PATH="/var/lib/jellyfin/data/playback_reporting.db"
MQTT_TOPIC="homeassistant/sensor/Rpi4/Jellyfin_Stats"


JSON_PAYLOAD=$(/usr/bin/sqlite3 "$DB_PATH" <<EOF
WITH ItemTypes(it) AS (VALUES ('Video'), ('Audio'), ('Episode'), ('Movie')),
Stats AS (
    SELECT
        it.it,
        SUM(p.PlayDuration) / 60.0 AS play_min
    FROM ItemTypes it
    LEFT JOIN PlaybackActivity p ON
        p.ItemType = it.it AND
        p.DateCreated >= datetime('now', '-60 minutes')
    GROUP BY it.it
)
SELECT json_group_object(
    it,
    json_object(
        'PlayMinutes', play_min
    )
) AS last_hour_stats
FROM Stats;
EOF
)
#        COALESCE(SUM(p.PlayDuration) / 60.0, 0) AS play_min,
#        COALESCE(SUM(p.PauseDuration) / 60.0, 0) AS pause_min

/usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "${JSON_PAYLOAD}"
echo $JSON_PAYLOAD
