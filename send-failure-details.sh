#!/bin/bash
UNIT=$1
HOSTNAME=$(hostname)

# 1. Get the status (ActiveState, Result, etc.)
STATUS=$(systemctl show "$UNIT" --property=ActiveState,Result,FileDescriptorStoreMax --value | tr '\n' ' ')

# 2. Grab the last 5 lines of logs for context
LOGS=$(journalctl -u "$UNIT" -n 5 --no-hostname --no-pager)

# 3. Format the message
MESSAGE="🚨 *Service Failure Alert* 🚨
*Host:* $HOSTNAME
*Service:* $UNIT
*State:* $STATUS
*Last Logs:*
$LOGS"

/usr/local/bin/pushover -p 1 -s bike -Title "Service Failure on $HOSTNAME" "$MESSAGE"
