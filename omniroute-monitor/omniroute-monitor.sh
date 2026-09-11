#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${OMNIROUTE_URL:=}"
: "${OMNIROUTE_API_KEY:=}"
: "${MQTT_BROKER:=}"
: "${MQTT_TOPIC:=}"
: "${MQTT_USER:=}"
: "${MQTT_PASSWORD:=}"

API_URL="${OMNIROUTE_URL}"/api/usage/analytics


if [[ -z "$MQTT_BROKER" || -z "$MQTT_TOPIC" || -z "$MQTT_USER" || -z "$MQTT_PASSWORD" ]]; then
  echo "Error: MQTT_BROKER, MQTT_TOPIC, MQTT_USER and MQTT_PASSWORD must be set in ${ENV_FILE}" >&2
  exit 1
fi

PAYLOAD=$(curl -s -H "Authorization: Bearer ${OMNIROUTE_API_KEY}" ${API_URL} | jq '.byApiKey | map(del(.apiKey, .apiKeyId, .historicalApiKeyNames))')

echo $PAYLOAD


if [[ -z "$PAYLOAD" || "$PAYLOAD" == "null" ]]; then
  echo "Error: empty or invalid payload from API" >&2
  exit 1
fi

mosquitto_pub -h "$MQTT_BROKER" -t "$MQTT_TOPIC" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -m "$PAYLOAD"
