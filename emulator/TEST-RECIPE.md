# Emulator test recipe — proven 2026-11-05

Host: Razer (RENE_HOME_MAIN)
AVD: Medium_Phone_API_37.0

Boot: detached WMI Win32_Process.Create launch with `-no-snapshot`.
Do NOT use Start-Process over SSH — it dies with the session. Snapshot boots did not come up in the 2026-11-05 test.

Then:
  adb install -r <treeos-launcher.apk>
  adb shell am start -n <package>/<activity>
  adb exec-out screencap -p > proof.png
  adb emu kill  (clean shutdown)

Known emulator limit: SwiftShader/gfxstream GPU stack fails some GLES3 shaders (seen with Godot). Native Android UI (our launcher) does not hit that — it renders fine in emulator. Real device remains ground truth for GPU-heavy work.

Mac fallback AVDs: Pixel_8_API_34, Pixel_5_API_30, Pixel_Tablet_API_34
