#!/usr/bin/env sh

# Scan the connected device: device info, the apps it shows in the launcher, and the
# state of every package compared with Debloat.txt / Keep.txt. Read-only.
# A copy of the report is saved to scans/. Set ANDROID_SERIAL to pick a device.

cd "$(dirname "$0")" || exit 1

if ! adb get-state >/dev/null 2>&1; then
    printf "%s\n" "No device found (connect one, or set ANDROID_SERIAL if several are attached)"
    exit 1
fi

# Package column of a list file, without comments or blank lines
list () {
    sed 's/#.*//' "$1" | awk 'NF {print $1}'
}
pkgs () {
    adb shell pm list packages "$@" | sed 's/^package://' | tr -d '\r' | sort
}
has () {
    printf "%s\n" "$2" | grep -qxF "$1"
}
label () {
    awk -v p="$1" '$1 == p { sub(/^[^#]*#[ \t]*/, ""); print; exit }' Keep.txt Debloat.txt
}
prop () {
    adb shell getprop "$1" | tr -d '\r'
}

all=$(pkgs -u)
installed=$(pkgs)
disabled=$(pkgs -d)
thirdparty=$(pkgs -3)
launcher=$(adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER |
    tr -d '\r' | awk -F/ '/\// {gsub(/ /, "", $1); print $1}' | sort -u)
remove=$(list Debloat.txt)
keep=$(list Keep.txt)

row () {
    if ! has "$1" "$installed"; then state=removed
    elif has "$1" "$disabled"; then state=disabled
    else state=enabled; fi
    has "$1" "$thirdparty" && type=user || type=system
    has "$1" "$launcher" && home=yes || home=-
    if has "$1" "$remove"; then plan=remove
    elif has "$1" "$keep"; then plan=keep
    else plan=-; fi
    printf "%-9s %-7s %-5s %-7s %-52s %s\n" "$state" "$type" "$home" "$plan" "$1" "$(label "$1")"
}
header () {
    printf "\n== %s\n" "$1"
    printf "%-9s %-7s %-5s %-7s %-52s %s\n" STATE TYPE HOME PLAN PACKAGE LABEL
}

serial=$(adb get-serialno | tr -d '\r')
brand=$(prop ro.product.brand)
model=$(prop ro.product.model)
mkdir -p scans
report="scans/$brand-$model-$serial-$(date +%Y%m%d-%H%M%S).txt"

{
    printf "%s\n" "Device:   $brand $model ($(prop ro.product.device)), serial $serial"
    printf "%s\n" "Android:  $(prop ro.build.version.release) (SDK $(prop ro.build.version.sdk)), security patch $(prop ro.build.version.security_patch)"
    printf "%s\n" "Build:    $(prop ro.build.fingerprint)"
    printf "%s\n" "Packages: $(printf "%s\n" "$installed" | wc -l | tr -d ' ') installed, $(printf "%s\n" "$disabled" | grep -c .) disabled, $(printf "%s\n" "$thirdparty" | grep -c .) user-installed"

    header "Launcher apps (HOME = currently visible; disabled apps don't show)"
    for pkg in $launcher; do row "$pkg"; done

    pending=""
    for pkg in $remove; do
        has "$pkg" "$installed" && ! has "$pkg" "$disabled" && pending="$pending $pkg"
    done
    header "Debloat.txt packages still enabled"
    for pkg in $pending; do row "$pkg"; done

    unreviewed=""
    for pkg in $launcher; do
        has "$pkg" "$remove" || has "$pkg" "$keep" || unreviewed="$unreviewed $pkg"
    done
    header "Launcher apps in neither list (review and add to Debloat.txt or Keep.txt)"
    for pkg in $unreviewed; do row "$pkg"; done

    header "All packages"
    for pkg in $all; do row "$pkg"; done
} | tee "$report"

printf "\n%s\n" "Saved to $report"
