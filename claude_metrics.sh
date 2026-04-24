#!/bin/bash

# --- Configuration ---
CLAUDE_DIR="$HOME/.claude"
MQTT_TOPIC_CLAUDE="$MQTT_TOPIC_LLM"
# ---------------------

# Find the latest session file in projects directory
latest_file=$(ls -t "$CLAUDE_DIR/projects"/*.jsonl 2>/dev/null | head -n 1)

if [ -z "$latest_file" ]; then
    exit 0
fi

# Calculate metrics for the latest session
latest_tokens=$(jq -rc 'select(.type == "assistant" and .message.usage != null) | (.message.usage.input_tokens // 0) + (.message.usage.output_tokens // 0)' "$latest_file" 2>/dev/null | awk '{s+=$1} END {print s+0}')

# Count user messages
latest_requests=$(jq -rc 'select(.type == "user" and .isMeta != true) | .uuid' "$latest_file" 2>/dev/null | wc -l)

# Calculate session duration (wall clock time)
latest_duration=0
timestamps=$(jq -rc 'select(.timestamp != null) | .timestamp' "$latest_file" 2>/dev/null)
if [ -n "$timestamps" ]; then
    start_time_iso=$(echo "$timestamps" | head -n 1)
    last_updated_iso=$(echo "$timestamps" | tail -n 1)

    if [ -n "$start_time_iso" ] && [ -n "$last_updated_iso" ]; then
        start_ts=$(date -d "${start_time_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${start_time_iso}" +%s)
        last_ts=$(date -d "${last_updated_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${last_updated_iso}" +%s)
        latest_duration=$((last_ts - start_ts))
    fi
fi

# Calculate Agent processing time
# Sum responseTimeMs if available in assistant messages and convert to seconds
agent_time=$(jq -rc 'select(.type == "assistant") | .message.responseTimeMs // 0' "$latest_file" 2>/dev/null | awk '{s+=$1} END {print s/1000}')

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
    /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC_CLAUDE}" -m "$output"
else
    echo "$output"
fi
