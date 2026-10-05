#!/usr/bin/env sh

# Install Fossify Launcher (open source, no Google search bar) and make it the home app.
# Usage: ./launcher.sh [version]   (default: latest release, e.g. ./launcher.sh 1.10.0)
# The stock launcher (com.android.launcher3) stays enabled: it also provides Recents.
# Set ANDROID_SERIAL to pick a device.

cd "$(dirname "$0")" || exit 1
repo="FossifyOrg/Launcher"
package="org.fossify.home"

if ! adb get-state >/dev/null 2>&1; then
    printf "%s\n" "No device found (connect one, or set ANDROID_SERIAL if several are attached)"
    exit 1
fi

if [ -n "$1" ]; then
    release="https://api.github.com/repos/$repo/releases/tags/$1"
else
    release="https://api.github.com/repos/$repo/releases/latest"
fi
url=$(curl -fsSL "$release" | grep -o '"browser_download_url": *"[^"]*\.apk"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
if [ -z "$url" ]; then
    printf "%s\n" "No APK found at $release"
    exit 1
fi

mkdir -p apks
apk="apks/$(basename "$url")"
[ -f "$apk" ] || curl -fL -o "$apk" "$url" || exit 1

printf "%s\n" "Installing $apk"
adb install -r "$apk" || exit 1

# Make it the default home app (Android 10+ home role)
adb shell cmd role add-role-holder --user 0 android.app.role.HOME "$package" &&
    adb shell input keyevent KEYCODE_HOME &&
    printf "%s\n" "Fossify Launcher is now the home app"
