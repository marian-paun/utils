#!/bin/bash

# Configuration
TELEGRAF_BIN="/opt/bin/telegraf"
CONFIG="/folder/telegraf.conf"
CONFIG_DIR="/folder/telegraf.d"
LOG_FILE="/var/log/telegraf-watchdog.log" # Optional: change to /dev/null if not wanted

# Check if telegraf is already running with this specific config
# pgrep -f matches against the full command line
if ! pgrep -f "$TELEGRAF_BIN.*$CONFIG" > /dev/null; then
    echo "$(date): Telegraf not running. Restarting..." >> "$LOG_FILE" 2>&1
    
    # Optional: wait if you suspect dependencies (like network) aren't ready
    # /bin/sleep 5 

    # Start telegraf in the background
    $TELEGRAF_BIN --config "$CONFIG" --config-directory "$CONFIG_DIR" --watch-config poll > /dev/null 2>&1 &
    
    if [ $? -eq 0 ]; then
        echo "$(date): Telegraf started successfully." >> "$LOG_FILE" 2>&1
    else
        echo "$(date): Failed to start Telegraf." >> "$LOG_FILE" 2>&1
    fi
fi
