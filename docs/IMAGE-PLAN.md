# XodOS — emulator that takes our OS (system-image plan)
Renamed from TreeOS on 2026-11-07. Earlier entries below keep the name they were written under.
Rene directive 2026-11-07 10:34 PT: "We should be using a emulator that can take our os"

## The distinction Rene is pointing at
- What we have done so far: a STOCK Android emulator (Google's AVD image) + our launcher installed as an app on top. The OS underneath is still Google's.
- What he wants: an emulator whose SYSTEM IMAGE *is* TreeOS — it boots into our OS, with TreeOS baked into the image as a system app, our default home, our branding from the first frame. No install step.

## How an emulator "takes an OS"
The Android Emulator boots whatever system images sit in its sysdir (system.img, vendor.img, product.img, ramdisk). Three ways to get OUR images there, in the order we'll do them:

### Phase 1 — Remaster the stock emulator image (doable now, no 250GB build)
Boot a rootable emulator image with `-writable-system`, `adb root` + `adb remount`, then:
- Push TreeOS APK to /product/priv-app/TreeOS/ (a real system app, survives factory reset)
- Set TreeOS as the preferred HOME in the image's default config
- Replace /system/media/bootanimation.zip with a TreeOS boot animation
- Add TreeOS default settings (dark theme, font, hostname) via product defaults
Prereq check (queued as read-only inventory): which variant is Medium_Phone_API_37 — Play Store images resist root/remount; google_apis (non-Play) images allow it. If the Razer AVD is a Play Store image, create the TreeOS AVD from a google_apis image (Mac already has Pixel_8_API_34 as a candidate host too).

### Phase 2 — Package it as its own emulator (the deliverable)
- Capture the modified partitions and lay them out as a local SDK system-image package:
  system-images/android-XX/treeos/x86_64/ with source.properties + package manifest
- Create AVD "TreeOS_Phone" from it
- PROOF: wipe-data fresh boot — TreeOS is home from first boot, package shows as a system app (`pm path` under /product or /system, not /data), screenshot, no adb install was run

### Phase 3 — True AOSP image (long-term owned stack, unchanged)
Full `sdk_phone64_x86_64` AOSP build produces these same images from source. Host needs Linux + ~250GB + 32GB RAM. Current fleet check: VM 57G free (no), Razer 156G + Windows (needs WSL2 + more disk), Deck 196G + Linux but 16GB RAM (link step will crawl/OOM). Parked until a host fits, or until cleanup/external SSD frees the Razer. Phase 1/2 do NOT depend on it.

## One image for emulator AND phones — the GSI architecture (Rene, 2026-11-07 12:51 PT)
Rene: "create an emulator that can run our image and then we use that image whenever we flash the phones."

That is exactly what Android's **GSI (Generic System Image)** exists for: one system image, separated from the phone's own vendor/hardware layer (Project Treble), so the SAME system image boots in an emulator and flashes onto any Treble phone with an unlocked bootloader. Adopted as the TreeOS image architecture:

- **One OS definition, two builds of it.** The TreeOS content (launcher priv-app, privapp-permissions, default-home config, boot animation, settings defaults) is defined ONCE as a spec/manifest. From that one spec we produce:
  1. an **x86_64 emulator image** — what TreeOS_Image boots (the Razer and Deck are x86; this is the test target), and
  2. an **arm64 GSI system image** — what flashes to phones (phones are ARM; fastboot flash / DSU boot).
  Honest nuance: the two files cannot be byte-identical — native code is compiled per architecture. Everything TreeOS itself is (the APK is architecture-neutral Java, the configs, the branding) IS literally the same file in both. Same OS, two processor builds — this is how Google ships GSIs.
- **Phone flashing, when Rene calls it:** unlockable Treble phone (Pixel first) → `fastboot flash system treeos-gsi.img` (or DSU: boot the GSI temporarily without overwriting the phone's OS — reboot restores stock; the safe first real-phone test). The phone keeps its own vendor image; our system image is the replaceable part, same as in the emulator.
- **Emulator side:** the standard Android Emulator and Cuttlefish both boot GSI-style system images; our current sysdir work (Phases 1-2b) is the emulator half of this and its content spec carries straight over.
- **What this changes now:** the surgery lane must ALSO emit the content manifest (exact files, paths, modes, hashes) as it builds the emulator image, so the arm64 GSI build is a re-run of the same spec against an arm64 base when the AOSP/GSI build host is ready — not a second invention.
- **Blocker for the arm64 half (unchanged):** producing a clean arm64 GSI from source needs the AOSP build host (~250GB/Linux); the surgery method can also be applied to an arm64 google_apis/GSI base image downloaded from Google as an interim route — the same debugfs write works on any architecture's ext4, and the TreeOS APK needs no recompiling.

## Cousins that also "take our OS"
- Waydroid (Deck): boots Lineage-based system/vendor images from /var/lib/waydroid/images — a custom TreeOS image can be dropped there later; the APK-in-Waydroid proof comes first.
- Cuttlefish (aosp_cf): Google's virtual device for AOSP images, Linux hosts only — a candidate once a Linux host has the disk/RAM.

## Sequencing vs live work
The v0.2 lane currently owns the Razer emulator (persistent-home proof). The image lane runs AFTER it finishes — one emulator, one lane at a time (shared-device rule). First image-lane step is the read-only inventory of the AVD image variant on the Razer.
