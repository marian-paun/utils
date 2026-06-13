#!/bin/bash

# Watchdog Notification & Repair Script
# This script is called by the watchdog daemon when a condition is met.
# It sends alerts and then attempts to repair common issues before forced reboot.

REASON=$1
HOSTNAME=$(hostname)
DATE=$(date "+%Y-%m-%d %H:%M:%S")
REPAIR_LOG="/home/marp/watchdog-repair.log"

if [ -z "$REASON" ]; then
    REASON="Unknown system instability / Watchdog timeout"
fi

# =====================================================================
# 1. SEND NOTIFICATIONS FIRST (While network and RAM are still alive)
# =====================================================================

MESSAGE="⚠️ Watchdog Alert on $HOSTNAME
Time: $DATE
Reason: $REASON
Action: Attempting Repair..."

# Telegram
/usr/bin/telegram-notify --error --title "Rpi4 Watchdog Alert" --text "$MESSAGE" >/dev/null 2>&1

# Pushover (Direct API call)
API_TOKEN="ar4xau8bzc6q721mrdbfcryw73k3ns"
USER_KEY="uaav2wrjzfs4jwceg6tnne6fv6i8do"

/usr/bin/curl -s \
  --max-time 10 \
  --form-string "token=$API_TOKEN" \
  --form-string "user=$USER_KEY" \
  --form-string "title=Rpi4 Watchdog Alert" \
  --form-string "message=$MESSAGE" \
  --form-string "priority=1" \
  https://api.pushover.net/1/messages.json > /tmp/watchdog-pushover.log 2>&1

echo "[$DATE] Watchdog triggered. Reason: $REASON" >> "$REPAIR_LOG"
echo "System Rebooting for: $REASON at $DATE" > /home/marp/reason.txt

# =====================================================================
# 2. REPAIR ATTEMPTS
# =====================================================================
REPAIRED=false

# A. Log2Ram / Disk Space Repair
LOG_USAGE=$(df /var/log | awk 'NR==2 {print $5}' | sed 's/%//')
if [ -n "$LOG_USAGE" ] && [ "$LOG_USAGE" -gt 80 ]; then
    echo "[$DATE] /var/log is at ${LOG_USAGE}%. Running logrotate and clearing old logs." >> "$REPAIR_LOG"
    /usr/sbin/logrotate -f /etc/logrotate.conf >/dev/null 2>&1
    # If still high, truncate large log files
    if [ $(df /var/log | awk 'NR==2 {print $5}' | sed 's/%//') -gt 90 ]; then
        find /var/log -type f -name "*.log" -size +10M -exec truncate -s 0 {} +
    fi
    REPAIRED=true
fi

# B. Memory / OOM Repair
FREE_MEM=$(free -m | awk '/Mem:/ {print $4 + $7}')
if [ -n "$FREE_MEM" ] && [ "$FREE_MEM" -lt 256 ]; then
    echo "[$DATE] Low memory (${FREE_MEM}MB). Dropping caches." >> "$REPAIR_LOG"
    sync && echo 3 > /proc/sys/vm/drop_caches
    # Restart services that might be leaking
#    systemctl restart qbittorrent-nox@marp.service >/dev/null 2>&1
#    systemctl restart deluge-web.service deluged.service >/dev/null 2>&1
    REPAIRED=true
fi

# C. Process Repair (SSHD)
if [[ "$REASON" == *"pidfile"* ]] || [[ "$REASON" == *"sshd"* ]]; then
    echo "[$DATE] SSH service failure detected. Restarting." >> "$REPAIR_LOG"
    systemctl restart ssh >/dev/null 2>&1
    REPAIRED=true
fi

# D. Network Repair
#if [[ "$REASON" == *"ping"* ]] || [[ "$REASON" == *"interface"* ]]; then
#    echo "[$DATE] Network issue detected. Restarting bond1." >> "$REPAIR_LOG"
#    ifup bond1 --force >/dev/null 2>&1
#    REPAIRED=true
#fi

# =====================================================================
# 3. FINAL ACTION
# =====================================================================

if [ "$REPAIRED" = true ]; then
    echo "[$DATE] Repair attempted. Exiting with 0 to defer reboot." >> "$REPAIR_LOG"
    # Notify of repair attempt
    /usr/bin/telegram-notify --success --title "Rpi4 Repair Attempted" --text "Watchdog repair logic executed for $REASON. Monitoring system..." >/dev/null 2>&1
    exit 0
fi

# If we get here, either repair wasn't possible or it's a critical hang
echo "[$DATE] No specific repair found or repair failed. Forcing reboot." >> "$REPAIR_LOG"

# Sync log2ram before rebooting
if [ -x /bin/systemctl ]; then
    /bin/systemctl reload log2ram.service >/dev/null 2>&1
fi

# Exit with 1 to force hardware reboot
#exit 1
