# TreeOS emulator proof - Razer AVD Medium_Phone_API_37.0, WMI detached launch, -no-snapshot
$ErrorActionPreference = 'Continue'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"
$emulator = "$env:ANDROID_HOME\emulator\emulator.exe"
$apk = 'C:\Users\cloud\treeos\treeos-0.1.0-debug.apk'
$shotDir = 'C:\Users\cloud\treeos\shots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

Write-Host "ADB=$adb exists=$(Test-Path $adb)"
Write-Host "EMULATOR=$emulator exists=$(Test-Path $emulator)"
& $adb devices 2>&1 | Out-String | Write-Host
& $emulator -list-avds 2>&1 | Out-String | Write-Host

# Kill any stale emulator first
& $adb emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 2

# Detached WMI launch - proven 2026-11-05, Start-Process dies with SSH session
$cmdLine = "`"$emulator`" -avd Medium_Phone_API_37.0 -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect"
Write-Host "WMI launching: $cmdLine"
$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Create ReturnValue=$($result.ReturnValue) ProcessId=$($result.ProcessId)"

# Wait for boot_completed
$booted = $false
for ($i=0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb shell getprop sys.boot_completed 2>&1 | Out-String
  Write-Host "poll $i boot_completed=$($out.Trim())"
  if ($out.Trim() -eq '1') { $booted = $true; break }
  & $adb devices 2>&1 | Out-String | Write-Host
}
Write-Host "BOOTED=$booted"
if (-not $booted) { Write-Host "=== EMULATOR BOOT FAILED ==="; exit 2 }

& $adb shell input keyevent 82 2>&1 | Out-String | Write-Host

# Install
Write-Host "=== INSTALL ==="
$installOut = & $adb install -r $apk 2>&1 | Out-String
Write-Host $installOut

# Launch as HOME
Write-Host "=== LAUNCH HOME ==="
$launchOut = & $adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity 2>&1 | Out-String
Write-Host $launchOut
Start-Sleep -Seconds 3

# Process / activity check
Write-Host "=== PIDOF ==="
& $adb shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "=== TOP ACTIVITY ==="
& $adb shell dumpsys activity activities 2>&1 | Select-String -Pattern 'topResumedActivity|mResumedActivity|dev.treeos' | Select-Object -First 20 | Out-String | Write-Host
Write-Host "=== LOGCAT FATAL CHECK ==="
& $adb logcat -d 2>&1 | Select-String -Pattern 'FATAL EXCEPTION|dev.treeos' | Select-Object -First 40 | Out-String | Write-Host

# Screencaps - two, few seconds apart. Use exec-out via cmd redirection trick on host:
# adb exec-out needs binary passthrough; in PowerShell over SSH, safer to do adb shell screencap -p /sdcard/... then pull
& $adb shell screencap -p /sdcard/treeos1.png 2>&1 | Out-String | Write-Host
& $adb pull /sdcard/treeos1.png "$shotDir\emu-treeos-1.png" 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 4
& $adb shell screencap -p /sdcard/treeos2.png 2>&1 | Out-String | Write-Host
& $adb pull /sdcard/treeos2.png "$shotDir\emu-treeos-2.png" 2>&1 | Out-String | Write-Host

Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }

Write-Host "=== SHUTDOWN ==="
& $adb emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== EMULATOR PROOF DONE ==="
