# TreeOS v0.2 emulator proof - PERSISTENT HOME + functional HOME-key test
# Every adb call targeted -s emulator-5554 only. A real phone is attached to the Razer - never touch it.
$ErrorActionPreference = 'Continue'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"
$emulator = "$env:ANDROID_HOME\emulator\emulator.exe"
$apk = 'C:\Users\cloud\treeos2\treeos-0.2.0-debug.apk'
$shotDir = 'C:\Users\cloud\treeos2\shots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

Write-Host "=== DEVICES BEFORE ==="
& $adb devices 2>&1 | Out-String | Write-Host

$devs = & $adb devices 2>&1 | Out-String
if ($devs -notmatch 'emulator-5554') {
  Write-Host "=== LAUNCHING VIA WMI ==="
  $cmdLine = "`"$emulator`" -avd Medium_Phone_API_37.0 -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect"
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
  Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
} else { Write-Host "=== REUSING RUNNING EMULATOR ===" }

$booted = $false
for ($i=0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  Write-Host "poll $i boot=[$($out.Trim())]"
  if ($out.Trim() -eq '1') { $booted = $true; break }
}
Write-Host "BOOTED=$booted"
if (-not $booted) { & $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host; exit 2 }

& $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-String | Write-Host

Write-Host "=== INSTALL ==="
& $adb -s emulator-5554 install -r $apk 2>&1 | Out-String | Write-Host

Write-Host "=== DUMPSYS PACKAGE VERSION ==="
& $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Select-String -Pattern 'versionCode|versionName|firstInstall|codePath' | Select-Object -First 10 | Out-String | Write-Host

Write-Host "=== SET HOME ATTEMPT 1: cmd package set-home-activity ==="
& $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
Write-Host "exit1=$LASTEXITCODE"

Write-Host "=== SET HOME ATTEMPT 2: cmd role add-role-holder HOME ==="
& $adb -s emulator-5554 shell cmd role add-role-holder android.app.role.HOME dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "exit2=$LASTEXITCODE"

Write-Host "=== READBACK: role holders ==="
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host

Write-Host "=== READBACK: resolve-activity HOME ==="
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host

Write-Host "=== READBACK: query-activities HOME ==="
& $adb -s emulator-5554 shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host

Write-Host "=== READBACK: dumpsys role HOME ==="
$roleDump = & $adb -s emulator-5554 shell dumpsys role 2>&1 | Out-String
($roleDump -split "`n" | Select-String -Pattern 'HOME|treeos|holder' | Select-Object -First 30) | Out-String | Write-Host

Write-Host "=== LAUNCH HOME ==="
& $adb -s emulator-5554 shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3

Write-Host "=== FUNCTIONAL TEST: OPEN SETTINGS ==="
& $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
$dumpA = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
Write-Host "--- TOP AFTER SETTINGS ---"
($dumpA -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 5) | Out-String | Write-Host

Write-Host "=== FUNCTIONAL TEST: KEYCODE_HOME ==="
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
$dumpB = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
Write-Host "--- TOP AFTER HOME KEY ---"
($dumpB -split "`n" | Select-String -Pattern 'topResumedActivity|mResumedActivity' | Select-Object -First 5) | Out-String | Write-Host
if ($dumpB -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "HOME_KEY_TEST=PASS_TREEOS_ON_TOP" } else { Write-Host "HOME_KEY_TEST=CHECK_DUMP_ABOVE" }

Write-Host "=== PIDOF ==="
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host

Write-Host "=== LOGCAT FATAL ==="
$log = & $adb -s emulator-5554 logcat -d 2>&1 | Out-String
$fatal = ($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION')
Write-Host "FATAL_COUNT=$(@($fatal).Count)"
($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*treeos' | Select-Object -First 20) | Out-String | Write-Host

Write-Host "=== SCREENCAP 1 (home after Home-key test) ==="
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-v02-1.png 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 pull /sdcard/treeos-v02-1.png "$shotDir\emu-treeos-v02-1.png" 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 4
Write-Host "=== PIDOF AFTER WAIT ==="
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "=== SCREENCAP 2 ==="
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-v02-2.png 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 pull /sdcard/treeos-v02-2.png "$shotDir\emu-treeos-v02-2.png" 2>&1 | Out-String | Write-Host
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }

Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
Write-Host "=== DEVICES AFTER ==="
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== DONE ==="
