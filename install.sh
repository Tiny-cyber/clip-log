#!/bin/bash
set -e

PREFIX="${PREFIX:-/usr/local/bin}"

# Build clip-log
echo "Building clip-log..."
swiftc clip-log.swift -o clip-log -lsqlite3 -framework Cocoa -O
echo "Installing to $PREFIX/clip-log"
sudo cp clip-log "$PREFIX/clip-log"

# Build app-tracker
echo "Building app-tracker..."
swiftc app-tracker.swift -o app-tracker -lsqlite3 -framework Cocoa -O
echo "Installing to $PREFIX/app-tracker"
sudo cp app-tracker "$PREFIX/app-tracker"

# Create LaunchAgent for clip-log
PLIST1=~/Library/LaunchAgents/com.clip-log.plist
cat > "$PLIST1" << EOF
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

# Create LaunchAgent for app-tracker
PLIST2=~/Library/LaunchAgents/com.app-tracker.plist
cat > "$PLIST2" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.app-tracker</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PREFIX/app-tracker</string>
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
    <string>$HOME/.clip-log/app-tracker.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.clip-log/app-tracker.err.log</string>
</dict>
</plist>
EOF

launchctl load "$PLIST1"
launchctl load "$PLIST2"
echo "Done! Both services running. Data: ~/.clip-log/history.db"
