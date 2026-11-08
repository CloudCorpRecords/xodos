# TreeOS — Phone OS for Android
Started: 2026-11-07 — Rene directive: build a phone OS, test in emulator, then put it on a real phone.

## Verified starting position (checked 2026-11-07)
- **Emulators ready TODAY:**
  - Razer (RENE_HOME_MAIN, 32GB RAM): Android Emulator, AVD `Medium_Phone_API_37.0` — proven boot recipe: detached WMI launch with `-no-snapshot` (Start-Process dies with SSH session). Used successfully 2026-11-05 for Xod Survivors APK install/run.
  - Mac: Android Studio + AVDs Pixel_5_API_30, Pixel_8_API_34, Pixel_Tablet_API_34
- **Build capacity:**
  - VM: 57GB free — NOT enough for full AOSP (needs ~200-250GB for source + build)
  - Razer: 156.6GB free (2026-11-06 snapshot), 31.7GB RAM — tight for AOSP, fine for app-suite builds + emulator. AOSP would need cleanup or an external SSD / cloud builder.
- **Real phones on hand:**
  - S25 Ultra — Rene's daily. US Snapdragon model = bootloader LOCKED, cannot be unlocked, cannot flash a custom ROM. Can install an OS suite as default launcher / default apps with zero risk.
  - Poco — dedicated to X only per standing rule, do not repurpose.
  - For a true ROM flash later: needs an unlockable phone — Pixel 6/7/8/9 (any), or OnePlus / Nothing with unlock support. Cheap clean target: used Pixel 8.

## The two real paths — they stack, not compete

### Path A — Installable OS Suite (START HERE)
What it is: Our own launcher (home screen = the OS face), lock-screen-style dashboard, app drawer, dialer/messages shortcuts, settings hub, widgets, and Xod/Tree built in as the assistant layer. Ships as APKs.
- Tests in emulator today, installs on ANY Android phone including the S25
- No root, no unlock, no bricking risk, uninstall = back to stock
- This is how you prove the look/feel/logic people will actually live in
- v0.1 scope: Launcher + app drawer + search + Tree/Xod panel + widgets (clock, battery, next calendar event) — simple, show don't tell

### Path B — Full AOSP ROM (THE END STATE for "our OS on a phone")
What it is: Build Android from AOSP / LineageOS source, with TreeOS suite preinstalled as system apps, our own boot animation, default settings, no bloat.
- First target is an EMULATOR system image (aosp / sdk_phone64_x86_64) — literally our OS booting in the emulator
- Second target is Pixel hardware — flash with fastboot, verified read-back
- Needs: ~250GB disk, 32GB+ RAM build host (Razer after cleanup, or a cloud builder), unlockable Pixel
- Timeline is days for first bootable image once the host is ready, not hours

## Recommended sequence
1. **TreeOS Suite v0.1** — build launcher APK, boot Razer AVD Medium_Phone_API_37.0, install, screenshot proof, iterate on feel. [DOING FIRST]
2. **Suite v0.2** — dialer, settings hub, notification shade styling, Xod voice entry.
3. **AOSP emulator image** — fork LineageOS/AOSP manifest for emulator target, drop suite in as prebuilts, boot OUR image (not stock + APK).
4. **Real phone** — get an unlockable Pixel, unlock, flash image from step 3, verify: boot, calls, Wi-Fi, camera, our launcher as system default.

## Design rules (from Rene's standing rules)
- Simple, show don't tell — minimal copy, demos/screenshots carry it
- Tree/Xod inside as the agent layer: approvals that mean something
- No Google account required to use the core OS
- Everything open and verifiable (fits the Internet of Things launch)

## Update 2026-11-07 09:30 PT — install DEFERRED, build continues, targets expand
Rene: "We aren't going to be installing this for a while. We're going to keep building on it... eventually I would love for it to actually replace the Pocophone but we will see. Maybe we'll just make it an emulator that works directly on the Steam Deck... Maybe we'll make the OS to where it works exactly like a phone but you can run it on a computer."

Decisions recorded:
- **S25 / real-phone install: DEFERRED indefinitely.** No installs until Rene says go. Building + emulator iteration is the work.
- **Suite-first was chosen and v0.1 is DONE** (built + emulator-proven 2026-11-07, see BUILD-REPORT.md).

### New target 1 — TreeOS on a computer / Steam Deck ("phone on a computer")
This is a real, underserved shape and it fits the fleet: a phone environment you can run on a PC, with Tree/Xod driving it.
- **Route A: Waydroid on Linux** — Android in a container on Wayland, near-native speed, runs real Android apps; our launcher APK becomes its home screen. Steam Deck runs Bazzite (Fedora-based Linux, x86_64, Wayland) and Bazzite ships a Waydroid setup path — Deck is the natural first host, Razer/PC second. ARM apps need translation (libndk/libhoudini); our own apps are native/Java so they run clean.
- **Route B: Our own AOSP emulator image on PC** — the Path B emulator image, packaged to launch like an app on Windows/Linux (Android Emulator / QEMU under the hood). Heavier, but it is literally OUR OS image, not stock Android + APK.
- **Route C: Bliss OS / Android-x86 ISO** — bootable Android for x86 PCs, could dual-boot the Deck from SD. Most "real OS", most invasive.
- Recommended order: Waydroid proof on the Deck first (fastest visible win), AOSP image stays the long-term owned stack.
- Deck reachability — VERIFIED LIVE 2026-11-07 09:43 PT (Rene said Deck is on; checked three ways): Deck is ON, up 6h41, hostname clouddeck, reached via LAN through the Razer jump on system sshd port 22 (the port-2222 deckdoor user service is INACTIVE, which is why the tailnet door <tailnet-address>:2222 does not answer even though the userspace tailscaled-user.service itself is ACTIVE and clouddeck shows on the tailnet). System tailscaled remains inactive as designed. **Waydroid: installed at /usr/bin/waydroid but NOT initialized** — first Deck-lane step is `waydroid init`. Disk: 196G free on /var/home — plenty.

### New target 2 — Replace the Pocophone (long-term, not now)
The Poco is the dedicated X/Twitter phone, driven by Tree over Razer adb, with Tree Poco Kit live on it.
What "replace" would actually require, checked against facts:
- **minSdk fix:** Poco runs Android 9 (API 28); TreeOS v0.1 is minSdk 29 — it cannot even install today. Lower TreeOS floor to 28 (Xod Android already did this exact move).
- **Install gate:** MIUI "Install via USB" restriction has blocked installs before (INSTALL_FAILED_USER_RESTRICTED) — a Rene on-phone toggle.
- **Job proof:** replacement is only real when TreeOS-on-new-host does the Poco's actual job end to end: X app logged in, posting flow driven by Tree, connection self-healing (Poco Kit's job) covered, verified read-backs.
- A Waydroid/Deck TreeOS could take over that job from a desk machine — phone hardware only matters if the X session must be mobile/always-on. That tradeoff is Rene's call when we get there.

### Revised sequence
1. ✅ Suite v0.1 — emulator proof (2026-11-07)
2. Suite v0.2+ — keep building in the Razer emulator: fix dock label wrap, minSdk 28, persistent default-home proof, widgets, Xod voice entry, own dialer/settings surfaces
3. Waydroid on Steam Deck — TreeOS as the home of a Deck-hosted Android (once Deck is awake/verified)
4. Phone-on-computer package for Razer/Windows — same TreeOS, computer host
5. AOSP emulator image (Path B) — our own system image
6. Real hardware only when Rene calls it: Pixel flash, and/or Poco replacement after the job-proof above
