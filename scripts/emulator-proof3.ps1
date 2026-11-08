# TreeOS emulator proof v3 - direct adb -s emulator-5554 calls, no wrapper function (dash-arg bug in v2)
$ErrorActionPreference = 'Continue'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"
$emulator = "$env:ANDROID_HOME\emulator\emulator.exe"
$apk = 'C:\Users\cloud\treeos\treeos-0.1.0-debug.apk'
$shotDir = 'C:\Users\cloud\treeos\shots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

Write-Host "=== DEVICES ==="
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

Write-Host "=== LAUNCH ==="
& $adb -s emulator-5554 shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3

Write-Host "=== PIDOF ==="
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host

Write-Host "=== TOP ==="
$dump = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dump -split "`n" | Select-String -Pattern 'topResumedActivity|mResumedActivity|dev.treeos' | Select-Object -First 20) | Out-String | Write-Host

Write-Host "=== LOGCAT ==="
$log = & $adb -s emulator-5554 logcat -d 2>&1 | Out-String
$fatal = ($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION')
Write-Host "FATAL_COUNT=$(@($fatal).Count)"
($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*treeos|dev.treeos' | Select-Object -First 40) | Out-String | Write-Host

Write-Host "=== SCREENCAP 1 ==="
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos1.png 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 pull /sdcard/treeos1.png "$shotDir\emu-treeos-1.png" 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 4
Write-Host "=== PIDOF AFTER WAIT ==="
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "=== SCREENCAP 2 ==="
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos2.png 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 pull /sdcard/treeos2.png "$shotDir\emu-treeos-2.png" 2>&1 | Out-String | Write-Host
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }

Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== DONE ==="
