#!/usr/bin/bash
set -euo pipefail
IFS=$'\n\t'

MQTT_TOPIC="homeassistant/sensor/Media_Stats"
DB_PATH="/var/lib/jellyfin/data/playback_reporting.db"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Query Jellyfin playback reporting database and output total minutes played in the last hour as JSON.

Options:
  -h, --help     Show this help
  -d, --db PATH  Database path (default: $DB_PATH)
  -w, --window DURATION  Time window (default: -1 hour, e.g. '-1 hour', '-30 minutes')

Output:
  {"PlayMinutes": 12345}
EOF
    exit 0
}

DB_PATH="${DB_PATH:-/var/lib/jellyfin/data/playback_reporting.db}"
TIME_WINDOW="${TIME_WINDOW:--1 hour}"
VERBOSE=false
OUTPUT_JSON=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -d|--db) DB_PATH="$2"; shift 2 ;;
        -w|--window) TIME_WINDOW="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ -f "$DB_PATH" ]] || { echo "Database not found: $DB_PATH" >&2; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 not found" >&2; exit 1; }

QUERY="SELECT COALESCE(SUM(PlayDuration), 0) FROM PlaybackActivity WHERE DateCreated >= datetime('now', '$TIME_WINDOW');"

TOTAL_SECONDS=$(sqlite3 "$DB_PATH" "$QUERY" 2>/dev/null || echo 0)

TOTAL_MINUTES=$((TOTAL_SECONDS / 60))

OUTPUT=$(printf '{"PlayMinutes":%d}\n' "$TOTAL_MINUTES")
mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "$OUTPUT"
echo $OUTPUT
