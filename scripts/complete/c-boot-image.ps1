# Completeness lane: plain launch of TreeOS_Image (NO wipe, NO -writable-system). Leaves emulator running.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Image -no-snapshot -no-audio -gpu swiftshader_indirect"
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
Start-Sleep -Seconds 5
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
Write-Host "=== IMAGE BOOT READY ==="
