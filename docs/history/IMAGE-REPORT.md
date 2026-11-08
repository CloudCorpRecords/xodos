# TreeOS OS-Image Lane — Phase 1 Report (Remaster)
Date: 2026-11-07 (America/Los_Angeles)
Host: Razer RENE_HOME_MAIN (Windows 11, user cloud)
Input APK: `treeos-0.2.0-debug.apk` — dev.treeos.launcher v0.2.0, minSdk 28, 2,453,754 bytes, sha256 `9e249eab93933823e8eeff24237594feacc7f5264886dded09ed5d0122e301b2` (re-verified on the Razer copy, identical)
Scripts (VM + Razer `C:\Users\cloud\treeos-image\`): `image-inventory.ps1`, `image-props-playstore.ps1`, `image-findtools.ps1`, `image-get-tools.ps1` (superseded), `image-get-tools2.ps1` (superseded), `image-get-tools3.ps1`, `image-cleanup.ps1`, `image-create-avd.ps1`, `image-remaster.ps1` (v1, flawed), `image-kill-remaster.ps1`, `image-remaster2.ps1` (v2), `image-persist-bootanim.ps1` (W2), `image-launch-detached.ps1`

## Verdict — PHASE 1 SUCCESS (with one structural caveat, stated plainly)
A new AVD **TreeOS_Phone** was created from a rootable google_apis image, remastered with `-writable-system`, and TreeOS now lives in the image as a **system priv-app** at `/product/priv-app/TreeOS/TreeOS.apk`, set as the default HOME, and **persists across reboots and across a full emulator relaunch with no install/push/set-home commands** — as long as the AVD is launched with `-writable-system` (the mode the remaster lives in). A plain launch *without* that flag boots the pristine stock image instead; removing that flag-dependence is precisely Phase 2's packaging job (see Gaps). Boot animation was also replaced and verified in place after a reboot (stretch goal).

Safety: the shared `Medium_Phone_API_37.0` AVD was **not** modified (only booted read-only-style for getprop, then killed). Every adb command in every script was targeted `-s emulator-5554`. The real phone attached to the Razer (`<real-phone-serial>`) was never installed on, pushed to, or otherwise touched. Final `adb devices` after clean shutdown: only `<real-phone-serial>`.

---

## STEP A — Inventory (read-only)

### Existing AVD: Medium_Phone_API_37.0
From `C:\Users\cloud\.android\avd\Medium_Phone.avd\config.ini`:
- `image.sysdir.1 = system-images\android-37.0\google_apis_playstore\x86_64\`
- `tag.id = google_apis_playstore`, `tag.display = Google Play`, `PlayStore.enabled=true`
- `abi.type = x86_64`, `hw.device.name = medium_phone`, skin 1080x2400, data partition 10G

### SDK system-images inventory (complete — only ONE image installed)
- `system-images\android-37.0\google_apis_playstore\x86_64\` — Pkg.Revision 7, ApiLevel 37.0, TagId `google_apis_playstore`, "System Image x86_64 with Google Play", system.img 2,704,277,504 B, vendor.img 72,351,744 B, ramdisk.img 1,639,867 B
- No google_apis (non-Play) image, no other API level. **No rootable image was installed locally.**
- Also missing: **no cmdline-tools at all** — no `sdkmanager.bat`, no `avdmanager.bat` anywhere under the SDK or Android Studio (SDK root contains only build-tools, emulator, licenses, platform-tools, platforms, system-images). Android Studio JBR java present.
- Razer C: free before work: 156,520,153,088 bytes (~145.8 GiB).

### Candidate boot #1 — the existing Play Store image (documented, rejected)
Booted Medium_Phone_API_37.0 headless (WMI, `-no-snapshot`), read at `sys.boot_completed=1`:
- `ro.build.type = user`
- `ro.build.flavor = sdk_gphone64_x86_64-user`
- `ro.build.tags = release-keys`
- `ro.build.version.sdk = 37`, release 17, abi x86_64
- `ro.debuggable = 0`, `ro.secure = 1`
- `adb root` → **`adbd cannot run as root in production builds`**; `whoami` stayed `shell`.
→ Not rootable, exactly as suspected for Play Store images. Rejected as remaster base.

### Tooling fix — sdkmanager obtained, rootable image installed
The Razer had no sdkmanager, so Google's commandline tools were downloaded from dl.google.com (`commandlinetools-win-11076708_latest.zip`). This took three attempts, documented honestly in Gaps: the working path was curl.exe with retries to a fresh filename, fully detached on the Razer. Result:
- Installed to `Sdk\cmdline-tools\latest\`; `sdkmanager --version` = **12.0**
- Installed **`system-images;android-35;google_apis;x86_64`** — Pkg.Desc "System Image x86_64 with Google APIs", Pkg.Revision 9, ApiLevel 35, TagId `google_apis`, system.img 3,576,692,736 B, vendor.img 116,391,936 B, ramdisk.img 2,154,591 B.

### Candidate boot #2 — the google_apis image (chosen)
First plain boot of TreeOS_Phone (below), read at boot_completed:
- `ro.build.type = userdebug`
- `ro.build.flavor = sdk_gphone64_x86_64-userdebug`
- `ro.build.tags = dev-keys`
- `ro.build.version.sdk = 35`, release 15, abi x86_64
- `ro.debuggable = 1`, `ro.secure = 1`
→ Rootable profile confirmed (`adb root` later verified: `whoami = root`).

## AVD created — TreeOS_Phone
Via the newly installed avdmanager: `avdmanager create avd -n TreeOS_Phone -k "system-images;android-35;google_apis;x86_64" -d medium_phone --force` → exit 0, appears in `emulator -list-avds` alongside (untouched) Medium_Phone_API_37.0. Its config.ini reads back:
- `image.sysdir.1 = system-images\android-35\google_apis\x86_64\`
- `tag.id = google_apis`, `tag.display = Google APIs`, `PlayStore.enabled = no`
- `abi.type = x86_64`, `hw.device.name = medium_phone`

---

## STEP B — Remaster

### Attempt v1 — FAILED safely, root cause found in its own log (no false success)
Flow error, mine: `adb remount` output was *"Successfully disabled verity … Using overlayfs for /system, /vendor, /product … **Now reboot your device for settings to take effect**"*, mounts stayed `ro`, and the script pushed immediately → `/product/priv-app/TreeOS: Read-only file system`. A second bug compounded it: the push check matched the string `TreeOS.apk` inside an *error* message and falsely set `DEST_USED`. The run was killed mid-flight (script + emulator), the log preserved, and **nothing was claimed from v1**. (The verity-disabled state v1 created did persist and made v2's first remount succeed immediately.)

### Attempt v2 — corrected flow, SUCCESS (`image-remaster2.ps1`, detached WMI launch, log `remaster2.log`)
Boot TreeOS_Phone with `-writable-system` (WMI detached, `-no-snapshot -no-audio -gpu swiftshader_indirect`):
- `adb root` → `restarting adbd as root`; `whoami = root` (both rounds)
- `adb remount` → **`Remounted /system as RW / /vendor / /product / /system_dlkm / /system_ext — Remount succeeded`** (both rounds, with the scripted reboot between them so verity/overlayfs took effect)
- RW probe: `touch /product/priv-app/.rwtest` → **RW_TEST /product/priv-app = True**
- Push: `adb push TreeOS.apk /product/priv-app/TreeOS/TreeOS.apk` → 1 file pushed, **push_exit=0**, on-device `stat -c %s` = **2453754 — byte-exact** (strict check, not a string match); `chmod 644` applied
- `DEST_USED=/product/priv-app/TreeOS/TreeOS.apk` (the /product path worked; the /system fallback was not needed)

### Verification after push + reboot (same writable session)
- **`pm path dev.treeos.launcher` → `package:/product/priv-app/TreeOS/TreeOS.apk`** ✅ (under /product, NOT /data/app)
- `dumpsys package`: `codePath=/product/priv-app/TreeOS`, **`flags=[ SYSTEM DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]`** ✅ — a genuine system app
- Set home (as in v0.2 proof): `cmd package set-home-activity dev.treeos.launcher/.MainActivity` → **Success**; `cmd role add-role-holder android.app.role.HOME dev.treeos.launcher` → exit 0
- Read-backs: `cmd role get-role-holders android.app.role.HOME` → **`dev.treeos.launcher`**; `cmd package resolve-activity --brief … HOME` → `isDefault=true` + `dev.treeos.launcher/.MainActivity`
- `topResumedActivity = dev.treeos.launcher/.MainActivity`; `pidof` = 1445; logcat **FATAL_COUNT=0**

### Persistence proof #1 — in-instance reboot, no writes
`adb reboot` (no install/push/set-home), re-read: `pm path` still `/product/priv-app/TreeOS/TreeOS.apk`, HOME role holder still `dev.treeos.launcher`. ✅

### Persistence proof #2 — full relaunch, NO TreeOS writes (`image-persist-bootanim.ps1`, first half)
Emulator killed, TreeOS_Phone relaunched fresh with `-writable-system`, and with **no install, no push, no set-home commands** (only display-wake settings so the screencap wouldn't be a black frame — see Gaps):
- `pm path` → `package:/product/priv-app/TreeOS/TreeOS.apk` → **RELAUNCH_PRIVAPP=PASS**
- `flags=[ SYSTEM … ]` read back again; HOME role holders → `dev.treeos.launcher`; resolve-activity HOME → `isDefault=true`, TreeOS
- Functional test: opened Settings, pressed **KEYCODE_HOME** → `topResumedActivity = dev.treeos.launcher/.MainActivity` → **RELAUNCH_HOME_TOP=PASS**, pid 1429 alive
- Screenshot: [emu-treeos-image-1.png](sandbox://workspace/tree-os/shots/emu-treeos-image-1.png) ✅

### Persistence counter-check — plain launch WITHOUT `-writable-system` (expected limitation, proven)
Same AVD relaunched with no flag: `pm path` empty (**PLAIN_RELAUNCH_PRIVAPP=MISS**), HOME role fell back to `com.google.android.apps.nexuslauncher`, top activity NexusLauncher. This is the emulator's overlay semantics: `-writable-system` changes live in the AVD's writable overlay and are only applied when booting in that mode. **Launching TreeOS_Phone = launching it with `-writable-system`** in Phase 1. Making the OS boot with no special flag is exactly Phase 2 (package the modified partitions as a standalone SDK system-image) — still to do, as scoped.

### Screenshots (all visually inspected by the lane)
- [emu-treeos-image-1.png](sandbox://workspace/tree-os/shots/emu-treeos-image-1.png) — 272,186 bytes, 1080x2400, sha256 `bcf1f907068f2626887d056e4d585a801837a4328d75fc37936996e010199f5b` — the persistence-proof frame from the fresh writable relaunch: dark-green TreeOS home, "🌳 TreeOS • 0.2", clock **11:12 AM**, "Sat, Nov 7 • 🔋 100%", Search apps bar, and the app grid of the **API-35 google_apis image's own apps** (Calendar, Camera, Chrome, Clock, Contacts, Drive, Files, Gmail, Google, Maps, Messages, Phone, Photos, Safety, Settings, SIM Toolkit, Voice Search, YouTube, YT Music — visibly a different OS image from Medium_Phone's grid: no Ganjuko/Xod/rdrive), dock Phone/Texts/Web/Cam/Tree/Setup all single-line.
- [emu-treeos-image-2.png](sandbox://workspace/tree-os/shots/emu-treeos-image-2.png) — 257,184 bytes, 1080x2400, sha256 `e2cff046c3d3d89669a297d13b871b9e73a09868c4f196a79ea4e51bf596990c` — same TreeOS home at 11:14 AM **after the boot-animation reboot** (BOOTANIM_BOOT_HOME=PASS).
- `emu-treeos-image-0-black.png` (15,580 bytes) — kept for honesty: the first screencap attempt in the remaster session was a pure black frame because the fresh AVD's display had fallen asleep; the activity/pid/flags read-backs from that moment were valid, but the frame itself was useless and was superseded by the wake-controlled screenshots above.

### STRETCH — boot animation replaced ✅
Generated a minimal valid bootanimation.zip on the VM (540x1200 @12fps, `desc.txt` + `part0/` with 6 STORED PNG frames: the TreeOS tree icon growing in over the dark-green background, "TreeOS / by Rene + Tree" text; 87,028 bytes, all entries ZIP_STORED). In a clearly separated second half of the W2 run (after all persistence proofs were captured):
- `adb root` + `adb remount` → Remount succeeded; `adb push` → 1 file pushed, exit 0; on-device `stat -c %s /system/media/bootanimation.zip` = **87028, byte-exact**; `ls -l` → `-rw-r--r-- 1 root root 87028 … /system/media/bootanimation.zip` (chmod 644 applied)
- Rebooted: boot completed, `ls -l` shows the file **still in place**, `pm path` still the priv-app path, HOME key → TreeOS on top (**BOOTANIM_BOOT_HOME=PASS**), final screenshot image-2 above.
- Caveat: playback of the animation mid-boot was not (and per the task, could not easily be) screenshot-verified; what is proven is correct placement, format, permissions, and a clean boot to TreeOS home with it in place. Like the rest of the remaster, it lives in the writable overlay (same Phase 2 caveat).

### Shutdown — CLEAN
Every session ended with `adb -s emulator-5554 emu kill` → "OK: killing emulator"; final `adb devices` lists only the real phone `<real-phone-serial>`. Nothing wiped, Medium_Phone AVD untouched.

---

## Honest gaps / notes
1. **Flag-dependence (the big one):** the remastered OS boots when TreeOS_Phone is launched with `-writable-system`; a flagless launch boots pristine stock Android (proven above). Phase 1 therefore delivers a *remastered AVD in its writable mode*, not yet a flag-independent image. **Phase 2 remains, as expected:** capture the modified partitions and package them as `system-images/android-35/treeos/x86_64/` so a fresh AVD + `-wipe-data` boots TreeOS with no flags and no adb writes at all.
2. **Download detour:** the first cmdline-tools download over a foreground SSH session died with the session (broken pipe, 13MB partial). The detached Invoke-WebRequest retry then raced a still-alive PowerShell from attempt 1 that kept writing the same zip (file lock, curl write error) — both stray processes were identified by command line and killed, and the third attempt (curl, fresh filename, detached) completed cleanly. No impact on the result; all Razer-side work after that point ran detached with log files, which is the right pattern for this host.
3. **v1 script bugs (mine):** remount's reboot requirement was not handled, and the push-success check string-matched an error message. v1 was killed, nothing was claimed from it, and v2 used exit codes + on-device byte-size equality + an RW touch-test instead.
4. **W2 display settings:** the persistence relaunch (proof #2) ran three display-only settings (`stay_on_while_plugged_in`, `screen_off_timeout`, `svc power stayon`) so the screencap would be lit. No install/push/set-home/role command was run in that session before the read-backs — the TreeOS presence and HOME default it verified were entirely from the remaster. These display settings live in /data and are test-harness cosmetics, not part of the OS image claim.
5. The HOME role read-back in proof #2 was taken *without* re-running set-home, but note the role state itself lives in /data (it survived because the package it points to survived as a system app; on the flagless boot, with the package gone, the role cleanly fell back to NexusLauncher — consistent, and further evidence the priv-app is what carries the claim).
6. Boot animation playback not visually verified mid-boot (per task's own note). Format is spec-conformant (STORED entries, desc.txt first) and the device boots cleanly with it.
7. First boot of the fresh AVD was slow (~44 polls ≈ 4 min); subsequent boots ~1 min. Emulator GPU was swiftshader_indirect throughout; native UI rendered correctly.

---

# Phase 2 Report — Standalone TreeOS system image (flag-independence)
Date: 2026-11-07 (America/Los_Angeles) · Host: Razer RENE_HOME_MAIN · Scripts: `phase2-*.ps1` in this folder and on the Razer at `C:\Users\cloud\treeos-image\` (work dir `C:\Users\cloud\treeos-image\p2work\`, logs there: `convert2.log`, `buildsysdir.log`, `proof-final.log`, `finish.log`, `diag2.log`, `kernel-console.log`)

## Verdict — PARTIAL SUCCESS (read carefully; two different claims)
1. **Standalone image: DONE.** The Phase 1 writable overlay was converted into a real SDK system-image at `system-images\android-35\treeos\x86_64\`, a new AVD **TreeOS_Image** was created from it, and that AVD **boots to `sys.boot_completed=1` on a plain launch with `-wipe-data` and NO `-writable-system`** — the flag dependence is removed at the image level. Both remastered files are present in the flagless boot with byte-exact sizes (`/product/priv-app/TreeOS/TreeOS.apk` 2,453,754 B — pulled back out and sha256-identical to the original APK; `/system/media/bootanimation.zip` 87,028 B). Getting the plain boot to work at all required solving an AVB problem the Phase 1 mode had been masking (below).
2. **TreeOS as the booted OS face: NOT achieved yet.** On the plain boot, PackageManager **refuses to parse the priv-app** (`Failed to open APK … File mapping failed` → `Failed to parse /product/priv-app/TreeOS`), so `dev.treeos.launcher` is never registered, never appears among HOME candidates, and the stock NexusLauncher comes up instead. The screenshot for this phase therefore shows the stock home running on the TreeOS image — **no flagless TreeOS-home success is claimed.** Root-cause evidence and the precise next route are at the end. Safety held throughout: every adb call targeted `-s emulator-5554`; `adb devices` after every shutdown listed only the real phone `<real-phone-serial>` (never touched); TreeOS_Phone and Medium_Phone AVDs unmodified.

## STEP 1 — AVD inventory (TreeOS_Phone)
`%USERPROFILE%\.android\avd\TreeOS_Phone.avd` (full listing in `phase2-inventory.log`):
- `system.img.qcow2` 10,551,296 B — the writable overlay carrying ALL Phase 1 changes; `qemu-img info --backing-chain`: backing file = stock `system-images\android-35\google_apis\x86_64\system.img`, format raw, virtual size 3,576,692,736 B, only 154/54576 clusters allocated (0.28%), `qemu-img check` clean
- `vendor.img.qcow2` 197,120 B (empty header only) · `userdata-qemu.img.qcow2` 4,546,494,464 B · `cache.img.qcow2` 197,120 B · `encryptionkey.img.qcow2` 2,752,512 B · snapshot `snapshots\default_boot\ram.img` 2,684,420,096 B
- Tooling: `qemu-img.exe` IS shipped (`Sdk\emulator\qemu-img.exe`); **no `img2simg`/`simg2img` anywhere in the SDK — and none was needed**: the stock `system.img`/`vendor.img` are **raw GPT disk images** (header check: zeros + `EFI PART` at LBA1, qemu-img format `raw`), not Android sparse. A sysdir of raw images is exactly what the emulator ships and boots.
- Disk layout of the system image (GPT, parsed from the merged image): just two partitions — `vbmeta` (LBA 2048–4095, 1 MiB) and `super` (LBA 4096–6983679, 3,573,547,008 B). **There is no separate product.img**: `/system`, `/product`, `/system_ext` etc. are logical partitions inside `super`, so the single merged `system.img` carries both Phase 1 changes (priv-app in product, bootanimation in system). Vendor was merged too as a control.

## STEP 2 — Conversion (qcow2 chain → raw)
Commands (Razer): `qemu-img convert -O raw TreeOS_Phone.avd\system.img.qcow2 p2work\system-merged.raw` (same for vendor).
- `system-merged.raw`: 3,576,692,736 B, sha256 `BCEB52DA1F239B887E64CD6257900C99B78717AD23B06308661DC65D9000C933`
- A second clean convert (`system-merged2.raw`) produced the **identical sha256** — conversion is deterministic and the file is complete.
- `vendor-merged.raw`: 116,391,936 B, sha256 `C95A4C23D44E2A4FFBF0BAB7B7BB37CAFDF3B390079A30CE1B4950536A17D0D5` = **stock vendor.img exactly** (stock system.img for comparison: `C06A5966E70BB34645E68E7FE0038ED4396BAD30E7A378DBDBB1C26D6A351171` ≠ merged, confirming the system disk is the one that changed).

## STEP 3 — New SDK sysdir `system-images\android-35\treeos\x86_64\`
Full stock file set copied (kernel-ranchu, ramdisk.img, vendor.img, encryptionkey.img, build.prop, `data\…`, VerifiedBootParams.textproto, package.xml), with `system.img` replaced by the merged image. `source.properties` rewritten honestly: `Pkg.Desc=System Image x86_64 with TreeOS (remastered from Google APIs image)`, `AndroidVersion.ApiLevel=35`, `SystemImage.TagId=treeos`, `SystemImage.TagDisplay=TreeOS`, `Addon.VendorId=treeos` (kept `Pkg.Dependencies=emulator#33.1.24`).
`package.xml` also had to be re-identified (stock copy → backup `package.xml.stock-backup` kept in place): its `localPackage path`, `<tag>` and `<vendor>` still said `google_apis`, which made sdkmanager treat the folder as a misplaced duplicate and avdmanager reject the package (`Package path is not valid`, first attempt). After literal replacement to `system-images;android-35;treeos;x86_64` / tag+vendor `treeos`, the package is accepted as its own SDK package.

## STEP 4 — AVD TreeOS_Image
`avdmanager create avd -n TreeOS_Image -k "system-images;android-35;treeos;x86_64" -d medium_phone --force` → **exit 0**. Read-back of `TreeOS_Image.avd\config.ini`: `image.sysdir.1=system-images\android-35\treeos\x86_64\`, `tag.id=treeos`, `tag.display=TreeOS`, `PlayStore.enabled=no`, `abi.type=x86_64`, `hw.device.name=medium_phone`. `emulator -list-avds` = Medium_Phone_API_37.0, TreeOS_Image, TreeOS_Phone (others untouched).

## STEP 5a — Plain boot FAILS first: AVB (root-caused from the guest kernel log, not guessed)
First plain `-wipe-data` launches never finished booting: the emulator stayed `offline` in adb with qemu burning CPU (bootloop). A `-show-kernel` launch (`kernel-console.log`) captured first-stage init dying at ~4 s:
```
init: [libfs_avb] ERROR_VERIFICATION / PUBLIC_KEY_REJECTED isn't allowed
init: Failed to open AvbHandle … Failed to setup verity for '/system' … Failed to mount /system
init: Failed to mount required partitions early … InitFatalReboot … reboot 'bootloader'
```
Forensics with avbtool (fetched from AOSP googlesource, run on the VM against the extracted 1 MiB vbmeta partition): stock vbmeta flags **0**, signature verifies; Phase 1's merged vbmeta flags **1** (Phase 1's `adb disable-verity` had flipped HASHTREE_DISABLED) and its **signature check FAILS** — any byte change breaks the RSA signature, and the sysdir's stock `VerifiedBootParams.textproto` still carried the stock vbmeta digest. Phase 1 never hit this because `-writable-system` boots with veritymode disabled and init skips libfs_avb entirely; a plain boot enforces, so both the content changes and the tampered vbmeta are rejected in locked state. (My intermediate step of patching vbmeta flags to 3 in the image — new system.img sha256 `DD53732D51899A6F43065632D33FA6210B144BA8D2A07D14B6952EB02B7BB602` — was necessary but not sufficient: signature/digest are still invalid in locked state.)
**Fix that worked — present the image as an unlocked device, in the image's own boot params.** The sysdir copy of `VerifiedBootParams.textproto` (stock values preserved; pre-change copies in `p2work\VerifiedBootParams.stock-backup` / `.before-unlock`) gained three params, all standard cmdline items the emulator forwards verbatim:
```
param: "androidboot.vbmeta.device_state=unlocked"
param: "androidboot.flash.locked=0"
param: "androidboot.verifiedbootstate=orange"
```
With those, libfs_avb treats verification errors as non-fatal (the standard unlocked/orange-state behavior), the vbmeta's flags=3 disables hashtree + verification, and the guest boots. Diagnostic boot reached adbd `device` state (previously stuck `offline`) and `sys.boot_completed=1` at poll 26. Honest framing: this is the emulator equivalent of an unlocked-bootloader build — appropriate for our own OS image, and it is *part of the image package* (a sysdir file), not a launch flag.

## STEP 5b — Plain-launch `-wipe-data` proof runs (final sysdir state as above)
Run 1 (`proof-final.log`): launch `emulator -avd TreeOS_Image -no-snapshot -no-audio -gpu swiftshader_indirect -wipe-data` (WMI detached; **no `-writable-system`, no install/push/set-home before read-backs**) → **BOOT OK at poll 45**, flavor `sdk_gphone64_x86_64-userdebug`, release 15. Read-backs before any set-home:
- `ls -l /product/priv-app/TreeOS/TreeOS.apk` → **2,453,754 B** ✅ and `/system/media/bootanimation.zip` → **87,028 B** ✅ (both Phase 1 changes, in the image, flagless)
- `pm path dev.treeos.launcher` → **empty**; `dumpsys package` → nothing (see 5c)
- HOME role holder → `com.google.android.googlesdksetup` (the Google setup wizard owns HOME on a fresh wipe until provisioning completes); top activity = its DefaultActivity; `set-home-activity` in that state → `Error: Failed to set default home.`
- logcat FATAL count = 0 · screenshot pulled (stock-frame, see below) · `emu kill` clean; final `adb devices` = `<real-phone-serial>` only.
Run 2 (`finish.log`, same plain+wipe recipe): BOOT OK at poll 34; provisioning harness (`settings put global device_provisioned 1`, `secure user_setup_complete 1` — runtime /data settings, not image state) moved the HOME role `googlesdksetup → nexuslauncher`, but `pm path` polled 36× over ~4 min stayed empty, set-home still failed, pidof TreeOS empty, FATAL_COUNT=0, clean shutdown.
Run 3 — DIAG2 (`diag2.log`, plain+wipe, read-only): BOOT OK at poll 45; `pm list packages -s` = 241 packages, **none matching tree**; HOME candidates per PM = googlesdksetup, nexuslauncher, Settings FallbackHome (TreeOS absent).

## STEP 5c — Why the priv-app doesn't register (evidence, not speculation)
- **Content is perfect:** diag2 pulled `/product/priv-app/TreeOS/TreeOS.apk` back out of the flagless boot: **sha256 `9E249EAB93933823E8EEFF24237594FEACC7F5264886DDED09ED5D0122E301B2` — byte-identical to the original TreeOS v0.2 APK**, 2,453,754 B. SELinux context is correct (`u:object_r:system_file:s0`, same as stock neighbors); APK mode 644 (the TreeOS *directory* is mode 777 `drwxrwxrwx`, unlike stock 755 dirs — noted, but world-readable/executable, so not a read blocker).
- **PM's own words (logcat, first-boot scan):**
  ```
  E system_server: Failed to open APK '/product/priv-app/TreeOS/TreeOS.apk': File mapping failed
  W PackageManager: Failed to parse /product/priv-app/TreeOS: Failed to parse /product/priv-app/TreeOS/TreeOS.apk
  ```
- Interpretation: the Phase 1 remaster wrote through Android's **remount overlayfs**, whose upper layer lives in `super`'s **scratch** logical partition (the kernel log shows `scratch` created as dm-5 at every boot). The qcow2→raw conversion faithfully captured that stacked state — regular reads (ls, adb pull, sha256) work — but PackageManager's first-boot parse mmaps the APK through that overlay/scratch path and the mapping fails, so the package is skipped. In Phase 1's writable boots the same content parsed, because the overlay there was established by a live `adb remount` session in that same boot. The defect is in **how the changes are stored in the captured image**, not in the APK and not in the packaging/boot path (both now proven).
- Consequence for the "default home" question: it is **downstream** of registration. The role machinery itself is fine (Phase 1 proved set-home + role + Home-key on a registered package, and Run 2 above shows the role moving normally between registered holders). Any default-home-in-image config work only becomes testable once the package registers.

## Screenshot (as required — and honestly labeled)
[emu-treeos-image2-1.png](sandbox://workspace/tree-os/shots/emu-treeos-image2-1.png) — 1,374,870 B, 1080×2400, sha256 `54e1144e23683730aea84dc52b56f61917ad588ff47ed4987968b5028a1cc779`, visually inspected: **the stock NexusLauncher home** (Sat, Nov 7 · Gmail/Photos/YouTube · Google search bar) on the flagless TreeOS-image AVD after provisioning + Home key — i.e. the OS image booting with the stock face because TreeOS isn't registered yet. The other wipe-boot frame (`emu-treeos-image2-wizard.png`, 1,310,839 B) shows the same stock home with its long-press menu from Run 1. No TreeOS-home screenshot exists for Phase 2 and none is implied.

## Honest gaps / next route
1. **Remaining blocker (precise):** TreeOS must be written into the product filesystem **natively**, not through the remount overlay. Route: offline ext4 surgery on the Linux VM — the merged `system.img` is already byte-faithful, so: split GPT, extract `super`, `lpunpack` it, write `TreeOS.apk` into the product ext4 with `debugfs -w` (no mount needed; set mode 644 / dir 755), also drop a privapp-permissions XML for `dev.treeos.launcher` into product etc, repack with `lpmake`, reassemble the GPT image, refresh the sysdir copy. Tooling needed on the VM: lpunpack/lpmake (AOSP host tools — fetch prebuilts or build tiny; ~57 GB free is ample, everything operates on the 3.5 GB image). The vbmeta/unlock-params state stays as-is (flags=3 + orange state) — content digests in descriptors are already non-enforced in this state.
2. After registration works, default-home-after-wipe still needs its own in-image answer (setup wizard holds HOME during provisioning): candidates are a SettingsProvider product overlay with `def_device_provisioned=true`, or accepting setup completion as part of first boot. Untested until (1) lands — do not conflate the two gaps.
3. Bootanimation: file proven in place in the flagless image (87,028 B at `/system/media/bootanimation.zip`); mid-boot playback still not visually captured (same caveat as Phase 1).
4. Detours worth recording: my first combined convert+scan script died on PowerShell parse errors after its qemu-img convert had actually completed (collision on re-run proved it: an independent re-convert hashed identically — no data was ever at risk); one `$pid` variable bug in the first proof script (PowerShell's read-only `$PID`) hid a pidof read-back — fixed in later scripts, and the affected verdicts were re-derived from dumpsys/logcat instead. Razer free space after all work: ~134 GB (two 3.5 GB raw copies + sysdir + AVD userdata are the bulk; `p2work\system-merged.raw` and the sysdir image are the keepers, `system-merged2.raw`/`system-vb3.raw` are spares that can be deleted).
5. Phase 1's TreeOS_Phone is untouched and still offers the writable-mode TreeOS experience; Phase 2 adds TreeOS_Image + the treeos sysdir alongside it. Nothing about the real phone (`<real-phone-serial>`) was read or written at any point.

---

# Phase 2b Report — Native ext4 surgery: the priv-app REGISTERS on a plain boot
Date: 2026-11-07 (America/Los_Angeles) · Surgery host: this Linux VM (`~/workspace/tree-os/image-surgery/`: `lpmeta.py`, `logs/`, `work/`) · Proof host: Razer RENE_HOME_MAIN (scripts `phase2b-ship.ps1`, `phase2b-proof.ps1` in this folder and on the Razer at `C:\Users\cloud\treeos-image\p2work\phase2b\`; console log pulled back to `image-surgery/logs/phase2b-proof-console.log`, guest logcat to `image-surgery/logs/phase2b-logcat.txt`) · Content spec: `docs/CONTENT-MANIFEST.md`

## Verdict — SUCCESS (the Phase 2 blocker is closed)
The standalone TreeOS image was rebuilt with TreeOS written **natively** into the stock filesystems (no remount overlay anywhere in its lineage), shipped to the treeos sysdir, and AVD **TreeOS_Image booted PLAINLY with `-wipe-data`** (WMI detached, NO `-writable-system`, no install/push/set-home before read-backs): **`pm path dev.treeos.launcher` returned `package:/product/priv-app/TreeOS/TreeOS.apk` on the very first poll**, dumpsys flags include **SYSTEM**, logcat contains **zero** `Failed to parse` / `File mapping failed` for our APK, set-home + HOME-role read-back pass, Settings → KEYCODE_HOME lands back on TreeOS, FATAL_COUNT=0, and the screenshot — [emu-treeos-image2b-1.png](sandbox://workspace/tree-os/shots/emu-treeos-image2b-1.png) — shows the **TreeOS home on the flagless boot** (the frame Phase 2 could not produce). Safety: every adb call targeted `-s emulator-5554`; final `adb devices` after clean `emu kill` = only the real phone `<real-phone-serial>` (never touched); TreeOS_Phone, Medium_Phone and the stock google_apis sysdir are unmodified; the Phase 2a sysdir image is preserved at `system.img.phase2a-backup` (see below). Razer route coordination: this lane held the lane-board heavy claim `treeos-phase2b` on `razer-route` from the sysdir replace through the proof (claim rule landed mid-lane; the earlier bulk transfers predate it).

## Base choice — from STOCK, not from the Phase 2 merged raw (and why)
Phase 2's `system-merged.raw` (sha256 `BCEB52DA…C933`, still on the Razer at `p2work\system-merged.raw`) faithfully captures the overlay-stacked state — its LP super contains the remount **scratch** logical partition holding the overlay upper layer; building on it risked inheriting exactly the storage layout that broke PM's mmap parse. The **stock** `system-images;android-35;google_apis;x86_64` `system.img` (3,576,692,736 B, sha256 `C06A5966E70BB34645E68E7FE0038ED4396BAD30E7A378DBDBB1C26D6A351171`, re-verified on the Razer and again on the VM after transfer) has pristine filesystems and known-clean LP metadata, and everything TreeOS adds is fully specified, so a from-stock native build loses nothing and starts from a provably clean base. Transfer: Razer-side `tar -czf` (1,627,164,193 B, sha256 `C384C8A0…8D0F`, hash-verified after reassembly from 4 parallel scp streams), extracted on the VM; raw hash matched stock exactly.

## Tooling (what was actually used, honestly)
- **otatools.zip from ci.android.com: attempted, not obtained.** Direct artifact URLs for `aosp_cf_x86_64_phone-userdebug` returned 404 and `aosp_arm64-userdebug` failed to connect over this VM's degraded egress; no apt package provides lpmake/lpunpack either. Per the brief's fallback rule, exactly one alternative was used — and it is not a third-party binary: **`image-surgery/lpmeta.py`, a ~150-line Python-stdlib parser I wrote for this lane implementing the documented AOSP liblp metadata format**, which *validates the SHA-256 checksums of the geometry, header and tables* before trusting any offset, and extracts partitions by concatenating their LINEAR extents (functionally lpdump + lpunpack, read-only). Two constants were initially wrong from memory and were corrected from the image's own bytes with checksum proof (geometry magic `0x616C4467`, header magic `0x414C5030`, descriptor order offset/num_entries/entry_size).
- **debugfs / e2fsck / dumpe2fs (e2fsprogs 1.47.0)** for all filesystem writes — the brief's named tool. No loop mounts exist on this VM (`/dev/loop*` absent), so debugfs was the only route regardless. debugfs write creates mode 0660, so modes were set explicitly via `set_inode_field` (full octal incl. type bits — semantics first proven on a scratch image); SELinux labels were set with `ea_set -f` from a 26-byte value file (`u:object_r:system_file:s0\0`, byte-identical convention to stock neighbors, whose `ea_list` reads `(26) = "u:object_r:system_file:s0\000"`).
- **lpmake was not needed and not used:** no partition changed size, so instead of repacking, the edited partition images were written back **at their exact recorded LP extent offsets** into a copy of the stock GPT image. The final image's LP metadata re-parses **byte-identical to stock** (JSON diff empty), which is stronger than a repack: geometry, groups, slots and checksums are provably untouched.

## LP metadata (recorded from the stock image; unchanged in the final image)
GPT: `vbmeta` LBA 2048–4095 (1 MiB @ file offset 1,048,576), `super` LBA 4096–6983679 (3,573,547,008 B @ 2,097,152). LP geometry: metadata_max_size 65,536, **metadata_slot_count 2**, logical_block_size 4,096; header v10.0, header_size 128, tables_size 540. Groups: `default` (max 0), `emulator_dynamic_partitions` (max 3,565,158,400). Block device `super`: first_logical_sector 2048, alignment 1 MiB, size 3,573,547,008. Partitions — **each a single LINEAR extent, attrs=1 (readonly), group `emulator_dynamic_partitions`**:
| partition | size (B) | extent target_data (sectors) | write-back offset in file (B) |
|---|---|---|---|
| system | 998,658,048 | 2048 | 3,145,728 |
| system_dlkm | 7,213,056 | 1,953,792 | — untouched |
| system_ext | 221,691,904 | 1,968,128 | — untouched |
| product | 2,144,882,688 | 2,402,304 | 1,232,076,800 |
| vendor | 114,139,136 | 6,592,512 | — untouched |

(The LP `vendor` partition above sits inside this system disk image's super and was not touched; the sysdir's separate `vendor.img` file is a different artifact and was likewise never modified.)

## Surgery steps (each stage hashed)
1. **Extract** (via lpmeta.py): `product-stock.img` sha256 `6D96CA62…C7A4`, `system-stock.img` sha256 `CC402D38…7B5`. Both ext4, 4 KiB blocks. Free space before writing: product only 1,552 blocks (6.4 MB — the 2.45 MB APK fits with room; no resize needed), system 16,401 blocks (67 MB).
2. **Product writes** (debugfs -w, on a copy): `mkdir /priv-app/TreeOS` (0755, 0/0, system_file label); `write` the v0.2 APK → `/priv-app/TreeOS/TreeOS.apk`, `set_inode_field mode 0100644` (uid/gid already 0/0), label set; `write` the privapp-permissions XML → `/etc/permissions/privapp-permissions-treeos.xml` (151 B, mode 0644, label set; contents verbatim in `docs/CONTENT-MANIFEST.md` — an empty `<privapp-permissions package="dev.treeos.launcher">` element, no privileged perms granted). Stock `/etc/permissions` already held the goldfish/google privapp files to mirror conventions against.
3. **System writes**: stock has **no** `/system/media` (Phase 1's push had created it in the overlay) → `mkdir /system/media` (0755, label), `write` the Phase 1 bootanimation source zip (`~/workspace/tree-os/bootanimation.zip`, 87,028 B, sha256 `5110137C…9AFB` — the exact Phase 1 file, no regeneration needed) → `/system/media/bootanimation.zip`, mode 0644, label set.
4. **Verify in-image**: `ls`/`stat`/`ea_list` all as intended; files dumped back out and hash-compared — APK `9E249EAB…1B2` (exact), bootanimation `5110137C…9AFB` (exact), XML content exact; `e2fsck -fn` clean on both filesystems. Edited partitions: `product-treeos.img` sha256 `2D1B26D8…AC01`, `system-treeos.img` sha256 `835E3E76…ED9B`.
5. **Reassemble**: fresh copy of stock GPT image; Python write-back of the two partitions at the offsets in the table above (an earlier `dd` attempt with integer-divided 4 MiB seeks overwrote the file head and was **caught by a vbmeta-magic sanity check and discarded** — the corrupted intermediate was deleted unshipped; the shipped image was rebuilt from stock and its vbmeta magic `AVB0` asserted *before* patching). **vbmeta flags patched 0 → 3** at partition offset +120 (same byte patch as Phase 2's vb3 step); the sysdir's Phase 2 `VerifiedBootParams.textproto` (unlocked/orange params) is reused **unchanged** — re-read on the Razer after shipping and still carrying all three params.
6. **Final artifact**: `treeos-system-final.img` — 3,576,692,736 B, sha256 **`216A425BF482791CC77B566C4DF6B621C60D153B0415C874AAE4DB47E04F4BA1`**. End-to-end re-verification from the final file itself: LP dump identical to stock; product/system re-extracted from it hash-match the surgery images; APK dumped from its product partition = `9E249EAB…`.

## Ship to the Razer sysdir (hash-gated)
`phase2b-ship.ps1`: **backup first** — `system-images\android-35\treeos\x86_64\system.img.phase2a-backup` created, 3,576,692,736 B, sha256 `DD53732D…B602` (= the Phase 2a vb3 image, exactly). Upload = tar.gz of the final image (1,629,869,861 B, sha256 `B9C7A3F9…A18`) in 4 parallel scp parts; Razer-side concat → `GZ_HASH=PASS`, extract → `IMG_HASH=PASS`, only then was the sysdir `system.img` replaced; read-back `216A425B…` → **`SHIP=PASS`**. No other sysdir, AVD or the stock google_apis image was touched.

## PROOF — plain boot of TreeOS_Image, `-wipe-data`, no `-writable-system` (`phase2b-proof.ps1`)
- **Boot:** `sys.boot_completed=1` at poll 27 (~2.5 min).
- **Default-home BEFORE any set-home (as instructed, tested first):** `resolve-activity` → `com.google.android.googlesdksetup/.DefaultActivity`, `isDefault=true`; HOME role holder = `com.google.android.googlesdksetup`. **The setup wizard still holds HOME on a fresh wipe — recorded as the remaining default-home gap, not forced and not conflated with registration (which now works).**
- **Registration (the Phase 2b question):** `pm path` poll **0** → `package:/product/priv-app/TreeOS/TreeOS.apk` ✅; dumpsys: `codePath=/product/priv-app/TreeOS`, `versionName=0.2.0`, **`flags=[ SYSTEM DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]`** ✅. In-boot read-backs: `TreeOS.apk` 2,453,754 B; `ls -lZ` context **`u:object_r:system_file:s0`** (the native xattr is honored) ✅; `/system/media/bootanimation.zip` 87,028 B ✅.
- **Logcat:** `FAILED_TO_PARSE_TREEOS_COUNT=0`, `FILE_MAPPING_COUNT=0` ✅ — and checked beyond the script's counters: the full 3.7 MB guest logcat contains **zero** `Failed to parse /product/priv-app/TreeOS` and zero `Failed to open APK` lines; its only `Failed to parse` lines are stock-image noise (oat/WebView/Chrome "Missing base APK" split-dir warnings, bootstat records). PM's own line for us is benign and correct: `/product/priv-app/TreeOS changed; collecting certs`.
- **Home flow (after the labeled provisioning harness — runtime /data settings only):** `set-home-activity` → **Success**; HOME role read-back = `dev.treeos.launcher`; resolve-activity → `isDefault=true`, `dev.treeos.launcher/.MainActivity`; open Settings → **KEYCODE_HOME → `topResumedActivity=dev.treeos.launcher/.MainActivity`** ✅; `pidof` = 2253.
- **Crashes:** **FATAL_COUNT=0**.
- **Screenshot:** [emu-treeos-image2b-1.png](sandbox://workspace/tree-os/shots/emu-treeos-image2b-1.png) — 275,579 B, 1080×2400, sha256 `9d9b0f8ac94e7c12a8a4b627a0d60cd8c3eb89d6fcce42b4f9caa90be74fd3fc`, visually inspected on the VM: the TreeOS home **on the plain boot** — dark-green, "🌳 TreeOS • 0.2", clock **2:15 PM**, "Sat, Nov 7 • 🔋 100%", Search apps bar, the API-35 image's own app grid (Calendar, Camera, Chrome, Clock, Contacts, Drive, Files, Gmail, Google, Maps, Messages, Phone, Photos, Safety, Settings, TMobile, Voice Search, YouTube, YT Music), dock Phone/Texts/Web/Cam/Tree/Setup all single-line.
- **Shutdown:** `emu kill` → OK; final `adb devices` = **`<real-phone-serial>` only** ✅.

## Honest gaps
1. **Default home after wipe is still the wizard's, not ours** (proven above, pre-set-home). Registration was the blocker for everything downstream and is now closed; the in-image default-home answer (SettingsProvider product overlay with `def_device_provisioned=true`, or an equivalent defaults mechanism) is the next, separate spec item — the CONTENT-MANIFEST already lists it as explicitly-not-yet-in-image.
2. **Bootanimation playback** still not visually captured mid-boot (file, format, mode, label and placement all proven in the booted system; same standing caveat as Phases 1–2).
3. **Transfer/tooling detours, for the record:** official otatools was unreachable (404/connection failure over degraded VM egress), hence the checksum-validating Python LP parser — its output was cross-checked against Phase 2's known GPT layout and every stage hash; the first write-back attempt's `dd` seek arithmetic bug corrupted a *local intermediate only* and was caught by the vbmeta magic check before anything shipped; bulk transfers over the tailnet relay ran ~0.4 MB/s per stream (4 parallel streams ≈ 3×), which is why this lane's wall-clock was dominated by moving 3.3 GB twice.
4. VM-side intermediates (split parts, duplicate tarballs, the re-extracted from-final partitions) were deleted after the final image verified; keepers in `image-surgery/work/`: the pristine `stock-system.img`, the shipped `treeos-system-final.img`, and the four surgery partition images. Razer `p2work\phase2b\` still holds the upload parts + reassembled gz + extracted image (~6.6 GB) if a re-ship is ever needed.

---

# Default-home — a plain wiped boot lands on TreeOS with NO set-home command
Date: 2026-11-07 (America/Los_Angeles) · Lane: `treeos-defhome` (lane-board heavy claim on `razer-route`, took over the stale `treeos-phase2b` claim) · Surgery host: this VM (`image-surgery/defhome_build.py`, `arsc.py`, `axml.py`, `lpmeta.py`) · Proof host: Razer RENE_HOME_MAIN (scripts `defhome-*.ps1` in this folder and on the Razer at `C:\Users\cloud\treeos-image\`; console logs pulled back to `image-surgery/logs/defhome-*`) · Content spec updated: `docs/CONTENT-MANIFEST.md` item 6.

## Verdict — SUCCESS, with no tradeoff
The treeos sysdir now holds a revised image (3,576,692,736 B, sha256 **`5C6429DFB3575F58D3761CA1DC19382407DF6B87A4947753EF968EED3088CA6A`**) that boots **plainly with `-wipe-data`** and lands on TreeOS as home with **zero** `set-home-activity`, zero role commands, and zero provisioning `settings put`s: at first read the device already reports `device_provisioned=1` / `user_setup_complete=1` **from the image**, `cmd role get-role-holders android.app.role.HOME` = `dev.treeos.launcher`, resolve-activity HOME `isDefault=true` → TreeOS **already at boot**, Settings → KEYCODE_HOME → top = `dev.treeos.launcher/.MainActivity`, PID alive, **FATAL_COUNT=0**, clean `emu kill`, final `adb devices` = only the real phone `<real-phone-serial>` (never touched; every adb call was `-s emulator-5554`). The shipped mechanism is a single 8,538 B static RRO in `/product/overlay` (manifest item 6) — **NexusLauncher was NOT removed**, and the recents check confirms the QuickStep cost that removal would have risked does not exist here: KEYCODE_APP_SWITCH lands on `com.google.android.apps.nexuslauncher/com.android.quickstep.RecentsActivity` with zero SystemUI/recents errors. Screenshot: [emu-treeos-defhome-1.png](sandbox://workspace/tree-os/shots/emu-treeos-defhome-1.png) — 263,613 B, 1080×2400, sha256 `FE254A6A…11E2`, visually inspected: the TreeOS home (dark-green, "🌳 TreeOS • 0.2", 3:10 PM clock, app grid, single-line dock) on the wiped plain boot of the shipped image.

## The baseline discovery that re-scoped the work (evidence first, routes second)
Before touching the image, a diagnostic run booted the **Phase 2b image unchanged** (plain + `-wipe-data`; the only state-changing adb ops were the two labeled provisioning puts, used as a trigger) and polled the HOME role: `ROLE_PRE = com.google.android.googlesdksetup`, then **poll 0 after the puts already read `dev.treeos.launcher`** and stayed there (18/18 polls), resolve-activity flipped to TreeOS `isDefault=true`, HOME key from Settings landed on TreeOS, FATAL=0. The guest logcat names the mechanism verbatim:

```
RoleControllerServiceImpl: Adding package as default/fallback role holder, package: dev.treeos.launcher, role: android.app.role.HOME
```

i.e. **once provisioning completes, the platform's own default/fallback grant (RoleManagerService → PermissionController's `HomeRoleBehavior`) picks TreeOS** — because TreeOS is now a *registered* qualifying launcher. Phase 2's flip to NexusLauncher happened only because TreeOS failed to parse there and Nexus was the sole qualifying candidate; Phase 2b's registration silently changed who wins the fallback. A second no-touch run on the 2b image (uiautomator open, **zero taps landed** — the wizard exited on its own between round 0 and round 1) showed the same end state: grant timeline in logcat — fallback grants HOME to `googlesdksetup` at 14:47:44 (unprovisioned), then to `dev.treeos.launcher` at 14:48:10 as the guest completed setup by itself (the precise guest component that marked provisioning complete in that run was not isolated; candidates are GoogleSdkSetup's emulator fast-exit / GMS SetupWizard auto-completion — stated as unisolated, not guessed).
**Consequence:** the only thing the image still owed was *provisioning itself*. That is exactly route 3's scope, and it made route 2 (below) unnecessary.

## Route 1 — default role holders via framework overlay: DEAD END, proven from the image's own bytes
`config_defaultRoleHolders` does not exist in this base. Verified by parsing `resources.arsc` directly (parser written for this lane, `image-surgery/arsc.py`): the string is **absent** from framework-res.apk (its full `config_default*` set was enumerated — no role-holders entry), absent from the Google PermissionController APK inside `com.google.android.permission.apex`, and absent from every product overlay that could plausibly carry it (`GoogleConfigOverlay.apk` — enumerated in full; `GooglePermissionControllerOverlay.apk`; the auto-generated framework-res product RRO). In API 35 the HOME default is not a framework config resource at all; it is the PermissionController behavior-class fallback quoted above. An RRO can only override resources that exist in its target, so the route-1 build was not attempted: there is nothing to override, and this paragraph is the exact refusal the brief asked to document if the mechanism proved impossible.

## Route 2 — remove NexusLauncher: NOT NEEDED, not shipped (deliberate deviation, with the reason)
The brief ordered routes 1→2→3; the baseline discovery above inverted the value order — the fallback grant already prefers TreeOS once provisioned, so removing the stock launcher would have bought nothing and risked the one real tradeoff on the table: on this base `config_recentsComponentName` is supplied by `PixelConfigOverlayCommon` and points at NexusLauncher's QuickStep, so deleting `/system_ext/priv-app/NexusLauncherRelease` (located and inventoried: 15,156,926 B APK + x86_64 oat pair) would predictably break Overview/recents. Route 2 was therefore documented instead of executed. It remains the fallback if a future base's fallback ordering ever prefers the stock launcher: delete that priv-app dir with debugfs (stock `system_ext` extraction is kept at `image-surgery/work/system_ext-stock.img` for exactly this), and accept + verify the recents cost on that base.

## Route 3 — SettingsProvider defaults overlay: BUILT, SHIPPED, PROVEN (the shipped mechanism)
- **Investigation:** SettingsProvider (system priv-app) carries `def_device_provisioned` and `def_user_setup_complete` in its own resources (confirmed via its arsc key pool); the stock product RRO for SettingsProvider overrides neither. Both default to the unprovisioned behaviour on a fresh DB — which is why the wizard held HOME.
- **Build (Razer, SDK build-tools 36.0.0):** `aapt2 compile` + `aapt2 link -I platforms/android-35/android.jar --auto-add-overlay`, zipalign, apksigner with the standard debug keystore. Two honest build detours: aapt2 refuses manifest `android:` attributes without the framework `-I` (fixed as shown), and apksigner needs `JAVA_HOME` pointed at Android Studio's jbr (the proven recipe). Result: `dev.treeos.overlay.settingsprovider`, static RRO, priority 100, target `com.android.providers.settings`, resources = the two bools `true`; 8,538 B, sha256 `7D0EFECC…B07` (full spec, sources and recipe: manifest item 6). The built APK's manifest + resources were read back with this lane's own parsers before any surgery.
- **Surgery (VM, 2b method):** debugfs write of the overlay APK into a copy of the 2b product partition at `/overlay/TreeOSSettingsProviderOverlay.apk` (0644, 0/0, `u:object_r:system_file:s0` label); dumped back out and hash-compared exact; `e2fsck -fn` clean; edited partition `product-defhome.img` sha256 `011753FB…687`; written back at the recorded product extent offset into a copy of the Phase 2b final image — LP metadata, vbmeta (flags already 3), system/system_ext/vendor all byte-untouched.
- **Ship (hash-gated, backup-first):** instead of re-shipping 3.5 GB over the degraded route, a 1 MiB **block delta** was computed (only **5 blocks** differ) and applied on the Razer to its pristine local copy of the 2b image (`p2work\phase2b\extract\treeos-system-final.img`, re-hashed `216A425B…` before use). Result hash matched the VM-built image exactly (`DELTA_APPLY=PASS`); the outgoing sysdir image was snapshotted to `p2work\defhome\outgoing-216A425B.img` and hash-verified **before** the sysdir replace; read-back `5C6429DF…` → **`SHIP=PASS`**. (One detour: the first delta file was malformed by a 9-byte header overwriting one data byte — the ship script's hash gate caught it as a short read, nothing shipped; format fixed to headerless + JSON sidecar, re-verified.) Stock sysdir, TreeOS_Phone, Medium_Phone untouched.
- **Proof run 1 (zero-touch, tag `overlay`):** plain launch + `-wipe-data`, **no puts, no taps** — the only adb writes in the whole script are none at all before the read-backs (the script contains no set-home/role/provisioning commands; the string appears only in its header comment saying so). Read-backs: `device_provisioned=1`, `user_setup_complete=1` at first read (2b image read 0/0); `cmd overlay list` → `[x] dev.treeos.overlay.settingsprovider`; `dumpsys overlay` → `STATE_ENABLED, mIsEnabled=true, mIsMutable=false`, target `com.android.providers.settings`, path `/product/overlay/TreeOSSettingsProviderOverlay.apk`; role poll 0 = gsdksetup → **poll 1 = dev.treeos.launcher**, `ROLE_FINAL = dev.treeos.launcher`, `DEFHOME_RESULT=PASS`, FATAL=0. Run 1's *visual* checks were inconclusive for an unrelated reason — the display fell asleep mid-run (top-activity reads empty; screenshot = the 21,617 B dark frame) — so they were re-proven in run 2 rather than claimed.
- **Proof run 2 (confirmation, tag `overlay2`):** same plain + wipe boot, plus a labeled **display-only** wake harness (stay-on + wake key + dismiss keyguard — display settings only; no provisioning/role writes): **TOP_AT_BOOT = `dev.treeos.launcher/.MainActivity`** (the first screen is TreeOS home), resolve-activity at boot already TreeOS `isDefault=true`, role settles to `dev.treeos.launcher` by poll 1, Settings → KEYCODE_HOME → **`HOME_TOP_TREEOS=PASS`**, recents → QuickStep `RecentsActivity` on top with `SYSUI_RECENTS_ERR_COUNT=0`, screenshot = the verified frame linked above, FATAL_COUNT=0, clean shutdown.

## Honest gaps / observations
1. **Transient first holder:** in both overlay runs the role *record* still names `googlesdksetup` at the very first poll (~first 5–10 s) before the provisioned-state grant pass lands on TreeOS — while PM's HOME resolution and the actual top activity are already TreeOS (run 2). This is grant-pass ordering inside RoleManagerService, not a configuration gap; the end state is stable and requires no interaction.
2. **GMS welcome sheet:** run 2's poll caught `com.google.android.gms/.setupservices.CoverSheetWelcomeActivity` transiently on top once during the first seconds. GMS may still flash its welcome cover sheet on first boot even when provisioned; it does not hold the HOME role and the HOME key lands on TreeOS. Removing GMS's setup services was out of scope.
3. **Fallback-ordering is base-specific:** TreeOS winning the HOME fallback over NexusLauncher is *observed platform behaviour on this base* (android-35 google_apis), not a documented guarantee. The manifest now carries the wiped-boot role read-back as a required gate for any future base (GSI included) instead of assuming it.
4. **Bootanimation playback** still not visually captured mid-boot (unchanged standing caveat from Phases 1–2b; file/format/mode/label/placement proven).
5. **Process notes:** long PowerShell runs over the SSH session die with the degraded tailnet route (one broken-pipe at ~2.6 min killed the first baseline attempt before its emulator finished, harmlessly); all subsequent runs used the WMI-detached launcher + log polling pattern (`defhome-launch.ps1`), which survived the route throughout. The lane-board **claim** registered cleanly (took over the stale `treeos-phase2b` claim), but the helper's **heartbeat writes failed all lane long** (`{"ok": false, "updated": 0}` / one connection timeout) — the claim's heartbeat timestamp therefore stayed at claim time and the claim is sweepable by design; noted here since the release call at lane end is subject to the same route.
6. What remains genuinely open after this lane: nothing for default-home on the emulator image. The arm64 GSI lane inherits item 6 as part of the portable spec; its wiped-boot/first-flash HOME gate is manifest checklist step 7.
