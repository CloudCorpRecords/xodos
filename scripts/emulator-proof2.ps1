# TreeOS emulator proof v2 - TARGET emulator-5554 EXPLICITLY (Razer also has a real phone on adb)
$ErrorActionPreference = 'Continue'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adbExe = "$env:ANDROID_HOME\platform-tools\adb.exe"
$emulator = "$env:ANDROID_HOME\emulator\emulator.exe"
$apk = 'C:\Users\cloud\treeos\treeos-0.1.0-debug.apk'
$shotDir = 'C:\Users\cloud\treeos\shots'
$serial = 'emulator-5554'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

function AdbE { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$a) & $adbExe -s $serial @a 2>&1 | Out-String }

Write-Host "=== DEVICES BEFORE ==="
& $adbExe devices 2>&1 | Out-String | Write-Host

# Check if emulator already running from v1 attempt
$devs = & $adbExe devices 2>&1 | Out-String
if ($devs -notmatch 'emulator-5554') {
  Write-Host "=== LAUNCHING EMULATOR VIA WMI ==="
  $cmdLine = "`"$emulator`" -avd Medium_Phone_API_37.0 -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect"
  $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
  Write-Host "WMI ReturnValue=$($result.ReturnValue) ProcessId=$($result.ProcessId)"
} else {
  Write-Host "=== EMULATOR ALREADY PRESENT (from v1) - REUSING ==="
}

$booted = $false
for ($i=0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 5
  $out = AdbE shell getprop sys.boot_completed
  Write-Host "poll $i boot_completed=[$($out.Trim())]"
  if ($out.Trim() -eq '1') { $booted = $true; break }
}
Write-Host "BOOTED=$booted"
if (-not $booted) {
  Write-Host "=== EMULATOR BOOT FAILED ==="
  AdbE emu kill | Write-Host
  exit 2
}

AdbE shell input keyevent 82 | Write-Host

Write-Host "=== INSTALL (emulator only) ==="
$installOut = AdbE install -r $apk
Write-Host $installOut

Write-Host "=== LAUNCH HOME (plain MainActivity start via HOME intent) ==="
$launchOut = AdbE shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity
Write-Host $launchOut
Start-Sleep -Seconds 3

Write-Host "=== PIDOF ==="
AdbE shell pidof dev.treeos.launcher | Write-Host
Write-Host "=== TOP ACTIVITY ==="
$dumpsys = AdbE shell dumpsys activity activities
Write-Host (($dumpsys -split "`n" | Select-String -Pattern 'topResumedActivity|mResumedActivity|dev.treeos' | Select-Object -First 20) | Out-String)
Write-Host "=== LOGCAT CHECK ==="
$log = AdbE logcat -d
$fatal = ($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION' )
Write-Host "FATAL_LINES_COUNT=$(@($fatal).Count)"
Write-Host (($log -split "`n" | Select-String -Pattern 'dev.treeos|FATAL EXCEPTION|AndroidRuntime' | Select-Object -First 40) | Out-String)

Write-Host "=== SCREENCAPS ==="
AdbE shell screencap -p /sdcard/treeos1.png | Write-Host
AdbE pull /sdcard/treeos1.png "$shotDir\emu-treeos-1.png" | Write-Host
Start-Sleep -Seconds 4
AdbE shell screencap -p /sdcard/treeos2.png | Write-Host
AdbE pull /sdcard/treeos2.png "$shotDir\emu-treeos-2.png" | Write-Host
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }

Write-Host "=== SHUTDOWN ==="
AdbE emu kill | Write-Host
Start-Sleep -Seconds 3
& $adbExe devices 2>&1 | Out-String | Write-Host
Write-Host "=== EMULATOR PROOF DONE ==="
