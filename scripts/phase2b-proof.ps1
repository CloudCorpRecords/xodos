# TreeOS Phase 2b PROOF: plain launch + -wipe-data of TreeOS_Image with the NATIVELY-written image.
# Checks, IN ORDER: boot; resolve-activity BEFORE any set-home (default-home gap record);
# pm path poll (PM first-boot scan lags); dumpsys SYSTEM flag; logcat "Failed to parse" check;
# provisioning harness (runtime /data settings only, labeled); set-home + HOME role read-back;
# Settings -> KEYCODE_HOME functional test; screenshot; FATAL count; clean shutdown.
# Every adb call: -s emulator-5554 only. The real phone <real-phone-serial> is never targeted.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$shotDir = 'C:\Users\cloud\treeos-image\shots'
New-Item -ItemType Directory -Force $shotDir | Out-Null

function Wait-Boot {
  for ($i=0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"; return $false
}

Write-Host "######## PHASE2B PROOF: PLAIN + WIPE (native image) ########"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Image -no-snapshot -no-audio -gpu swiftshader_indirect -wipe-data"
Write-Host "LAUNCH: $cmdLine"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
if (-not (Wait-Boot)) { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 3 }
Start-Sleep -Seconds 5

Write-Host "--- resolve-activity BEFORE any set-home (default-home record) ---"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
$rolePre = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
Write-Host "ROLE_PRE: $($rolePre.Trim())"

Write-Host "--- POLL pm path (PM first-boot scan can lag) ---"
$pmOk = $false
for ($i=0; $i -lt 36; $i++) {
  $pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
  Write-Host "pm poll $i : [$($pmp.Trim())]"
  if ($pmp -match '/product/priv-app/TreeOS/TreeOS\.apk') { $pmOk = $true; break }
  Start-Sleep -Seconds 5
}
Write-Host "NATIVE_PRIVAPP_PM_PATH=$pmOk"
$dump = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
($dump -split "`n" | Select-String -Pattern 'flags=|codePath|versionName|firstInstallTime' | Select-Object -First 6) | Out-String | Write-Host

Write-Host "--- file read-backs inside the plain boot ---"
& $adb -s emulator-5554 shell ls -l /product/priv-app/TreeOS/ /system/media/bootanimation.zip 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell ls -lZ /product/priv-app/TreeOS/TreeOS.apk 2>&1 | Out-String | Write-Host

Write-Host "--- logcat parse check (full buffer) ---"
$log = & $adb -s emulator-5554 shell logcat -d 2>&1 | Out-String
$parseFail = ([regex]::Matches($log, 'Failed to parse /product/priv-app/TreeOS')).Count
$mapFail = ([regex]::Matches($log, "Failed to open APK '/product/priv-app/TreeOS")).Count
Write-Host "FAILED_TO_PARSE_TREEOS_COUNT=$parseFail FILE_MAPPING_COUNT=$mapFail"
($log -split "`n" | Select-String -Pattern 'priv-app/TreeOS' | Select-Object -First 10) | Out-String | Write-Host
$fatal = ([regex]::Matches($log, 'FATAL EXCEPTION')).Count
Write-Host "FATAL_COUNT=$fatal"
$log | Set-Content 'C:\Users\cloud\treeos-image\p2work\phase2b-logcat.txt'

if ($pmOk) {
  Write-Host "--- PROVISIONING HARNESS (runtime /data settings, NOT image state) ---"
  & $adb -s emulator-5554 shell settings put global device_provisioned 1 2>&1 | Out-String | Write-Host
  & $adb -s emulator-5554 shell settings put secure user_setup_complete 1 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 3
  Write-Host "--- set-home (post-provisioning) ---"
  & $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
  & $adb -s emulator-5554 shell cmd role add-role-holder android.app.role.HOME dev.treeos.launcher 2>&1 | Out-String | Write-Host
  $roleAfter = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
  Write-Host "ROLE_AFTER: $($roleAfter.Trim())"
  & $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host

  Write-Host "--- functional: open Settings, then HOME key ---"
  & $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 3
  & $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
  Start-Sleep -Seconds 3
  $dH = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
  ($dH -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 2) | Out-String | Write-Host
  if ($dH -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "IMAGE_HOME_TOP=PASS" } else { Write-Host "IMAGE_HOME_TOP=FAIL" }
  $topPid = & $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String
  Write-Host "PIDOF: $($topPid.Trim())"
}

Write-Host "--- screenshot (wake only) ---"
& $adb -s emulator-5554 shell settings put global stay_on_while_plugged_in 7 2>&1 | Out-Null
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-image2b-1.png 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/treeos-image2b-1.png "$shotDir\emu-treeos-image2b-1.png" 2>&1 | Out-String | Write-Host
$f = Get-Item "$shotDir\emu-treeos-image2b-1.png" -ErrorAction SilentlyContinue
if ($f) { Write-Host "SHOT bytes=$($f.Length) sha256=$((Get-FileHash $f.FullName -Algorithm SHA256).Hash)" }

Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== PHASE2B PROOF DONE ==="
