#!/bin/bash
#DB_PATH="/home/marp/.local/share/opencode/opencode.db"
# collect local Opencode performance metrics; excluding those related to litellm or LLM Gateway exposed
# local opencode.db path in OPENCODE_DB

TOKENS=$(sqlite3 "${OPENCODE_DB}" "
  SELECT COALESCE(SUM(json_extract(data, '\$.tokens.total')), 0)
  FROM message
  WHERE json_extract(data, '\$.role') = 'assistant'
  AND json_extract(data, '\$.tokens.total') IS NOT NULL
  AND json_extract(data, '\$.providerID') NOT IN ('litellm', 'LLM Gateway');
")

REQUESTS=$(sqlite3 "${OPENCODE_DB}" "
  SELECT COUNT(*)
  FROM message
  WHERE json_extract(data, '\$.role') = 'assistant'
  AND json_extract(data, '\$.providerID') IS NOT NULL
  AND json_extract(data, '\$.providerID') NOT IN ('litellm', 'LLM Gateway');
")

DURATION=$(sqlite3 "${OPENCODE_DB}" "
  SELECT COALESCE(SUM(time_updated - time_created) / 1000, 0)
  FROM session;
")

echo "opencode_metrics,host=$HOSTNAME opencode_tokens=$TOKENS,opencode_requests=$REQUESTS,opencode_session_duration_seconds=$DURATION $(date +%s)000000000"
