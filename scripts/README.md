# Scripts of record

The build, proof, and ship scripts referenced by the reports in
`docs/history/`. They are the actual scripts that produced the verified
results, kept as the reproducible record.

Notes for anyone reusing them:

- They were written for the project's reference Windows build machine, so
  paths like `C:\Users\cloud\...` are that machine's real paths. Treat
  them as examples: the equivalents on your machine are
  `%USERPROFILE%\AppData\Local\Android\Sdk` (Android SDK),
  `%ProgramFiles%\Android\Android Studio\jbr` (JDK), and your own working
  directories for the `treeos*` build folders.
- A real attached phone's serial number, where the original scripts
  printed one to prove it was never targeted, is redacted here as
  `<real-phone-serial>`. Every emulator command in these scripts targets
  `-s emulator-5554` explicitly.
- One-off diagnostic iterations from the working tree are not included;
  the scripts here are the ones the reports cite as proof.
