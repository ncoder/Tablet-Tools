# Android Tools

Scripts to strip a stock Android tablet down to the essentials over ADB, following the same
approach as Fire Tools' debloat: packages are disabled with `pm disable-user` and their data
cleared, so everything can be turned back on. No root required.

First built for the FOSSiBOT Q2 (MediaTek MT8766, Android 13). The lists only touch packages
that are installed, so they can be reused on other tablets after a scan.

## Requirements

- `adb` ([Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools))
- USB debugging enabled on the tablet (Settings > About tablet > tap Build number 7 times, then
  Settings > System > Developer options > USB debugging)
- With more than one device attached, choose one with `export ANDROID_SERIAL=<serial>`

## Usage

```sh
./scan.sh                       # Read-only report; also saved to scans/
./debloat.sh Disable            # Disable everything in Debloat.txt
./debloat.sh Enable             # Re-enable everything debloat.sh disabled
./debloat.sh Disable <package>  # Disable / enable a single package
./debloat.sh Enable <package>
./launcher.sh [version]         # Install Fossify Launcher and make it the home app
```

`scan.sh` shows the device's launcher apps, the Debloat.txt packages that are still enabled, and
any launcher app that is in neither list. Review those on a new device and add each one to
`Debloat.txt` or `Keep.txt`.

## Lists

- `Debloat.txt`: packages to disable.
- `Keep.txt`: packages that must stay. `debloat.sh` refuses to disable anything listed here.
- Packages in neither list (framework, providers, overlays, networking, telephony) are left alone.

What stays in the app drawer: Settings, Camera, Chrome, Photos, Files by Google, Clock, Calculator.
Google Play services, Gboard (the only keyboard), WebView, printing and the core system stay
enabled in the background.

## Notes

- **No Play Store means no automatic updates** for Chrome, WebView, Gboard and Google Play
  services. To update one, download the APK and run `adb install -r <file>.apk`.
- **Launcher:** the stock launcher's Google search bar can't be removed and stops working once
  the Google app is disabled, so `launcher.sh` installs
  [Fossify Launcher](https://github.com/FossifyOrg/Launcher) from its GitHub releases and makes it
  the home app. The stock launcher stays enabled because it provides the Recents screen. Downloaded
  APKs are cached in `apks/`.
- **Firmware updates** are off (`com.incar.update`). To update, run
  `./debloat.sh Enable com.incar.update`, update, disable it again, and re-run `./scan.sh` in case
  the update brought apps back.
- A factory reset re-enables everything; run `./debloat.sh Disable` again afterwards.
