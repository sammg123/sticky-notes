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

# Xcode registers its build output with Launch Services, and the App Intents index (linkd)
# then files the widget's buttons under that copy. Unregistering or deleting it later makes
# linkd drop the bundle id altogether, and every click on a note's circle fails with
# "Missing: ...ToggleNoteIntent". So: retire the build copy first, give linkd a moment to
# process that, then register the installed app as a fresh install and check linkd took it.
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
pluginkit -r "$BUILT_APP/Contents/PlugIns/StickyNotesWidget.appex" 2>/dev/null || true
rm -rf "$BUILT_APP" "$(dirname "$BUILT_APP")/StickyNotesWidget.appex"
sleep 2

register_installed() {
    touch "$APP_DIR"
    "$LSREGISTER" -f -R -trusted "$APP_DIR"
    pluginkit -a "$APP_DIR/Contents/PlugIns/StickyNotesWidget.appex"
}

# True when linkd's latest event about bundles is indexing the installed copy's widget.
linkd_has_installed_copy() {
    /usr/bin/log show --start "$1" --style compact --predicate \
        'process == "linkd" AND (eventMessage CONTAINS "Detected uninstalled bundle" OR eventMessage CONTAINS "Found static metadata file")' \
        2>/dev/null | grep -E "Detected uninstalled|Found static metadata file at .*Sticky%20Notes" | tail -1 \
        | grep -q "Found static metadata file at .*Applications/Sticky%20Notes.app/Contents/PlugIns/StickyNotesWidget.appex"
}

echo "==> Registering $APP_DIR"
for attempt in 1 2 3; do
    since="$(date '+%Y-%m-%d %H:%M:%S')"
    register_installed
    sleep 3
    if linkd_has_installed_copy "$since"; then
        echo "    widget buttons indexed (attempt $attempt)"
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "WARNING: the App Intents index did not pick up $APP_DIR; widget buttons may do nothing." >&2
        echo "         Run ./build.sh again, or log out and back in." >&2
    fi
done

# Restart the widget service so a placed widget picks up this build right away.
killall chronod 2>/dev/null || true

# Running in the background is what lets notes be dragged on the widget; no box on this launch.
echo "==> Starting Sticky Notes in the background"
open -g -a "$APP_DIR" --args --background

echo "==> Done: $APP_DIR"
