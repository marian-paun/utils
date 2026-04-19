#!/bin/bash

# --- Configuration ---
GEMINI_DIR="$HOME/.gemini"
STATE_FILE="$GEMINI_DIR/tmp/telemetry/metrics_state.json"
MQTT_TOPIC="homeassistant/sensor/LLM/gemini"
# ---------------------

# Ensure state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize state if not exists
if [ ! -f "$STATE_FILE" ]; then
    echo '{"total_tokens": 0, "total_requests": 0, "processed_sessions": []}' > "$STATE_FILE"
fi

# Find all session files
session_files=$(find "$GEMINI_DIR/tmp" -name "session-*.json" 2>/dev/null)

if [ -z "$session_files" ]; then
    # Even if no sessions, we output the current total state
    total_tokens=$(jq -r '.total_tokens' "$STATE_FILE")
    total_requests=$(jq -r '.total_requests' "$STATE_FILE")
    output=$(jq -n --arg tk "$total_tokens" --arg rq "$total_requests" \
        '{"GeminiLatestSessionTokens": 0, "GeminiLatestSessionDuration": 0, "GeminiLatestSessionRequests": 0, "GeminiTotalTokens": $tk, "GeminiTotalRequests": $rq}')
    echo "$output"
    exit 0
fi

# Load current state
state=$(cat "$STATE_FILE")
total_tokens=$(echo "$state" | jq -r '.total_tokens')
total_requests=$(echo "$state" | jq -r '.total_requests')
processed_sessions=$(echo "$state" | jq -r '.processed_sessions[]')

# 1. Process New Sessions and Get Latest
latest_file=$(ls -t $session_files 2>/dev/null | head -n 1)
latest_tokens=0
latest_duration=0
latest_requests=0

for file in $session_files; do
    filename=$(basename "$file")
    
    # Calculate metrics for this session
    session_tokens=$(jq -r '[ .messages[] | select(.type == "gemini") | .tokens.total // 0 ] | add // 0' "$file")
    session_requests=$(jq -r '[ .messages[] | select(.type == "user") ] | length' "$file")

    # If this is the latest file, update latest metrics
    if [ "$file" == "$latest_file" ]; then
        latest_tokens=$session_tokens
        latest_requests=$session_requests
        
        start_time_iso=$(jq -r '.startTime // empty' "$file")
        last_updated_iso=$(jq -r '.lastUpdated // empty' "$file")
        if [ -n "$start_time_iso" ] && [ -n "$last_updated_iso" ]; then
            start_ts=$(date -d "${start_time_iso/Z/+00:00}" +%s)
            last_ts=$(date -d "${last_updated_iso/Z/+00:00}" +%s)
            latest_duration=$((last_ts - start_ts))
        fi
    fi

    # Update global totals if session not yet processed
    if [[ ! " ${processed_sessions[@]} " =~ " ${filename} " ]]; then
        total_tokens=$((total_tokens + session_tokens))
        total_requests=$((total_requests + session_requests))
        processed_sessions+=("$filename")
    fi
done

# Update state file
jq -n \
    --argjson tk "$total_tokens" \
    --argjson rq "$total_requests" \
    --argjson ps "$(printf '%s\n' "${processed_sessions[@]}" | jq -R . | jq -s .)" \
    '{"total_tokens": $tk, "total_requests": $rq, "processed_sessions": $ps}' > "$STATE_FILE"

# Output and Publish
output=$(jq -n \
  --arg lat_tok "$latest_tokens" \
  --arg lat_dur "$latest_duration" \
  --arg lat_req "$latest_requests" \
  --arg tot_tok "$total_tokens" \
  --arg tot_req "$total_requests" \
  '{
    "GeminiLatestSessionTokens": $lat_tok,
    "GeminiLatestSessionDuration": $lat_dur,
    "GeminiLatestSessionRequests": $lat_req,
    "GeminiTotalTokens": $tot_tok,
    "GeminiTotalRequests": $tot_req
  }')

/usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC}" -m "$output"
