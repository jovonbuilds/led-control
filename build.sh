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
    <key>UTExportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key><string>io.jovon.ledsign.design</string>
        <key>UTTypeDescription</key><string>LED Sign Design</string>
        <key>UTTypeConformsTo</key><array><string>public.json</string></array>
        <key>UTTypeTagSpecification</key>
        <dict><key>public.filename-extension</key><array><string>ledsign</string></array></dict>
    </dict></array>
    <key>CFBundleDocumentTypes</key>
    <array><dict>
        <key>CFBundleTypeName</key><string>LED Sign Design</string>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>LSHandlerRank</key><string>Owner</string>
        <key>LSItemContentTypes</key><array><string>io.jovon.ledsign.design</string></array>
    </dict></array>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
# Tell Launch Services about the .ledsign type so Finder double-click opens us.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $(pwd)/$APP"
