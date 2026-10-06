#!/usr/bin/env sh

# Build a small app that shows a website full screen (WebView), and install it on the device.
# Usage: ./webapp.sh [name url package icon-url]
# Without arguments it builds the Descartes portal app. Set ANDROID_SERIAL to pick a device.

cd "$(dirname "$0")" || exit 1
. lib/apk.sh
name="${1:-Descartes}"
url="${2:-https://portal.descarteslearningclub.com/offline}"
package="${3:-com.descarteslearningclub.portal}"
icon="${4:-https://portal.descarteslearningclub.com/apple-touch-icon-180x180.png}"

build="build/$package"
rm -rf "$build" && mkdir -p "$build"

# Icon at each launcher density
curl -fsSL -o "$build/icon.png" "$icon" || exit 1
for density in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    mkdir -p "$build/res/mipmap-${density%:*}"
    sips -s format png -z "${density#*:}" "${density#*:}" "$build/icon.png" \
        --out "$build/res/mipmap-${density%:*}/icon.png" >/dev/null || exit 1
done

sed -e "s|@PACKAGE@|$(escape "$package")|" -e "s|@LABEL@|$(escape "$name")|" -e "s|@URL@|$(escape "$url")|" \
    WebApp/AndroidManifest.xml > "$build/AndroidManifest.xml"

build_apk "$build" WebApp/src "$build/$name.apk" || exit 1
printf "%s\n" "Installing $name ($package) -> $url"
install_apk "$build/$name.apk" "$package"
