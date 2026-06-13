#!/bin/bash

# --- Configuration ---
GEMINI_DIR="$HOME/.gemini"
MQTT_TOPIC_GEMINI="$MQTT_TOPIC_LLM"
# ---------------------

# Find the latest session file (JSON or JSONL) across subdirectories
latest_file=$(find "$GEMINI_DIR/tmp" -name "session-*.json*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)

if [ -z "$latest_file" ]; then
    exit 0
fi

# Calculate metrics based on file format
if [[ "$latest_file" == *.jsonl ]]; then
    # JSONL format: each line is a JSON object
    latest_tokens=$(jq -r 'select(.type == "gemini") | ((.tokens.total // 0) - (.tokens.cached // 0))' "$latest_file" | awk '{s+=$1} END {print s+0}')
    latest_requests=$(jq -r 'select(.type == "user") | .id' "$latest_file" | wc -l)
    
    # Calculate session duration for JSONL
    start_time_iso=$(jq -r 'select(.startTime != null) | .startTime' "$latest_file" | head -n 1)
    last_updated_iso=$(jq -r '.. | .lastUpdated? // empty' "$latest_file" | tail -n 1)
    if [ -z "$last_updated_iso" ]; then
        last_updated_iso=$(jq -r 'select(.timestamp != null) | .timestamp' "$latest_file" | tail -n 1)
    fi

    # Calculate Agent processing time by summing (gemini.timestamp - previous_user.timestamp)
    agent_time=$(jq -r 'select(.type == "user" or .type == "gemini") | [.type, .timestamp] | @tsv' "$latest_file" | awk -F'\t' '
        $2 ~ /Z$/ { 
            type = $1;
            ts_str = $2;
            gsub(/[TZ]/, " ", ts_str); 
            cmd = "date -d \"" ts_str " +0000\" +%s.%N"; 
            if ((cmd | getline ts) > 0) {
                if (type == "user") {
                    start_ts = ts;
                } else if (type == "gemini" && start_ts > 0) {
                    total_sec += (ts - start_ts);
                    start_ts = ts;
                }
            }
            close(cmd);
        } 
        END { print total_sec + 0 }' 2>/dev/null || echo 0)
else
    # Legacy JSON format
    latest_tokens=$(jq -r '[ .messages[] | select(.type == "gemini") | ((.tokens.total // 0) - (.tokens.cached // 0)) ] | add // 0' "$latest_file")
    latest_requests=$(jq -r '[ .messages[] | select(.type == "user") ] | length' "$latest_file")
    start_time_iso=$(jq -r '.startTime // empty' "$latest_file")
    last_updated_iso=$(jq -r '.lastUpdated // empty' "$latest_file")
    
    # For legacy JSON, if root duration is 0, try to calculate from message timestamps
    agent_time=$(jq -r '.duration // 0' "$latest_file")
    if [ "$agent_time" = "0" ]; then
        agent_time=$(jq -r '.messages[] | select(.type == "user" or .type == "gemini") | [.type, .timestamp] | @tsv' "$latest_file" | awk -F'\t' '
            $2 ~ /Z$/ { 
                type = $1;
                ts_str = $2;
                gsub(/[TZ]/, " ", ts_str); 
                cmd = "date -d \"" ts_str " +0000\" +%s.%N"; 
                if ((cmd | getline ts) > 0) {
                    if (type == "user") {
                        start_ts = ts;
                    } else if (type == "gemini" && start_ts > 0) {
                        total_sec += (ts - start_ts);
                        start_ts = ts;
                    }
                }
                close(cmd);
            } 
            END { print total_sec + 0 }' 2>/dev/null || echo 0)
    fi
fi

# Calculate session duration
latest_duration=0
if [ -n "$start_time_iso" ] && [ -n "$last_updated_iso" ]; then
    # Handle ISO 8601 timestamps with standard date command fallback
    start_ts=$(date -d "${start_time_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${start_time_iso}" +%s)
    last_ts=$(date -d "${last_updated_iso/Z/+00:00}" +%s 2>/dev/null || date -d "${last_updated_iso}" +%s)
    latest_duration=$((last_ts - start_ts))
fi

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

# Always output to stdout for visibility
echo "$output"

# Publish to MQTT if broker is configured
if [ -n "${MQTT_BROKER}" ]; then
    /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "${MQTT_TOPIC_GEMINI}" -m "$output"
fi
