# TreeOS — Content Manifest (the one OS spec for emulator image + future arm64 GSI)

This is the complete list of content the TreeOS image surgery places into a stock
Android system image. Re-running exactly these placements against ANY stock base
(x86_64 emulator image today; an arm64 GSI/google_apis base later) reproduces
TreeOS. Everything TreeOS-owned is architecture-neutral (APK is Java, configs are
text, branding is a zip) — the same source files, byte for byte, go into both builds.

First produced: Phase 2b, 2026-11-07. Emulator base used:
`system-images;android-35;google_apis;x86_64` stock `system.img`
(3,576,692,736 B, sha256 `c06a5966e70bb34645e68e7fe0038ed4396bad30e7a378dbdbb1c26d6a351171`),
a GPT disk image with partitions `vbmeta` (1 MiB @ LBA 2048) and `super`
(3,573,547,008 B @ LBA 4096). Inside `super` (AOSP liblp dynamic partitions,
metadata v10.0, 2 slots, group `emulator_dynamic_partitions` max 3,565,158,400 B):
system 998,658,048 B · system_dlkm 7,213,056 B · system_ext 221,691,904 B ·
product 2,144,882,688 B · vendor 114,139,136 B — **all sizes and the LP metadata
are left unchanged by the surgery**; files are written natively into the existing
ext4 filesystems (debugfs), and the edited partition images are written back at
their exact LP extent offsets. No partition is resized.

Resulting x86_64 emulator image (Phase 2b): `system.img` 3,576,692,736 B,
sha256 `216a425bf482791cc77b566c4df6b621c60d153b0415c874aae4db47e04f4ba1`.

Revised by the default-home spec item (2026-11-07, see item 6 below):
`system.img` 3,576,692,736 B (size unchanged),
sha256 `5c6429dfb3575f58d3761ca1dc19382407df6b87a4947753ef968eed3088ca6a`.
The Phase 2b image remains preserved on the build machine
(not in git — image binaries are never committed; see the README).

---

## Files placed

### 1. TreeOS launcher — system priv-app (partition: product)
- **Destination:** `/priv-app/TreeOS/TreeOS.apk`
- **Source:** `treeos-0.2.0-debug.apk` — the launcher build output (build from `launcher/` per the README; APK binaries are not kept in git)
  (package `dev.treeos.launcher`, versionName 0.2.0 / versionCode 2, minSdk 28)
- **Size / sha256:** 2,453,754 B · `9e249eab93933823e8eeff24237594feacc7f5264886dded09ed5d0122e301b2`
- **Mode / owner:** 0644 · uid 0 / gid 0
- **SELinux xattr:** `security.selinux` = `u:object_r:system_file:s0` + trailing NUL (26 bytes total, matching stock neighbors)
- **Directory created:** `/priv-app/TreeOS/` — mode 0755 · uid 0 / gid 0 · same SELinux xattr
  (stock `/priv-app` itself already exists at 0755 with the same label; do not alter it)

### 2. Privapp-permissions declaration (partition: product)
- **Destination:** `/etc/permissions/privapp-permissions-treeos.xml`
- **Source:** `image-surgery/privapp-permissions-treeos.xml` in this repo
- **Size / sha256:** 151 B · `bc0111b67de40f9e5f263337fefb53499e3bd948c0e7f362389e8a6edf8d52e5`
- **Mode / owner:** 0644 · uid 0 / gid 0
- **SELinux xattr:** `security.selinux` = `u:object_r:system_file:s0` + trailing NUL (26 bytes)
- **Full contents (verbatim):**
```xml
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="dev.treeos.launcher">
    </privapp-permissions>
</permissions>
```
  (Deliberately grants no privileged permissions — the launcher needs none.
  The entry exists so the priv-app has a native, well-formed permissions record.
  Any future privileged permission for `dev.treeos.launcher` gets added inside
  this element and nowhere else.)

### 3. Boot animation (partition: system)
- **Destination:** `/media/bootanimation.zip` — note: inside the `system` logical
  partition this is the path `/system/media/bootanimation.zip` as seen by Android,
  because the system partition's root is mounted at `/` and its `system/` subtree
  is the classic system tree. The stock base has NO `media` directory there; create it.
- **Source:** `bootanimation.zip` — built from the `bootanim/` sources in this repo
  (540x1200 @ 12 fps, `desc.txt` + `part0/` with 6 ZIP-STORED PNG frames:
  TreeOS tree icon growing in over dark-green background, "TreeOS / by Rene + Tree")
- **Size / sha256:** 87,028 B · `5110137cf2e941d21dc25cb1068f7c4dc547c6c0464ed07b0601db602659afb5`
- **Mode / owner:** 0644 · uid 0 / gid 0
- **SELinux xattr:** `security.selinux` = `u:object_r:system_file:s0` + trailing NUL (26 bytes)
- **Directory created:** `/system/media/` (path inside the system partition image) —
  mode 0755 · uid 0 / gid 0 · same SELinux xattr
- **Format rule:** every entry in the zip must be ZIP_STORED (uncompressed),
  `desc.txt` first — required by Android's bootanimation player.

### 6. SettingsProvider defaults overlay — default-home mechanism (partition: product)
- **Destination:** `/overlay/TreeOSSettingsProviderOverlay.apk`
- **What it is:** a static Runtime Resource Overlay (RRO), package
  `dev.treeos.overlay.settingsprovider`, `android:isStatic="true"`,
  `android:priority="100"`, `android:targetPackage="com.android.providers.settings"`,
  no code (`android:hasCode="false"`).
- **Effect:** overrides two boolean resources in SettingsProvider's first-boot
  database defaults — `def_device_provisioned=true` and
  `def_user_setup_complete=true`. A wiped boot therefore starts in the
  provisioned state from the image itself: the Google setup wizard never owns
  the HOME role, and the platform's own default/fallback role grant
  (RoleManagerService → PermissionController `HomeRoleBehavior`) resolves
  `android.app.role.HOME` to the registered TreeOS priv-app (item 1) with no
  adb command, no tap, and no `/data` state baked in.
- **Size / sha256 (built APK):** 8,538 B ·
  `7d0efecc6ad204a8cc007a0dbbb141d5c809cad9411f409c2c25f52d4f951b07`
- **Mode / owner:** 0644 · uid 0 / gid 0
- **SELinux xattr:** `security.selinux` = `u:object_r:system_file:s0` + trailing NUL (26 bytes)
- **Sources:** `overlay/settings-provider/AndroidManifest.xml` in this repo
  (sha256 `a3a5954824dc2c0ec45d6a6f2a14dc6a58e90a6333fe76ca2d6aba22fc6ad713`) and
  `overlay/settings-provider/res/values/bools.xml` in this repo
  (sha256 `994cfae66c8ad58c207426562967ba24ea2ae799235a9706929b44bcb570f77f`,
  contents: the two `<bool>` lines named above, both `true`).
  Built APK kept with the build outputs on the build machine (not in git).
- **Build recipe (any host with SDK build-tools 36 + a JDK):**
  `aapt2 compile --dir res -o res.zip`; `aapt2 link -o overlay-unsigned.apk
  -I platforms/android-35/android.jar --manifest AndroidManifest.xml res.zip
  --auto-add-overlay`; `zipalign -f 4`; `apksigner sign` with the Android debug
  key (`~/.android/debug.keystore`, alias `androiddebugkey`). Resource matching
  is by name via idmap at boot, so the debug signature is sufficient on
  userdebug; a release build for a phone GSI would sign with the TreeOS release
  key instead. Script of record: `scripts/defhome-build-overlay.ps1` in this repo.
- **On-device verification (from the proof boots):** `cmd overlay list` shows
  `[x] dev.treeos.overlay.settingsprovider`; `dumpsys overlay` shows
  `mState=STATE_ENABLED, mIsEnabled=true, mIsMutable=false`,
  target `com.android.providers.settings`; first `settings get` reads on a
  wiped boot return `device_provisioned=1`, `user_setup_complete=1`.

## Image-level changes that are NOT files

### 4. vbmeta flags (GPT `vbmeta` partition of the emulator disk image)
- At vbmeta image offset +120 (big-endian uint32 flags field of the AVB header,
  magic `AVB0` at partition start): set flags **0 → 3**
  (AVB_VBMETA_IMAGE_FLAGS_HASHTREE_DISABLED | VERIFICATION_DISABLED).
- This makes the edited partitions' stale AVB descriptors non-enforcing, the same
  state an unlocked-bootloader build presents. The stock RSA signature no longer
  verifies after any content change; flags=3 + the unlocked-state boot params
  (item 5) are what allow a plain boot. Emulator-only construct — a phone GSI
  build handles AVB per the target device's unlock state instead; do not carry
  this byte patch to a signed production image.

### 5. Boot params in the emulator package (sysdir file, not inside system.img)
- **File:** `VerifiedBootParams.textproto` in the SDK sysdir
  (`system-images/android-35/treeos/x86_64/`), stock contents plus exactly:
  ```
  param: "androidboot.vbmeta.device_state=unlocked"
  param: "androidboot.flash.locked=0"
  param: "androidboot.verifiedbootstate=orange"
  ```
- The rest of the sysdir is the stock google_apis file set (kernel-ranchu,
  ramdisk.img, vendor.img, encryptionkey.img, build.prop, data/) with
  `source.properties` / `package.xml` re-identified: TagId/VendorId `treeos`,
  package path `system-images;android-35;treeos;x86_64`.
- For the arm64 GSI build this item has no equivalent (fastboot/DSU flashing
  carries its own unlock semantics); items 1–3 and 6 are the entire portable spec.

## Explicitly NOT in the image (runtime state, never bake in)
- HOME role / default-home assignment — still lives in /data and is still never
  baked in. What changed with item 6: the image now carries the *mechanism*
  (provisioned-from-image defaults + the registered TreeOS priv-app), so the
  platform's own first-boot fallback grant assigns HOME to TreeOS on a wiped
  boot with zero adb role/settings commands. The guard is the verification
  read-back in the checklist below (on this base the fallback prefers TreeOS
  over the stock Nexus launcher; a different base could order candidates
  differently, so the wiped-boot role read-back is a required gate, not a
  formality).
- Display/wake settings used by test harnesses (stay_on_while_plugged_in etc.).

## Reproduction checklist (any base)
1. Parse GPT → `super`; parse liblp metadata (validate its SHA-256 checksums) → extents.
2. Extract `product` and `system` partition images.
3. debugfs -w: place items 1–3 and item 6 with the modes/owners/xattrs above.
4. Read every placed file back out and hash-compare against this manifest.
5. Write partitions back at their recorded extent offsets (sizes unchanged);
   for the emulator disk image only, apply item 4; package with item 5.
6. Boot and require: `pm path dev.treeos.launcher` =
   `/product/priv-app/TreeOS/TreeOS.apk`, dumpsys flags include `SYSTEM`,
   no `Failed to parse` in logcat.
7. Default-home gate (plain launch, `-wipe-data`, no set-home/role commands,
   no provisioning puts): require `settings get global device_provisioned` =
   `1` at first read, `cmd role get-role-holders android.app.role.HOME` =
   `dev.treeos.launcher`, `cmd overlay list` shows the item-6 overlay enabled,
   and Settings → KEYCODE_HOME lands on `dev.treeos.launcher/.MainActivity`.
