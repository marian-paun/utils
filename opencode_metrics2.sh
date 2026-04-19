#!/bin/bash

# --- Configuration ---
OPENCODE_DB="$HOME/.local/share/opencode/opencode.db"
# ---------------------

if [ ! -f "$OPENCODE_DB" ]; then
    echo "{}"
    exit 0
fi

# 1. Get Latest Session ID
latest_session_id=$(sqlite3 "$OPENCODE_DB" "SELECT id FROM session ORDER BY time_updated DESC LIMIT 1")

if [ -z "$latest_session_id" ]; then
    echo "{}"
    exit 0
fi

# 2. Get Latest Session Metrics
latest_data=$(sqlite3 "$OPENCODE_DB" "
    SELECT 
        SUM(CAST(json_extract(data, '$.tokens.total') AS INTEGER)) as tokens,
        (MAX(time_updated) - MIN(time_created)) / 1000 as duration,
        COUNT(*) FILTER (WHERE json_extract(data, '$.role') = 'user') as requests
    FROM message 
    WHERE session_id = '$latest_session_id'
")

latest_tokens=$(echo "$latest_data" | cut -d'|' -f1)
latest_duration=$(echo "$latest_data" | cut -d'|' -f2)
latest_requests=$(echo "$latest_data" | cut -d'|' -f3)

# 3. Get Cumulative Metrics
cumulative_data=$(sqlite3 "$OPENCODE_DB" "
    SELECT 
        SUM(CAST(json_extract(data, '$.tokens.total') AS INTEGER)) as total_tokens,
        COUNT(*) FILTER (WHERE json_extract(data, '$.role') = 'user') as total_requests
    FROM message
")

total_tokens_cum=$(echo "$cumulative_data" | cut -d'|' -f1)
total_requests_cum=$(echo "$cumulative_data" | cut -d'|' -f2)

# Output in JSON format
jq -n \
  --arg lat_tok "${latest_tokens:-0}" \
  --arg lat_dur "${latest_duration:-0}" \
  --arg lat_req "${latest_requests:-0}" \
  --arg tot_tok "${total_tokens_cum:-0}" \
  --arg tot_req "${total_requests_cum:-0}" \
  '{
    "OpenCode Latest Session Tokens": $lat_tok,
    "OpenCode Latest Session Duration": $lat_dur,
    "OpenCode Latest Session Requests": $lat_req,
    "OpenCode Total Tokens": $tot_tok,
    "OpenCode Total Requests": $tot_req
  }'
