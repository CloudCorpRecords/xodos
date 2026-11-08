# TreeOS v0.1 — Build + Emulator Proof Report
Date: 2026-11-07 (America/Los_Angeles)
Host: Razer RENE_HOME_MAIN (Windows 11, user cloud)
Source: ~/workspace/tree-os/treeos.tar.gz (6,711 bytes) — Gradle project, AGP 9.0.1, module :app, plain Java, no project fixes needed

## Build — SUCCESS
Build script written locally first: `build-on-razer.ps1` (also `emulator-proof.ps1` / `emulator-proof2.ps1` / `emulator-proof3.ps1`, see Gaps)
Recipe: JAVA_HOME = Android Studio jbr (OpenJDK 25.0.3), ANDROID_HOME = C:\Users\cloud\AppData\Local\Android\Sdk, gradle-9.1.0 `gradle :app:assembleDebug --console=plain`
Result: `BUILD SUCCESSFUL in 45s`, 32 actionable tasks executed, build exit 0. Only note: MainActivity uses a deprecated API (onBackPressed) — compiles fine.

### APK verification (aapt2 badging, build-tools 36.0.0)
- Package: `dev.treeos.launcher` ✅
- versionName: `0.1.0`, versionCode `1` ✅
- Label: `TreeOS` ✅
- Launchable activity: `dev.treeos.launcher.MainActivity`, provides-component: launcher
- minSdk 29 / targetSdk 34 / compileSdk 35
- Razer APK path: `C:\Users\cloud\treeos\project\app\build\outputs\apk\debug\app-debug.apk` (copied to `C:\Users\cloud\treeos\treeos-0.1.0-debug.apk`)
- Size: **2,452,486 bytes**
- SHA256: **cb748aefd362cd326e34249049ab34265937a233497b1bbadafe51b771f37573**
- VM copy: [treeos-0.1.0-debug.apk](sandbox://workspace/tree-os/apks/treeos-0.1.0-debug.apk) — sha256 re-verified on the VM, identical.

## Emulator proof — SUCCESS
AVD: `Medium_Phone_API_37.0` on the Razer, headless, detached WMI Win32_Process.Create launch with `-no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect` (ProcessId 79592, ReturnValue 0).
All adb commands in the successful run were explicitly targeted `-s emulator-5554` (see Gaps).
- Boot: `sys.boot_completed=1` — poll 0 on the final run (emulator already booted from the first launch; ~90s typical from cold)
- Install: `adb -s emulator-5554 install -r` → **"Performing Streamed Install / Success"** ✅ (seen in both proof runs v2 and v3)
- Launch: plain start, NOT set-home-activity — `adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity` → `Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.HOME] cmp=dev.treeos.launcher/.MainActivity }`
- Alive check: `pidof dev.treeos.launcher` = **4431**, same pid on re-check 4+ seconds later
- Top activity: `topResumedActivity=ActivityRecord{... u0 dev.treeos.launcher/.MainActivity t27}`, ResumedActivity and mFocusedApp also TreeOS
- Crash check: logcat scan **FATAL_COUNT=0** — no FATAL EXCEPTION anywhere in the dump, no AndroidRuntime crash for our package

### Screenshots
- [emu-treeos-1.png](sandbox://workspace/tree-os/shots/emu-treeos-1.png) — 341,589 bytes, 1080x2400, sha256 6e87f1c6607d92f17b5a6172a380b6328f1321af695800499517968c2dbcb4b4
- [emu-treeos-2.png](sandbox://workspace/tree-os/shots/emu-treeos-2.png) — 341,589 bytes, identical sha256 (same static frame, taken ~4s apart; clock had not ticked a minute)

What they show (visually verified): dark-green TreeOS home screen — "🌳 TreeOS • 0.1" branding at top, large clock **4:27**, "Sat, Nov 7 • 🔋 100%", "Search apps" bar, a 4-column app grid with 24 real apps (Calendar, Camera, Chrome, Clock, Contacts, Drive, Files, Ganjuko, Gemini, Gmail, Google, Maps, Messages, Phone, Photos, Play Store, rdrive, Safety, Settings, TMoble, Xod, Xod Survivors, YouTube, YT Music), and the bottom dock: Phone / Texts / Web / Camera / Tree / Settings.

### Shutdown — CLEAN
`adb -s emulator-5554 emu kill` → "OK: killing emulator, bye bye / OK". `adb devices` afterwards lists only the two real devices — emulator-5554 gone. Nothing wiped.

## Honest gaps / notes
1. **First proof attempt (v1) failed safely, nothing installed anywhere wrong:** plain `adb` was ambiguous because the Razer also has a real phone attached (USB `<real-phone-serial>` + Wi-Fi `adb-RFAX51PLLDE-...`). v1 was killed during boot polling; v2/v3 target `-s emulator-5554` on every command. Per instructions, no real phone was installed on, and the Poco was not touched.
2. **v2 launch bug (script only, not the app):** a PowerShell wrapper function mangled the `-a/-c` flags on `am start`. v3 uses direct adb calls and launched cleanly. No project source files were changed — zero fixes to `~/workspace/tree-os/project/` were needed.
3. **Not set as the default home launcher persistently** — proof used a plain HOME-intent start of MainActivity (task allowed this). `cmd package set-home-activity` was not run.
4. **Both screencaps are byte-identical** — expected for a static home screen within the same minute, and pid/top-activity were re-verified between them, but they are not two visually distinct frames.
5. Cosmetic: dock labels "Camera" and "Settings" wrap to two lines in the screenshot. App label "TMoble" is the emulator image's own app label, not ours.
6. Emulator GPU was swiftshader_indirect; native Android UI rendered correctly (the GLES3 shader limit seen with Godot on 2026-11-05 does not apply here).
