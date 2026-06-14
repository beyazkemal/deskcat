#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/DeskCat.app"
DMG="$ROOT/dist/DeskCat.dmg"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: ESRA BEYAZ (5S5NZJ7SKF)}"

swift build -c release
rm -rf "$APP" "$ROOT/dist/DesktopPet.app" "$ROOT/dist/DesktopPet.dmg" "$ROOT/dist/dmg"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/DeskCat" "$APP/Contents/MacOS/DeskCat"
cp "$ROOT/Assets/DeskCat.icns" "$APP/Contents/Resources/DeskCat.icns"
cp "$ROOT/Assets/deskcat-agent-event.sh" "$APP/Contents/Resources/deskcat-agent-event.sh"
chmod +x "$APP/Contents/Resources/deskcat-agent-event.sh"

/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string DeskCat" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.kemalbeyaz.desktoppet" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string DeskCat" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string DeskCat" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string DeskCat.icns" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.kemalbeyaz.desktoppet.agent" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string deskcat" "$APP/Contents/Info.plist"
plutil -convert xml1 "$APP/Contents/Info.plist"

codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$ROOT/dist/dmg"
cp -R "$APP" "$ROOT/dist/dmg/DeskCat.app"
ln -s /Applications "$ROOT/dist/dmg/Applications"
rm -f "$DMG"
hdiutil create -volname DeskCat -srcfolder "$ROOT/dist/dmg" -ov -format UDZO "$DMG"
rm -rf "$ROOT/dist/dmg"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"
hdiutil verify "$DMG"
