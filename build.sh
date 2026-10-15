#!/bin/bash
# Builds LEDSign.app (release) next to this script. macOS needs a real .app bundle
# with NSBluetoothAlwaysUsageDescription before it will grant Bluetooth access.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=LEDSign.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/LEDSign "$APP/Contents/MacOS/LEDSign"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>LED Sign</string>
    <key>CFBundleDisplayName</key><string>LED Sign</string>
    <key>CFBundleIdentifier</key><string>io.jovon.ledsign</string>
    <key>CFBundleExecutable</key><string>LEDSign</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>LED Sign uses Bluetooth to send text and drawings to your CoolLED sign.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $(pwd)/$APP"
