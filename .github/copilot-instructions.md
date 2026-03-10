# Copilot Instructions for Utils Repository

This repository contains utility shell scripts for system administration, media management, and monitoring tasks.

## Language & Shell Standards

- **Primary shell**: `bash` (use `#!/bin/bash`)
- **POSIX-compatible scripts**: use `#!/bin/sh` only when maximum portability is required (e.g., `media.sh`)
- **All scripts**: executable with clear shebangs at the top
- **Code style**: 
  - Use `local` scope for function variables
  - Configure settings (codec, quality, MQTT broker, paths) as uppercase variables at the top of each script
  - Use `()` for function definitions

## Major Script Categories

### Audio Conversion (`convert`)
- **Purpose**: Converts FLAC/MP3 to AAC (m4a format)
- **Features**: Single/batch processing, CUE sheet support (split into tracks or create chapters), metadata/cover art embedding
- **Configuration**: `AUDIO_QUALITY`, `AUDIO_CODEC`, `OUTPUT_EXT` at the top
- **Key functions**: `find_cover_art()`, `build_cover_art_args()`, `convert_single_file()`
- **Dependencies**: `ffmpeg`, `ffprobe`, `shnsplit` (from `shntool`)
- **Usage**: `bash convert [path_to_directory]`

### Media Size Reporting (`media.sh`)
- **Purpose**: Calculate disk usage across media directories and publish to MQTT
- **Pattern**: Uses `du -sm` to get directory sizes, formats as JSON, publishes via `mosquitto_pub`
- **Configuration**: Broker hostname, credentials, and directory paths (update as needed)
- **Key variables**: `MQTT_USER`, `MQTT_PWD` (from environment)

### Monitoring Scripts (diskio, pdio, ssd-astor, etc.)
- **Pattern**: Collect system metrics (I/O, power, disk SMART data) → parse into JSON → publish to MQTT
- **MQTT Integration**: All monitoring scripts send data to Home Assistant via `homeassistant/sensor/` topics
- **Configuration**: MQTT broker hostname and credentials typically at top or set via environment
- **Dependencies**: `iostat`, `bc`, `smartctl`, `mosquitto_pub`

### Systemd Integration
- `.service` files define units for running scripts (e.g., `ssd.service`, `mqtt-wait.service`)
- `.timer` files define scheduled execution (e.g., `ssd.timer`, `sshguard-stat.timer`)
- Modify paths and environment variables in service files when relocating or adapting scripts

## Key Patterns & Conventions

### Configuration Management
1. **Hard-coded paths**: Some scripts include absolute paths (e.g., `/volume1/` in `media.sh`). Update these when adapting for different environments.
2. **MQTT broker**: Typically `oramicro2.alpine-blues.ts.net` or read from variables; update `MQTT_BROKER`, `MQTT_USER`, `MQTT_PWD` as needed.
3. **Credentials**: Passed via environment variables (`MQTT_USER`, `MQTT_PWD`) — do NOT hardcode passwords.

### JSON Output
- Metrics scripts format output as JSON before publishing:
  - Use `echo` with string concatenation or `printf` for building JSON payloads
  - Simple key-value metrics work well with single-line JSON

### External Tools
When modifying scripts, ensure these tools are available:
- Audio: `ffmpeg`, `ffprobe`, `shnsplit`
- Metrics: `iostat`, `du`, `bc`, `smartctl`
- Networking: `mosquitto_pub`
- Utilities: `jq` (for JSON manipulation in some scripts)

## Directory Structure

```
.
├── convert           # Audio conversion script (main utility)
├── media.sh          # Media directory size reporter
├── ssd.sh / ssd-astor.sh  # SSD SMART data monitor
├── diskio1.sh / pdio # Disk I/O metrics
├── mqtt-wait.sh      # MQTT broker connection checker
├── telegraf/         # Telegraf agent monitoring configs
├── *.service / *.timer    # Systemd unit files
└── .github/
    └── copilot-instructions.md  # This file
```

## Linting

- **ShellCheck** is configured for automated shell script validation
- Run checks locally: `shellcheck [script_name]`
- Common issues to watch: unused variables, unquoted variables, incorrect conditionals
- Not all ShellCheck warnings require changes (e.g., some POSIX portability warnings may be intentional)

## Testing & Validation

- **No automated test suite** exists; scripts are validated by:
  1. Running them in target environment (Raspberry Pi 4, NAS, etc.)
  2. Verifying MQTT message publication with `mosquitto_sub -t "homeassistant/sensor/#"`
  3. Checking systemd service status: `systemctl status <service-name>`

- **Manual validation steps**:
  - For audio conversion: Compare input/output file specs with `ffprobe`
  - For MQTT scripts: Monitor broker logs or subscribe to test topics
  - For timing: Run scripts manually first, then enable systemd timers after verification

## Common Edits

- **Update MQTT broker**: Change `MQTT_BROKER` or hardcoded hostnames (search for `oramicro2`)
- **Change audio codec/quality**: Modify `AUDIO_QUALITY`, `AUDIO_CODEC` in `convert`
- **Adapt directory paths**: Search for absolute paths like `/volume1/` or `/data/git/` and update for your environment
- **Enable/disable scripts**: Use `systemctl enable/disable <service>` and `systemctl start/stop <service>`

## Development Notes

- These are **operational scripts** run on specific hardware (Raspberry Pi, NAS); they are not libraries or frameworks
- Prioritize **reliability and correctness** over conciseness
- Test changes in a non-production environment first, especially for audio conversion and system monitoring
- When adding new monitoring scripts, follow the "collect → format JSON → publish via MQTT" pattern
