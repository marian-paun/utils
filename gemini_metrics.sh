#!/bin/bash

# --- Configuration ---
GEMINI_DIR="$HOME/.gemini"
MQTT_TOPIC_GEMINI="$MQTT_TOPIC_LLM"
# ---------------------

# Find the latest session file
latest_file=$(ls -t "$GEMINI_DIR/tmp"/session-*.json 2>/dev/null | head -n 1)

if [ -z "$latest_file" ]; then
    exit 0
fi

# Calculate metrics for the latest session
latest_tokens=$(jq -r '[ .messages[] | select(.type == "gemini") | .tokens.total // 0 ] | add // 0' "$latest_file")
latest_requests=$(jq -r '[ .messages[] | select(.type == "user") ] | length' "$latest_file")

# Calculate session duration
latest_duration=0
start_time_iso=$(jq -r '.startTime // empty' "$latest_file")
last_updated_iso=$(jq -r '.lastUpdated // empty' "$latest_file")

if [ -n "$start_time_iso" ] && [ -n "$last_updated_iso" ]; then
    # Handle ISO 8601 timestamps with standard date command fallback
    start_ts=$(date -d "${start_time_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${start_time_iso}" +%s)
    last_ts=$(date -d "${last_updated_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${last_updated_iso}" +%s)
    latest_duration=$((last_ts - start_ts))
fi

# Extract Agent processing time if available (defaulting to 0 if missing)
# This assumes the 'duration' field in the session JSON represents total agent processing time.
agent_time=$(jq -r '.duration // 0' "$latest_file")

# Generate JSON output
output=$(jq -n \
  --argjson lat_tok "$latest_tokens" \
  --argjson lat_dur "$latest_duration" \
  --argjson lat_req "$latest_requests" \
  --argjson agent_time "$agent_time" \
  '{
    "LatestSessionTokens": $lat_tok,
    "LatestSessionDuration": $lat_dur,
    "LatestSessionRequests": $lat_req,
    "LastSessionAgentTime": $agent_time
  }')

#echo $output

# Publish to MQTT if broker is configured, otherwise output to stdout
if [ -n "${MQTT_BROKER}" ]; then
    /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC_GEMINI}" -m "$output"
else
    echo "$output"
fi
