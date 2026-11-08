# Contributing to TreeOS

## Build

Launcher (JDK + Android SDK platform 35 / build-tools 36, Gradle 9.1):

```sh
cd launcher
gradle :app:assembleDebug
```

System image: follow the reproduction checklist at the end of
[`docs/CONTENT-MANIFEST.md`](docs/CONTENT-MANIFEST.md). If you place a new
file into the image, the manifest gains an entry for it — destination,
source, SHA-256, mode, owner, SELinux label — in the same change.

## The proof bar

This project's rule is **read-back verification**:

- A build is done when its output is hashed and the hash is read back, not
  when a script prints "success".
- An image change is done when a plain, factory-wiped boot passes the
  manifest gates (`pm path`, HOME role holder, overlay state, logcat scan)
  and the evidence is in the report.
- A check that could not run is reported as **unknown**, with the unread
  source named — never as a pass.
- Screenshots of the claimed state beat descriptions of it.

If a step fails, say so in the PR, with the failing output. A precise
failure report is a good contribution; a false success is the one thing
that is not.

## Pull requests

- Keep changes scoped: one fix, one feature, one manifest item.
- Update the docs the change touches (manifest, plan, report history).
- No binaries in git: no APKs, no system images (see `.gitignore`).
