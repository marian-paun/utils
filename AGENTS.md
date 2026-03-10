# AGENTS.md - Agent Coding Guidelines for Utils Repository

## Overview

This repository contains utility shell scripts for system administration, media management, and monitoring tasks. Most scripts run on Raspberry Pi 4 or NAS devices and integrate with Home Assistant via MQTT.

## Build / Lint / Test Commands

### Linting

```bash
# Lint a single shell script with ShellCheck
shellcheck <script_name>

# Lint all shell scripts
shellcheck *.sh

# Stricter validation
shellcheck -S error -x <script_name>
```

### Testing

**No automated test suite exists.** Scripts are validated by:
1. Running in target environment (Raspberry Pi 4, NAS)
2. Verifying MQTT: `mosquitto_sub -t "homeassistant/sensor/#"`
3. Checking systemd: `systemctl status <service-name>`

---

## Code Style Guidelines

### Shell Standards

- **Primary**: `bash` with `#!/bin/bash` shebang
- **POSIX**: use `#!/bin/sh` only when maximum portability required
- All scripts must be executable

### Formatting

- 4-space indentation (no tabs)
- Max line length: 100 characters
- Blank lines between logical sections
- Group config variables at top
- Section comments: `# ==== SECTION NAME ====`

### Naming Conventions

- Scripts: lowercase with dashes (`media.sh`, `diskio1.sh`)
- Variables: lowercase with underscores (`mqtt_broker`)
- Constants: uppercase (`AUDIO_QUALITY`, `MQTT_BROKER`)
- Functions: lowercase with underscores (`find_cover_art`)

### Variables & Scope

- Always use `local` for function variables
- Quote paths and potentially empty strings: `"$variable"`
- Use `${var}` for clarity in complex expressions

### Functions

```bash
function_name() {
    local arg1="$1"
    local arg2="$2"
    # function body
}
```

### Error Handling

- Use `set -e` where appropriate
- Check command existence: `command -v tool >/dev/null 2>&1`
- Check exit codes for critical operations
- Output errors to stderr: `echo "Error: message" >&2`
- Clean up on failure: `[[ -f "$output" ]] && rm "$output"`

### Input Handling

- Validate required arguments at start
- Provide usage message: `echo "Usage: $0 [args]" >&2; exit 1`

### External Tools

Common dependencies:
- Audio: `ffmpeg`, `ffprobe`, `shnsplit`
- Metrics: `iostat`, `bc`, `smartctl`, `jq`
- Networking: `mosquitto_pub`, `mosquitto_sub`
- System: `du`, `awk`, `sed`

### MQTT Integration

- Use env vars for credentials: `${MQTT_USER}`, `${MQTT_PWD}`
- Never hardcode passwords
- Default broker: `oramicro2.alpine-blues.ts.net`
- Topics: `homeassistant/sensor/<device>/<metric>`

### JSON Output

- Use `jq` for JSON manipulation
- Simple metrics can use string concatenation
- Publish via: `mosquitto_pub -t "topic" -m "$json"`

### Configuration

- Hardcoded paths exist (e.g., `/volume1/`) - update for your environment
- MQTT settings at top of scripts
- Credentials via environment variables

---

## Common Patterns

### Monitoring Script
```bash
#!/bin/bash
MQTT_BROKER="hostname"
MQTT_TOPIC="homeassistant/sensor/..."

metrics=$(some_command | parse_output)
mosquitto_pub -h "$MQTT_BROKER" -u "${MQTT_USER}" -P "${MQTT_PWD}" \
    -t "$MQTT_TOPIC" -m "$metrics"
```

### Audio Conversion
```bash
AUDIO_QUALITY="-q:a 2"
AUDIO_CODEC="aac"
OUTPUT_EXT="m4a"

find_cover_art() { ... }
convert_single_file() { ... }
```

### Systemd Integration
- `.service` files define how scripts run
- `.timer` files define schedules

---

## Directory Structure

```
.
├── convert           # Audio conversion (FLAC/MP3 -> AAC)
├── media.sh          # Media directory size to MQTT
├── ssd.sh / ssd-astor.sh  # SSD SMART data
├── diskio1.sh / pdio # Disk I/O metrics
├── mqtt-wait.sh      # MQTT broker connectivity
├── telegraf/         # Telegraf monitoring configs
└── *.service / *.timer   # Systemd unit files
```

## Notes

- These are **operational scripts** for specific hardware; not libraries
- Prioritize **reliability** over cleverness
- Test in non-production first
- New monitoring scripts: collect → format JSON → publish MQTT
