#!/bin/bash

# qBittorrent Post-Download Script
# This script moves completed downloads to an NFS share and sends a Telegram notification.
#
# Arguments from qBittorrent:
# %N: Torrent name
# %F: Content path (file or folder)
# %Z: Size (bytes)

TORRENT_NAME="$1"
CONTENT_PATH="$2"
TORRENT_SIZE_BYTES="$3"

MOUNT_POINT="/mnt/Astor.Video"
DEST_DIR="$MOUNT_POINT/Incomplete"
TAG="qbittorrent-postprocess"

# Helper function for logging to journald
log_message() {
    echo "$1" | systemd-cat -t "$TAG"
}

# Get current date/time
DATETIME=$(date "+%Y-%m-%d %H:%M:%S")

# Convert size to human readable (e.g., 1.2GiB)
SIZE_HR=$(numfmt --to=iec-i --suffix=B "$TORRENT_SIZE_BYTES" 2>/dev/null || echo "$TORRENT_SIZE_BYTES bytes")

# 1. Check if NFS share is available
if mountpoint -q "$MOUNT_POINT"; then
    # 2. Ensure destination exists
    mkdir -p "$DEST_DIR"
    
    # Attempt to move the file or folder
    if mv "$CONTENT_PATH" "$DEST_DIR/"; then
        log_message "SUCCESS: Moved '$TORRENT_NAME' to $DEST_DIR"
        MSG="Name: $TORRENT_NAME\nSize: $SIZE_HR\nDate: $DATETIME\nStatus: Moved to NFS share"
        /usr/bin/telegram-notify --title "Torrent Downloaded" --text "$MSG" --success
    else
        log_message "ERROR: Failed to move '$TORRENT_NAME' from $CONTENT_PATH"
        MSG="Name: $TORRENT_NAME\nSize: $SIZE_HR\nDate: $DATETIME\nStatus: Error moving to NFS"
        /usr/bin/telegram-notify --title "Torrent Move Failed" --text "$MSG" --error
    fi
else
    log_message "SKIP: NFS share '$MOUNT_POINT' not available. '$TORRENT_NAME' stays at $CONTENT_PATH"
    MSG="Name: $TORRENT_NAME\nSize: $SIZE_HR\nDate: $DATETIME\nStatus: Finished (NFS Unavailable - Not Moved)"
    /usr/bin/telegram-notify --title "Torrent Downloaded" --text "$MSG" --question
fi
