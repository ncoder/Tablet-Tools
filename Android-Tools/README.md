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
./webapp.sh                     # Build + install the Descartes portal app
./webapp.sh <name> <url> <package> <icon-url>   # Same for any other website
./home.sh [layout-file]         # Build + install the Home launcher from Layout.txt
./config.sh                     # Screen timeout 5 min, PIN after 30 min, faster animations
```

Setting up a new tablet: `./scan.sh`, `./debloat.sh Disable`, `./webapp.sh`, `./home.sh`,
`./config.sh`.

`scan.sh` shows the device's launcher apps, the Debloat.txt packages that are still enabled, and
any launcher app that is in neither list. Review those on a new device and add each one to
`Debloat.txt` or `Keep.txt`.

## Lists

- `Debloat.txt`: packages to disable.
- `Keep.txt`: packages that must stay. `debloat.sh` refuses to disable anything listed here.
- Packages in neither list (framework, providers, overlays, networking, telephony) are left alone.

- `Layout.txt`: the home screen (see below).

What's left to use: Descartes, Chrome, Camera, Photos, Files by Google, Clock, Calculator and
Settings. Google Play services, Gboard (the only keyboard), WebView, printing and the core system stay
enabled in the background.

## Notes

- **No Play Store means no automatic updates** for Chrome, WebView, Gboard and Google Play
  services. To update one, download the APK and run `adb install -r <file>.apk`.
- **Home screen:** `home.sh` builds a small launcher (source in `Home/`) from `Layout.txt`: one
  large featured tile (Descartes) and a grid of apps, in file order. Only listed apps appear and
  there's no app drawer, so students can't move or remove icons. To change the home screen, edit
  `Layout.txt` and re-run `./home.sh`. The stock launcher stays enabled because it provides the
  Recents screen.
- **Web apps:** `webapp.sh` builds a tiny APK (source in `WebApp/`) that shows the site full screen
  in Android's WebView: no browser tabs or address bar, and it always starts on the given URL.
  Pages on the same host stay in the app (Back goes back through them); other links and downloads
  open in the default browser. The app keeps its own login, separate from Chrome/Silk, and the
  site's service worker works, so the portal's offline page loads without Wi-Fi.
- **Building:** `home.sh` and `webapp.sh` share `lib/apk.sh`, which needs the Android SDK
  (build-tools + a platform; set `ANDROID_HOME` if it isn't in the default location) and a JDK,
  but no Android Studio or Gradle. The signing key is created as `apk.keystore` on the first build
  (gitignored). A copy signed on another machine is uninstalled and replaced automatically.
- **Lock timeout:** `config.sh` sets "Lock after screen timeout" to 30 minutes, but pressing the
  power button still locks immediately unless "Power button instantly locks" is turned off in
  Settings > Security > Screen lock (gear icon); that switch can't be changed over ADB.
- **Firmware updates** are off (`com.incar.update`). To update, run
  `./debloat.sh Enable com.incar.update`, update, disable it again, and re-run `./scan.sh` in case
  the update brought apps back.
- **Fire tablets:** `webapp.sh` works (tested on a Fire HD 10, Fire OS 8.3) and Fire Launcher adds
  its icon to the home screen automatically. `home.sh` doesn't: Fire OS
  sends Home to Fire Launcher whatever the home app setting says, and Fire Launcher is a protected
  package that can't be disabled. Silk's homepage can't be set over ADB either; it reads
  `HomepageLocation` only from an MDM's managed configuration.
- A factory reset re-enables everything; run `./debloat.sh Disable` again afterwards.
