#!/bin/bash
# Try to connect to port 22 locally
nc -z localhost 22
if [ $? -ne 0 ]; then
    echo "SSH unresponsive, restarting..."
    systemctl restart ssh
fi
