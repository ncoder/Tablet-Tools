#!/usr/bin/env sh

# Build the Home launcher with a layout file, install it and make it the home app.
# Usage: ./home.sh [layout-file]   (default: Layout.txt). Set ANDROID_SERIAL to pick a device.
# The stock launcher (com.android.launcher3) stays enabled: it also provides Recents.

cd "$(dirname "$0")" || exit 1
. lib/apk.sh
layout="${1:-Layout.txt}"
package="tools.home"

build="build/$package"
rm -rf "$build" && mkdir -p "$build/assets"
cp Home/AndroidManifest.xml "$build/" && cp "$layout" "$build/assets/layout.txt" || exit 1

build_apk "$build" Home/src "$build/Home.apk" || exit 1
printf "%s\n" "Installing Home with $layout"
install_apk "$build/Home.apk" "$package" || exit 1

# Make it the default home app (Android 10+ home role)
adb shell cmd role add-role-holder --user 0 android.app.role.HOME "$package" &&
    adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null &&
    printf "%s\n" "Home is now the home app"
