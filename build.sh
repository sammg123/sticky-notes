#!/bin/bash
# Build Sticky Notes.app (with its desktop widget) and install it to ~/Applications.
# Needs Xcode and XcodeGen (brew install xcodegen). `--test` runs the unit tests first.
set -euo pipefail
cd "$(dirname "$0")"

APP_DIR="$HOME/Applications/Sticky Notes.app"
BUILT_APP=".build/xcode/Build/Products/Release/Sticky Notes.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

for arg in "$@"; do
    case "$arg" in
        --test) echo "==> swift test"; swift test ;;
        *) echo "Usage: $0 [--test]" >&2; exit 1 ;;
    esac
done

echo "==> xcodegen + xcodebuild"
xcodegen generate --spec project.yml --quiet
# A fresh build number every time: the widget service caches each extension version, and a
# placed widget will not redraw from a newer build that reuses the old number.
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotesApp -configuration Release \
    -derivedDataPath .build/xcode -quiet build CURRENT_PROJECT_VERSION="$(date +%Y%m%d%H%M%S)"

if pgrep -x "Sticky Notes" > /dev/null 2>&1; then
    echo "==> Quitting the running app"
    pkill -x "Sticky Notes"
    sleep 0.3
fi

echo "==> Installing $APP_DIR"
mkdir -p "$HOME/Applications"
rm -rf "$APP_DIR"
cp -R "$BUILT_APP" "$APP_DIR"

# Xcode registers its build output with LaunchServices, which then opens stickynotes:// links
# in that copy. Only the installed app should answer them.
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
pluginkit -r "$BUILT_APP/Contents/PlugIns/StickyNotesWidget.appex" 2>/dev/null || true

# Register now so the widget shows up in Edit Widgets and the stickynotes:// link resolves,
# then restart the widget service so a placed widget picks up this build right away.
"$LSREGISTER" -f "$APP_DIR"
pluginkit -a "$APP_DIR/Contents/PlugIns/StickyNotesWidget.appex"
killall chronod 2>/dev/null || true

echo "==> Done: $APP_DIR"
