#!/usr/bin/env sh

# Apply common settings over ADB. Prints each setting's old and new value.
# Usage: ./config.sh       Set ANDROID_SERIAL to pick a device.

if ! adb get-state >/dev/null 2>&1; then
    printf "%s\n" "No device found (connect one, or set ANDROID_SERIAL if several are attached)"
    exit 1
fi

# settings namespace, key, value, description
set_setting () {
    old=$(adb shell settings get "$1" "$2" | tr -d '\r')
    adb shell settings put "$1" "$2" "$3"
    printf "%-40s %s -> %s\n" "$4" "$old" "$(adb shell settings get "$1" "$2" | tr -d '\r')"
}

# Screen turns off after 5 minutes idle (ms)
set_setting system screen_off_timeout 300000 "Screen timeout"
# PIN only required once the screen has been off for 30 minutes (ms)
set_setting secure lock_screen_lock_after_timeout 1800000 "Lock after screen timeout"
# Faster animations on low-end hardware
set_setting global window_animation_scale 0.5 "Window animation scale"
set_setting global transition_animation_scale 0.5 "Transition animation scale"
set_setting global animator_duration_scale 0.5 "Animator duration scale"
