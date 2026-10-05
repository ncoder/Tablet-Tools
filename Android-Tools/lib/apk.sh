# Shared helpers for building and installing the small apps in this folder (Home, WebApp).
# Source from a script that has already cd'ed into Android-Tools.
# Needs the Android SDK (build-tools + a platform; set ANDROID_HOME if not in the default
# location) and a JDK. No Android Studio or Gradle.

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

# Escape for XML, then for a sed replacement
escape () {
    printf "%s" "$1" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/[\\|&]/\\&/g'
}

# build_apk <build-dir> <src-dir> <out.apk>
# <build-dir> must contain AndroidManifest.xml, and optionally res/ and assets/.
build_apk () {
    dir="$1" src="$2" out="$3"
    mkdir -p "$dir/classes"
    resources=""
    if [ -d "$dir/res" ]; then
        "$tools/aapt2" compile --dir "$dir/res" -o "$dir/res.zip" || return 1
        resources="$dir/res.zip"
    fi
    assets=""
    [ -d "$dir/assets" ] && assets="-A $dir/assets"
    "$tools/aapt2" link -o "$dir/unsigned.apk" -I "$jar" --manifest "$dir/AndroidManifest.xml" \
            --min-sdk-version 24 --target-sdk-version 34 $assets $resources &&
        javac -nowarn --release 11 -cp "$jar" -d "$dir/classes" $(find "$src" -name '*.java') &&
        "$tools/d8" --release --min-api 24 --lib "$jar" --output "$dir" $(find "$dir/classes" -name '*.class') &&
        (cd "$dir" && zip -q unsigned.apk classes.dex) &&
        "$tools/zipalign" -f 4 "$dir/unsigned.apk" "$dir/aligned.apk" || return 1

    # One signing key per checkout (gitignored); updates must be signed with the same key
    [ -f apk.keystore ] || keytool -genkeypair -keystore apk.keystore -storepass tablet-tools \
        -keypass tablet-tools -alias tablet-tools -keyalg RSA -keysize 2048 -validity 36500 \
        -dname "CN=Tablet Tools" >/dev/null 2>&1
    "$tools/apksigner" sign --ks apk.keystore --ks-pass pass:tablet-tools --out "$out" \
        "$dir/aligned.apk" 2>/dev/null
}

# install_apk <apk> <package>
install_apk () {
    output=$(adb install -r "$1" 2>&1)
    case "$output" in
        *UPDATE_INCOMPATIBLE*)
            # Installed copy was signed with another key (built on another machine): replace it
            adb uninstall "$2" >/dev/null && output=$(adb install "$1" 2>&1);;
    esac
    printf "%s\n" "$output" | grep -E 'Success|Failure|Error' | tail -1
    case "$output" in *Success*) return 0;; *) return 1;; esac
}
