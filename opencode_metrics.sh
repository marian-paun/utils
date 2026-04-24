#!/bin/bash

# --- Configuration ---
MQTT_TOPIC_OPENCODE="$MQTT_TOPIC_LLM"
# ---------------------

if [ ! -f "$OPENCODE_DB" ]; then
    exit 0
fi

# 1. Get Latest Session ID
latest_session_id=$(sqlite3 "$OPENCODE_DB" "SELECT id FROM session ORDER BY time_updated DESC LIMIT 1")

if [ -z "$latest_session_id" ]; then
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

#echo $output

# Publish to MQTT if broker is configured, otherwise output to stdout
if [ -n "${MQTT_BROKER}" ]; then
  /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC_OPENCODE}" -m "$output"
else
  echo "$output"
fi
