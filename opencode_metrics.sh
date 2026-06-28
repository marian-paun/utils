#!/bin/bash

# --- Configuration ---
MQTT_TOPIC_OPENCODE="$MQTT_TOPIC_LLM"
# ---------------------

if [ ! -f "$OPENCODE_DB" ]; then
    exit 0
fi

# 1. Get Latest Session ID and update time
latest_session_info=$(sqlite3 "$OPENCODE_DB" "SELECT id, time_updated FROM session ORDER BY time_updated DESC LIMIT 1")

if [ -z "$latest_session_info" ]; then
    exit 0
fi

latest_session_id=$(echo "$latest_session_info" | cut -d'|' -f1)
latest_session_time=$(echo "$latest_session_info" | cut -d'|' -f2)

if [ -z "$latest_session_id" ] || [ -z "$latest_session_time" ]; then
    exit 0
fi

# Ensure output is generated only if the last session is for the current day
if [[ ! "$latest_session_time" =~ ^[0-9]+$ ]]; then
    exit 0
fi

latest_session_sec=$((latest_session_time / 1000))
latest_session_date=$(date -d "@$latest_session_sec" +%Y-%m-%d 2>/dev/null)
current_date=$(date +%Y-%m-%d)

if [ "$latest_session_date" != "$current_date" ]; then
    exit 0
fi

# 2. Get Latest Session Metrics
latest_data=$(sqlite3 "$OPENCODE_DB" "
    SELECT 
        SUM(CAST(json_extract(data, '$.tokens.total') AS INTEGER)) as tokens,
        (MAX(time_updated) - MIN(time_created)) / 1000 as duration,
        COUNT(*) FILTER (WHERE json_extract(data, '$.role') = 'user') as requests,
        SUM(CAST(json_extract(data, '$.time.completed') AS INTEGER) - CAST(json_extract(data, '$.time.created') AS INTEGER)) / 1000.0 as agent_time
    FROM message 
    WHERE session_id = '$latest_session_id'
")

latest_tokens=$(echo "$latest_data" | cut -d'|' -f1)
latest_duration=$(echo "$latest_data" | cut -d'|' -f2)
latest_requests=$(echo "$latest_data" | cut -d'|' -f3)
agent_time=$(echo "$latest_data" | cut -d'|' -f4)

# Generate JSON output
output=$(jq -n \
  --arg lat_tok "${latest_tokens:-0}" \
  --arg lat_dur "${latest_duration:-0}" \
  --arg lat_req "${latest_requests:-0}" \
  --arg agent_time "${agent_time:-0}" \
  '{
    "LatestSessionTokens": ($lat_tok | tonumber),
    "LatestSessionDuration": ($lat_dur | tonumber),
    "LatestSessionRequests": ($lat_req | tonumber),
    "LastSessionAgentTime": ($agent_time | tonumber)
  }')

# Always output to stdout for visibility
echo "$output"

# Publish to MQTT if broker is configured
if [ -n "${MQTT_BROKER}" ]; then
  /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC_OPENCODE}" -m "$output"
fi
