#!/bin/sh

# Configuration
DB_PATH="/volume1/home/emby/data/playback_reporting.db"
MQTT_TOPIC="homeassistant/sensor/Astor/Emby_Stats"

JSON_PAYLOAD=$(/opt/bin/sqlite3 "$DB_PATH" <<EOF
#SELECT json_group_array(
#  json_object(
#    'type', ItemType,
#    'play_minutes', ROUND(CAST(PlayDuration AS REAL) / 60.0, 2),
#    'pause_minutes', ROUND(CAST(PauseDuration AS REAL) / 60.0, 2)
#  )
#)
#FROM (
#  SELECT ItemType, SUM(PlayDuration) as PlayDuration, SUM(PauseDuration) as PauseDuration
#  FROM PlaybackActivity
#  WHERE DateCreated >= datetime('now', '-1 hour')
#  GROUP BY ItemType
#);

WITH ItemTypes(it) AS (VALUES ('Video'), ('Audio'), ('Episode'), ('Movie')),
Stats AS (
    SELECT 
        it.it,
        SUM(p.PlayDuration) / 60.0 AS play_min,
        SUM(p.PauseDuration) / 60.0 AS pause_min
    FROM ItemTypes it
    LEFT JOIN PlaybackActivity p ON 
        p.ItemType = it.it AND 
        p.DateCreated >= datetime('now', '-60 minutes')
    GROUP BY it.it
)
SELECT json_group_object(
    it,
    json_object(
        'PlayMinutes', play_min,
        'PauseMinutes', pause_min
    )
) AS last_hour_stats
FROM Stats;
EOF
)
#        COALESCE(SUM(p.PlayDuration) / 60.0, 0) AS play_min,
#        COALESCE(SUM(p.PauseDuration) / 60.0, 0) AS pause_min

/opt/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "${JSON_PAYLOAD}"
echo $JSON_PAYLOAD
