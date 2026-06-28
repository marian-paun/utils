#!/bin/bash

# ==== CONFIGURATION ====
AGY_DIR="$HOME/.gemini/antigravity-cli"
MQTT_TOPIC_AGY="$MQTT_TOPIC_LLM"
# =======================

# ==== FIND LATEST SESSION ====
# Find the latest transcript.jsonl file across subdirectories
latest_file=$(find "$AGY_DIR/brain" -name "transcript.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -n 1 | cut -d' ' -f2-)

if [ -z "$latest_file" ]; then
    exit 0
fi

# ==== PROCESS METRICS ====
# Parse transcript to extract metrics: tokens (characters / 4), duration, requests, agent time
metrics_data=$(jq -r '
    select(.created_at != null) |
    [
        .created_at,
        .type,
        ((.content // "") | length) +
        (if .tool_calls then (.tool_calls | tostring | length) else 0 end),
        (if .source == "USER_EXPLICIT" and .type == "USER_INPUT" then 1 else 0 end)
    ] | @tsv
' "$latest_file" 2>/dev/null | awk -F'\t' '
function get_ts(ts_str) {
    if (ts_str in ts_cache) return ts_cache[ts_str]
    gsub(/[TZ]/, " ", ts_str)
    cmd = "date -d \"" ts_str " +0000\" +%s"
    if ((cmd | getline ts) > 0) {
        ts_cache[ts_str] = ts + 0
    } else {
        ts_cache[ts_str] = 0
    }
    close(cmd)
    return ts_cache[ts_str]
}
BEGIN {
    first_ts_str = ""
    last_ts_str = ""
    total_chars = 0
    requests = 0
    agent_time = 0
    last_trigger_ts = 0
}
{
    ts_str = $1
    type = $2
    chars = $3 + 0
    is_req = $4 + 0

    if (first_ts_str == "") {
        first_ts_str = ts_str
    }
    last_ts_str = ts_str

    total_chars += chars
    requests += is_req

    ts = get_ts(ts_str)
    if (type == "PLANNER_RESPONSE") {
        if (last_trigger_ts > 0) {
            diff = ts - last_trigger_ts
            if (diff > 0) {
                agent_time += diff
            }
        }
        last_trigger_ts = ts
    } else {
        last_trigger_ts = ts
    }
}
END {
    start_ts = get_ts(first_ts_str)
    end_ts = get_ts(last_ts_str)
    duration = end_ts - start_ts
    if (duration < 0) duration = 0
    tokens = int(total_chars / 4)
    print tokens "|" duration "|" requests "|" agent_time
}
' 2>/dev/null)

if [ -z "$metrics_data" ]; then
    exit 0
fi

latest_tokens=$(echo "$metrics_data" | cut -d'|' -f1)
latest_duration=$(echo "$metrics_data" | cut -d'|' -f2)
latest_requests=$(echo "$metrics_data" | cut -d'|' -f3)
agent_time=$(echo "$metrics_data" | cut -d'|' -f4)

# ==== GENERATE JSON ====
output=$(jq -n \
    --argjson lat_tok "${latest_tokens:-0}" \
    --argjson lat_dur "${latest_duration:-0}" \
    --argjson lat_req "${latest_requests:-0}" \
    --argjson agent_time "${agent_time:-0}" \
    '{
        "LatestSessionTokens": $lat_tok,
        "LatestSessionDuration": $lat_dur,
        "LatestSessionRequests": $lat_req,
        "LastSessionAgentTime": $agent_time
    }')

# Always output to stdout for visibility
echo "$output"

# ==== MQTT PUBLISH ====
# Publish to MQTT if broker is configured
if [ -n "${MQTT_BROKER}" ]; then
    /usr/bin/mosquitto_pub -h "${MQTT_BROKER}" -u "${MQTT_USER}" -P "${MQTT_PWD}" \
        -t "${MQTT_TOPIC_AGY}" -m "$output"
fi
