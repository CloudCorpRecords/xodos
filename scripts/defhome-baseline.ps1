# TreeOS default-home BASELINE diagnostic: current Phase 2b image, plain launch + -wipe-data.
# NO set-home-activity, NO role commands that change state. Only state-changing adb ops are the
# two provisioning settings puts (TEST NAVIGATION ONLY, labeled) midway through.
# Goal: observe who holds HOME before/after provisioning flips, and capture role-grant logcat.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$work = 'C:\Users\cloud\treeos-image\p2work\defhome'
New-Item -ItemType Directory -Force $work | Out-Null

function Wait-Boot {
  for ($i=0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"; return $false
}

Write-Host "######## DEFHOME BASELINE: PLAIN + WIPE (2b image) ########"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Image -no-snapshot -no-audio -gpu swiftshader_indirect -wipe-data"
Write-Host "LAUNCH: $cmdLine"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
if (-not (Wait-Boot)) { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 3 }
Start-Sleep -Seconds 5

Write-Host "--- PRE-PROVISIONING STATE ---"
$pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
Write-Host "PM_PATH_PRE: $($pmp.Trim())"
$prov = & $adb -s emulator-5554 shell settings get global device_provisioned 2>&1 | Out-String
$usc = & $adb -s emulator-5554 shell settings get secure user_setup_complete 2>&1 | Out-String
Write-Host "device_provisioned=$($prov.Trim()) user_setup_complete=$($usc.Trim())"
$rolePre = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
Write-Host "ROLE_PRE: $($rolePre.Trim())"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell dumpsys role 2>&1 | Out-String | Set-Content "$work\dumpsys-role-pre.txt"
Write-Host "dumpsys role (pre) saved"

Write-Host "--- PROVISIONING PUTS (TEST NAVIGATION ONLY) ---"
& $adb -s emulator-5554 shell settings put global device_provisioned 1 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell settings put secure user_setup_complete 1 2>&1 | Out-String | Write-Host

Write-Host "--- POLL ROLE HOLDERS (no set-home, watch the flip) ---"
for ($i=0; $i -lt 18; $i++) {
  Start-Sleep -Seconds 5
  $roleNow = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
  Write-Host "role poll $i : [$($roleNow.Trim())]"
}
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell dumpsys role 2>&1 | Out-String | Set-Content "$work\dumpsys-role-post.txt"
Write-Host "dumpsys role (post) saved"

Write-Host "--- HOME key with NO set-home: who is on top? ---"
& $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
$dH = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dH -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 2) | Out-String | Write-Host

Write-Host "--- logcat: role-grant evidence ---"
$log = & $adb -s emulator-5554 shell logcat -d 2>&1 | Out-String
$log | Set-Content "$work\defhome-baseline-logcat.txt"
$fatal = ([regex]::Matches($log, 'FATAL EXCEPTION')).Count
Write-Host "FATAL_COUNT=$fatal"
($log -split "`n" | Select-String -Pattern 'RoleManager|RoleController|grantDefaultRoles|HomeRole|fallback role|default role|addRoleHolder' | Select-Object -First 40) | Out-String | Write-Host

Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== DEFHOME BASELINE DONE ==="
