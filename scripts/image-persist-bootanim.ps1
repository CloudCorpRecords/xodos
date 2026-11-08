# TreeOS Phase 1 W2: (1) fresh -writable-system relaunch persistence proof with NO install/push/set-home
# (only screen-wake display settings so screencap is lit), (2) STRETCH bootanimation in a separated half.
# Every adb call: -s emulator-5554 only.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$shotDir = 'C:\Users\cloud\treeos-image\shots'
$bootanimLocal = 'C:\Users\cloud\treeos-image\bootanimation.zip'
$bootanimBytes = 87028

function Wait-Boot {
  for ($i=0; $i -lt 48; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"; return $false
}
function Wake-Screen {
  & $adb -s emulator-5554 shell settings put global stay_on_while_plugged_in 7 2>&1 | Out-Null
  & $adb -s emulator-5554 shell settings put system screen_off_timeout 1800000 2>&1 | Out-Null
  & $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
  & $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
  Start-Sleep -Seconds 1
  & $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
  & $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-Null
  Start-Sleep -Seconds 1
}
function Take-Shot([string]$remote, [string]$local) {
  for ($try=1; $try -le 3; $try++) {
    Wake-Screen
    & $adb -s emulator-5554 shell screencap -p $remote 2>&1 | Out-Null
    & $adb -s emulator-5554 pull $remote $local 2>&1 | Out-String | Write-Host
    $f = Get-Item $local -ErrorAction SilentlyContinue
    if ($f) { Write-Host "SHOT_TRY$try $local bytes=$($f.Length)"; if ($f.Length -gt 50000) { return $true } }
    Start-Sleep -Seconds 2
  }
  return $false
}

Write-Host "######## W2 FRESH WRITABLE RELAUNCH - PERSISTENCE (no treeos writes) ########"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Phone -no-snapshot -no-audio -gpu swiftshader_indirect -writable-system"
Write-Host "LAUNCH: $cmdLine"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
if (-not (Wait-Boot)) { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 3 }
Wake-Screen
Write-Host "--- pm path (fresh relaunch, no writes) ---"
$pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
Write-Host $pmp
if ($pmp -match '/product/priv-app/TreeOS/TreeOS\.apk') { Write-Host "RELAUNCH_PRIVAPP=PASS" } else { Write-Host "RELAUNCH_PRIVAPP=MISS" }
Write-Host "--- flags (fresh relaunch) ---"
$dump = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
($dump -split "`n" | Select-String -Pattern 'flags=|codePath' | Select-Object -First 4) | Out-String | Write-Host
Write-Host "--- role holders (fresh relaunch, set-home NOT re-run) ---"
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
Write-Host "--- resolve HOME (fresh relaunch) ---"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
Write-Host "--- functional: open Settings, then HOME key ---"
& $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
$dS = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dS -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 2) | Out-String | Write-Host
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
$dH = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dH -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 2) | Out-String | Write-Host
if ($dH -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "RELAUNCH_HOME_TOP=PASS" } else { Write-Host "RELAUNCH_HOME_TOP=CHECK_DUMP" }
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
$okShot = Take-Shot "/sdcard/treeos-image-1.png" "$shotDir\emu-treeos-image-1.png"
Write-Host "PERSIST_SHOT_OK=$okShot"

Write-Host "######## STRETCH: BOOTANIMATION (separated system write) ########"
& $adb -s emulator-5554 root 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
if (-not (Wait-Boot)) { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 4 }
& $adb -s emulator-5554 remount 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 2
$rw = & $adb -s emulator-5554 shell "touch /system/media/.rwtest 2>/dev/null && echo RW_OK; rm -f /system/media/.rwtest" 2>&1 | Out-String
Write-Host "SYSTEM_MEDIA_RW=$($rw.Trim())"
& $adb -s emulator-5554 push $bootanimLocal /system/media/bootanimation.zip 2>&1 | Out-String | Write-Host
Write-Host "push_exit=$LASTEXITCODE"
& $adb -s emulator-5554 shell chmod 644 /system/media/bootanimation.zip 2>&1 | Out-String | Write-Host
$bsz = & $adb -s emulator-5554 shell "stat -c %s /system/media/bootanimation.zip" 2>&1 | Out-String
Write-Host "BOOTANIM_ONDEVICE_SIZE=[$($bsz.Trim())] expected $bootanimBytes"
& $adb -s emulator-5554 shell "ls -l /system/media/bootanimation.zip" 2>&1 | Out-String | Write-Host
Write-Host "=== REBOOT with new bootanim ==="
& $adb -s emulator-5554 reboot 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
if (-not (Wait-Boot)) { Write-Host "BOOTANIM_BOOT_FAILED"; & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 5 }
Wake-Screen
Write-Host "--- after bootanim reboot: file + pm path + home top ---"
& $adb -s emulator-5554 shell "ls -l /system/media/bootanimation.zip" 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 2
$dB = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dB -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 2) | Out-String | Write-Host
if ($dB -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "BOOTANIM_BOOT_HOME=PASS" } else { Write-Host "BOOTANIM_BOOT_HOME=CHECK_DUMP" }
$okShot2 = Take-Shot "/sdcard/treeos-image-2.png" "$shotDir\emu-treeos-image-2.png"
Write-Host "FINAL_SHOT_OK=$okShot2"
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }
Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 4
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== DONE W2 ==="
