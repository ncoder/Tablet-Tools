#!/usr/bin/env sh

# Build a small app that opens a website in Chrome, and install it on the device.
# Usage: ./webapp.sh [name url package icon-url]
# Without arguments it builds the Descartes portal app. Set ANDROID_SERIAL to pick a device.
# Needs the Android SDK (build-tools + a platform) and a JDK.

cd "$(dirname "$0")" || exit 1
name="${1:-Descartes}"
url="${2:-https://portal.descarteslearningclub.com/offline}"
package="${3:-com.descarteslearningclub.portal}"
icon="${4:-https://portal.descarteslearningclub.com/apple-touch-icon-180x180.png}"

sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
tools=$(ls -d "$sdk"/build-tools/* 2>/dev/null | sort -V | tail -1)
jar=$(ls -d "$sdk"/platforms/android-*/android.jar 2>/dev/null | sort -V | tail -1)
if [ -z "$tools" ] || [ -z "$jar" ]; then
    printf "%s\n" "Android SDK build-tools/platform not found under $sdk (set ANDROID_HOME)"
    exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
    printf "%s\n" "No device found (connect one, or set ANDROID_SERIAL if several are attached)"
    exit 1
fi

# Escape for XML, then for the sed replacement
escape () {
    printf "%s" "$1" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/[\\|&]/\\&/g'
}

build="WebApp/build/$package"
rm -rf "$build" && mkdir -p "$build/classes"

# Icon at each launcher density
curl -fsSL -o "$build/icon.png" "$icon" || exit 1
for density in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    mkdir -p "$build/res/mipmap-${density%:*}"
    sips -s format png -z "${density#*:}" "${density#*:}" "$build/icon.png" \
        --out "$build/res/mipmap-${density%:*}/icon.png" >/dev/null || exit 1
done

sed -e "s|@PACKAGE@|$(escape "$package")|" -e "s|@LABEL@|$(escape "$name")|" -e "s|@URL@|$(escape "$url")|" \
    WebApp/AndroidManifest.xml > "$build/AndroidManifest.xml"

"$tools/aapt2" compile --dir "$build/res" -o "$build/res.zip" &&
    "$tools/aapt2" link -o "$build/unsigned.apk" -I "$jar" --manifest "$build/AndroidManifest.xml" \
        --min-sdk-version 24 --target-sdk-version 34 "$build/res.zip" &&
    javac -nowarn --release 11 -cp "$jar" -d "$build/classes" WebApp/src/tools/webapp/Main.java &&
    "$tools/d8" --release --min-api 24 --lib "$jar" --output "$build" $(find "$build/classes" -name '*.class') &&
    (cd "$build" && zip -q unsigned.apk classes.dex) &&
    "$tools/zipalign" -f 4 "$build/unsigned.apk" "$build/aligned.apk" || exit 1

# One signing key per checkout (gitignored); updates must be signed with the same key
keystore="WebApp/webapp.keystore"
[ -f "$keystore" ] || keytool -genkeypair -keystore "$keystore" -storepass webapp -keypass webapp \
    -alias webapp -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=Tablet Tools Web App" >/dev/null 2>&1
apk="$build/$name.apk"
"$tools/apksigner" sign --ks "$keystore" --ks-pass pass:webapp --out "$apk" "$build/aligned.apk" || exit 1

printf "%s\n" "Installing $name ($package) -> $url"
output=$(adb install -r "$apk" 2>&1)
case "$output" in
    *UPDATE_INCOMPATIBLE*)
        # Installed copy was signed with another key (built on another machine): replace it
        adb uninstall "$package" >/dev/null && output=$(adb install "$apk" 2>&1);;
esac
printf "%s\n" "$output" | tail -1
