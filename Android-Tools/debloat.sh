#!/usr/bin/env sh

# Disable (and clear) the packages in Debloat.txt, or re-enable them.
# Usage: ./debloat.sh Disable|Enable [package]
# With a package, only that package is changed. Set ANDROID_SERIAL to pick a device.

cd "$(dirname "$0")" || exit 1
option="$1"
app="$2"

case "$option" in
    Disable|Enable) ;;
    *) printf "%s\n" "Usage: $0 Disable|Enable [package]"; exit 1;;
esac

if ! adb get-state >/dev/null 2>&1; then
    printf "%s\n" "No device found (connect one, or set ANDROID_SERIAL if several are attached)"
    exit 1
fi

# Package column of a list file, without comments or blank lines
list () {
    sed 's/#.*//' "$1" | awk 'NF {print $1}'
}
has () {
    printf "%s\n" "$2" | grep -qxF "$1"
}

installed=$(adb shell pm list packages | sed 's/^package://' | tr -d '\r')
disabled=$(adb shell pm list packages -d | sed 's/^package://' | tr -d '\r')
protected=$(list Keep.txt)

debloat () {
    if ! has "$app" "$installed"; then
        [ -n "$single" ] && printf "%s\n" "Not installed: $app"
        return
    fi
    case "$option" in
        Disable)
            if has "$app" "$protected"; then
                printf "%s\n" "Skipped (in Keep.txt): $app"; return
            elif has "$app" "$disabled"; then
                printf "%s\n" "Already disabled: $app"; return
            fi
            output=$(adb shell pm disable-user --user 0 "$app" 2>&1)
            adb shell pm clear --user 0 "$app" >/dev/null 2>&1;;
        Enable)
            # Only undo disable-user (enabled=3); leave factory-disabled packages (enabled=2) alone
            state=$(adb shell "dumpsys package $app 2>/dev/null | grep -m1 ' User 0: .*enabled='" | grep -o 'enabled=[0-9]')
            if [ "$state" != "enabled=3" ]; then
                [ -n "$single" ] && printf "%s\n" "Not user-disabled, left as is: $app"
                return
            fi
            output=$(adb shell pm enable --user 0 "$app" 2>&1);;
    esac
    # Enable/Disable(d): package || Failed to Enable/Disable: package
    case "$output" in
        *"new state"*) printf "%sd: %s\n" "$option" "$app";;
        *) printf "%s\n" "Failed to $option: $app ($(printf "%s" "$output" | tr -d '\r' | head -1))";;
    esac
}

if [ -n "$app" ]; then
    single=1
    debloat
else
    for app in $(list Debloat.txt); do
        debloat
    done
fi
