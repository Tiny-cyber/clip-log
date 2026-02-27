#!/bin/bash

PLIST=~/Library/LaunchAgents/com.clip-log.plist

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null
    rm "$PLIST"
    echo "LaunchAgent removed."
fi

if [ -f /usr/local/bin/clip-log ]; then
    sudo rm /usr/local/bin/clip-log
    echo "Binary removed."
fi

echo "Done. Your data is still at ~/.clip-log/history.db"
