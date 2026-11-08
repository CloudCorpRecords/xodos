# Boot TreeOS_Phone (writable iteration device), install v0.4 APK, set home. Leaves emulator running.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
& $adb -s emulator-5554 emu kill 2>&1 | Out-Null
Start-Sleep -Seconds 4
$cmdLine = "`"$emulator`" -avd TreeOS_Phone -no-snapshot -no-audio -gpu swiftshader_indirect -writable-system"
Write-Host "LAUNCH: $cmdLine"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
$booted = $false
for ($i=0; $i -lt 70; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; $booted = $true; break }
}
if (-not $booted) { Write-Host "BOOT TIMEOUT"; exit 3 }
Start-Sleep -Seconds 4
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
$inst = & $adb -s emulator-5554 install -r 'C:\Users\cloud\treeos4\treeos-0.4.0-debug.apk' 2>&1 | Out-String
Write-Host "INSTALL: $($inst.Trim())"
$sh = & $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String
Write-Host "SET-HOME: $($sh.Trim())"
$ver = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
$m = [regex]::Match($ver, 'versionName=(\S+)'); if ($m.Success) { Write-Host "VERSION: $($m.Groups[1].Value)" }
$pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
Write-Host "PM_PATH: $($pmp.Trim())"
$role = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
Write-Host "HOME_ROLE: $($role.Trim())"
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "=== PHONE V04 READY ==="
