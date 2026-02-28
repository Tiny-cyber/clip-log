#!/bin/bash

# clip-log
PLIST1=~/Library/LaunchAgents/com.clip-log.plist
if [ -f "$PLIST1" ]; then
    launchctl unload "$PLIST1" 2>/dev/null
    rm "$PLIST1"
    echo "clip-log LaunchAgent removed."
fi
if [ -f /usr/local/bin/clip-log ]; then
    sudo rm /usr/local/bin/clip-log
    echo "clip-log binary removed."
fi

# app-tracker
PLIST2=~/Library/LaunchAgents/com.app-tracker.plist
if [ -f "$PLIST2" ]; then
    launchctl unload "$PLIST2" 2>/dev/null
    rm "$PLIST2"
    echo "app-tracker LaunchAgent removed."
fi
if [ -f /usr/local/bin/app-tracker ]; then
    sudo rm /usr/local/bin/app-tracker
    echo "app-tracker binary removed."
fi

echo "Done. Your data is still at ~/.clip-log/history.db"
