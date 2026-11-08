# TreeOS — openness direction

TreeOS is an open-source product (Apache License 2.0). This note records
what is open today, what is not, and where the line moves next.

## Open today

Everything TreeOS owns is in this repo under the LICENSE:

- the launcher/app suite source (`launcher/`)
- the image surgery tooling (`image-surgery/`)
- the default-home overlay source (`overlay/`)
- the boot animation sources (`bootanim/`)
- the complete content spec (`docs/CONTENT-MANIFEST.md`) — every file the
  image adds, with hashes, modes, owners, and labels, and the checklist
  that reproduces the image on any compatible base
- the build/proof scripts and the full report history, including the
  failures (the Phase 2 overlay-capture failure is documented, not hidden)

## Not open, and not ours to open

The current **test** image is reproduced on top of Google's
`system-images;android-35;google_apis;x86_64` base. That base contains
Google-proprietary applications (the Google apps in the screenshots are
the base's, not TreeOS's). Those components:

- are not part of TreeOS and are not covered by this repo's license,
- are not redistributed here — no base image, system image, or APK binary
  is committed to this repo,
- exist in the test image only because it is the fastest base that boots
  the emulator proof.

## The direction

The distribution base for TreeOS is **AOSP without Google apps**: the same
manifest spec re-run against an AOSP base, with open components filling
the everyday-device roles. The design rule from the start
([`docs/PLAN.md`](PLAN.md)): no Google account required to use the core OS.

A device-completeness audit — every everyday function (dialer, SMS,
contacts, camera, browser, keyboard, settings surfaces, lock screen,
notifications, and the rest), whose implementation it is today (AOSP /
Google / TreeOS / third-party), and what replaces the proprietary pieces —
is in progress. Its structure is published at
[`docs/DEVICE-COMPLETENESS-draft-structure.md`](DEVICE-COMPLETENESS-draft-structure.md);
the filled audit (including its openness inventory: Google-proprietary
present vs AOSP-open vs TreeOS-owned) lands as `docs/DEVICE-COMPLETENESS.md`
when the audit completes, and this note will be updated from it.
