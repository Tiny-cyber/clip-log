#!/bin/bash
set -e

echo "Building clip-log..."
swiftc clip-log.swift -o clip-log -lsqlite3 -framework Cocoa -O

PREFIX="${PREFIX:-/usr/local/bin}"
echo "Installing to $PREFIX/clip-log"
sudo cp clip-log "$PREFIX/clip-log"

# Create LaunchAgent for auto-start
PLIST=~/Library/LaunchAgents/com.clip-log.plist
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clip-log</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PREFIX/clip-log</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.clip-log/clip-log.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.clip-log/clip-log.err.log</string>
</dict>
</plist>
EOF

launchctl load "$PLIST"
echo "Done! clip-log is running. Data: ~/.clip-log/history.db"
