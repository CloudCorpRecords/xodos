# TreeOS v0.2 — Build + Emulator Proof Report (PERSISTENT HOME)
Date: 2026-11-07 (America/Los_Angeles)
Host: Razer RENE_HOME_MAIN (Windows 11, user cloud)
Source: ~/workspace/tree-os/treeos-v02.tar.gz (6,998 bytes) — Gradle project, AGP 9.0.1, module :app, plain Java, no project fixes needed
Fresh Razer dir: `C:\Users\cloud\treeos2\project` (v0.1 at `C:\Users\cloud\treeos\` left intact)
Scripts: `build-on-razer-v02.ps1`, `emulator-proof-v02.ps1` (in ~/workspace/tree-os/ and on the Razer under treeos2)

## Build — SUCCESS
Recipe identical to v0.1: JAVA_HOME = Android Studio jbr (OpenJDK 25.0.3), ANDROID_HOME = C:\Users\cloud\AppData\Local\Android\Sdk, gradle-9.1.0 `gradle :app:assembleDebug --console=plain`
Result: `BUILD SUCCESSFUL in 41s`, 32 actionable tasks executed, build exit 0. Only note: MainActivity uses a deprecated API (onBackPressed) — compiles fine, same as v0.1.

### APK verification (aapt2 badging, build-tools 36.0.0)
- Package: `dev.treeos.launcher` ✅
- versionName: `0.2.0`, versionCode `2` ✅
- **minSdkVersion: `28`** ✅ (confirmed in badging AND in on-device dumpsys: `versionCode=2 minSdk=28 targetSdk=34`)
- targetSdkVersion `34`, compileSdkVersion `35`
- Label: `TreeOS`, launchable activity `dev.treeos.launcher.MainActivity`, provides-component: launcher
- Razer APK path: `C:\Users\cloud\treeos2\project\app\build\outputs\apk\debug\app-debug.apk` (copied to `C:\Users\cloud\treeos2\treeos-0.2.0-debug.apk`)
- Size: **2,453,754 bytes**
- SHA256: **9e249eab93933823e8eeff24237594feacc7f5264886dded09ed5d0122e301b2**
- VM copy: [treeos-0.2.0-debug.apk](sandbox://workspace/tree-os/apks/treeos-0.2.0-debug.apk) — sha256 re-verified on the VM, identical.

## Emulator proof — SUCCESS, including PERSISTENT HOME
AVD: `Medium_Phone_API_37.0`, headless, detached WMI Win32_Process.Create launch with `-no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect` (ProcessId 94188, ReturnValue 0).
Safety: `adb devices` before launch listed ONLY the real attached phone (`<real-phone-serial>`). Every adb command in the proof was explicitly targeted `-s emulator-5554`. The real phone was not installed on, launched on, or otherwise touched; the Poco was not touched. No real-phone installs (per Rene's indefinite deferral).

- Boot: `sys.boot_completed=1` at poll 16 (cold boot; early polls showed device-offline while the AVD came up)
- Install: `adb -s emulator-5554 install -r` → **"Performing Streamed Install / Success"** ✅
- On-device package read-back: `versionCode=2 minSdk=28 targetSdk=34`, `versionName=0.2.0`

### Persistent HOME — SET AND VERIFIED ✅ (the v0.1 gap, now closed)
- Attempt 1: `cmd package set-home-activity dev.treeos.launcher/.MainActivity` → **"Success"**, exit 0. This method worked on the API 37 image.
- Attempt 2 (also run): `cmd role add-role-holder android.app.role.HOME dev.treeos.launcher` → exit 0, no error output.
- Read-back 1 — `cmd role get-role-holders android.app.role.HOME` → **`dev.treeos.launcher`** (sole holder)
- Read-back 2 — `cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME` → `isDefault=true` + **`dev.treeos.launcher/.MainActivity`**
- Read-back 3 — `dumpsys role`: `name=android.app.role.HOME` → `holders=dev.treeos.launcher`
- (Read-back 4 — `cmd package query-activities` for HOME lists 3 activities: NexusLauncher, TreeOS, FallbackHome; the query listing flags multiple entries isDefault=true, so the authoritative proofs are the role-holder and resolve-activity read-backs above.)

### Functional HOME-key test — PASS ✅
1. Opened Settings: `topResumedActivity = com.android.settings/.homepage.SettingsHomepageActivity` (Settings in front, TreeOS displaced)
2. Sent `input keyevent 3` (KEYCODE_HOME)
3. Read-back: `topResumedActivity = dev.treeos.launcher/.MainActivity` → **the system returned to TreeOS as the default home.** Script marker: `HOME_KEY_TEST=PASS_TREEOS_ON_TOP`

### Stability
- `pidof dev.treeos.launcher` = **2319**, same pid on re-check after the screencap wait
- Logcat scan: **FATAL_COUNT=0** — no FATAL EXCEPTION anywhere, no crash for our package

### Screenshots (both visually inspected)
- [emu-treeos-v02-1.png](sandbox://workspace/tree-os/shots/emu-treeos-v02-1.png) — 340,987 bytes, 1080x2400, sha256 51264a94d073a9de0b231291438fcfb1dc42fadbd92dd712cec4700c6f812d5f — taken on the home screen AFTER the Home-key test
- [emu-treeos-v02-2.png](sandbox://workspace/tree-os/shots/emu-treeos-v02-2.png) — 344,238 bytes, 1080x2400, sha256 bc04fc3b50835e237d6f6ad95f3d6c65d344390985e268e54126f50fd0743138 — ~4s later, same pid

What they show: dark-green TreeOS home — brand **"🌳 TreeOS • 0.2"**, clock **"10:34 AM"** (new h:mm a format, AM shown, fits at 48sp), "Sat, Nov 7 • 🔋 100%", Search apps bar, 4-column grid of 24 real apps (Calendar, Camera, Chrome, Clock, Contacts, Drive, Files, Ganjuko, Gemini, Gmail, Google, Maps, Messages, Phone, Photos, Play Store, rdrive, Safety, Settings, TMoble, Xod, Xod Survivors, YouTube, YT Music), and the dock: **Phone / Texts / Web / Cam / Tree / Setup — every label on a single line, NO wrapping.** The v0.1 "Camera"/"Settings" two-line wrap is fixed.

### Shutdown — CLEAN
`adb -s emulator-5554 emu kill` → "OK: killing emulator, bye bye / OK". Honest nuance: the `adb devices` check 3s after the kill still listed emulator-5554 (adb lag), but a re-check immediately after showed only the real phone `<real-phone-serial>` — emulator fully gone. Nothing wiped.

## Honest gaps / notes
1. Features changed in v0.2 source but NOT functionally exercised in this proof: long-press → App-info, the search "No apps match" empty view, and the updated Tree panel text. What was exercised: build/badging, install, persistent-home set + three read-backs, the Home-key functional test, crash check, and visual verification of the dock/clock/brand fixes.
2. `firstInstallTime` in dumpsys reads 2026-11-07 04:24:22 — the v0.1 install time, preserved by `install -r` upgrading in place on the same AVD data (expected; versionCode/minSdk read-backs confirm v0.2 is what is installed).
3. Persistent home was set inside this emulator instance only — the AVD was shut down after proof and launched with -no-snapshot, so the setting does not carry to the next boot. The proof demonstrates the method works and the system honors it; a future run that needs it re-applies the same two commands after install.
4. No source fixes were needed — zero changes to the v0.2 project as delivered.
