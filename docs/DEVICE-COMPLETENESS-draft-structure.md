# (scratch — structure for DEVICE-COMPLETENESS.md; final filled from audit.txt)
Sections:
1. Method + image identity (TreeOS_Image AVD, sysdir image sha, build props)
2. Checklist table: Item | Status (PRESENT/MISSING/BROKEN) | Whose (AOSP/Google/TreeOS/third-party) | Evidence (package/role/setting)
   Items: dialer+in-call UI, SMS/MMS, contacts, camera, gallery, browser, email, calendar,
   clock/alarms, calculator, files, notes, maps, app store/install path + sideload,
   keyboard/IME, settings surfaces (wifi/bt/display/sound/battery/storage/security),
   lock screen + PIN/pattern + biometrics surface, notifications + QS tiles,
   emergency calling surface, flashlight (tile + hardware), screen record/screenshots,
   share sheet + intent sanity, clipboard, accessibility/TalkBack, voice assistant entry,
   system updater surface, backup/restore, multi-user/guest, safe mode, privacy dashboard,
   hotspot/tethering surface, NFC surface, printing, location + GPS fix (emu geo)
3. Openness inventory: Google-proprietary present list vs AOSP-open list vs TreeOS list
4. Named big gaps + recommended route (adopt OSS vs build later)
5. What v0.4 added (Calculator/Notes/Flashlight/About — TreeOS-owned)
