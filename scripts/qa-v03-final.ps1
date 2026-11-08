# Final v0.3 proof: query preservation across rotation, by screenshot
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$shotDir = 'C:\Users\cloud\treeos-image\shots'
$res = 'C:\Users\cloud\treeos-image\p2work\qa-v03-final.txt'
function Log($s) { $s | Tee-Object -FilePath $res -Append | Write-Host }
function A { & $adb -s emulator-5554 @args 2>&1 | Out-String }
function Shot($name) {
  & $adb -s emulator-5554 shell screencap -p /sdcard/$name 2>&1 | Out-Null
  & $adb -s emulator-5554 pull /sdcard/$name "$shotDir\$name" 2>&1 | Out-Null
  $f = Get-Item "$shotDir\$name" -ErrorAction SilentlyContinue
  if ($f) { Log "SHOT $name bytes=$($f.Length)" }
}
function DismissAnr {
  & $adb -s emulator-5554 shell uiautomator dump /sdcard/win.xml 2>&1 | Out-Null
  $xml = A shell cat /sdcard/win.xml
  if ($xml -match 'isn.t responding') {
    $m = [regex]::Match($xml, 'text="Wait"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if ($m.Success) {
      $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
      $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
      Log "ANR dialog present; tapping Wait at $x,$y"
      & $adb -s emulator-5554 shell input tap $x $y 2>&1 | Out-Null
      Start-Sleep -Seconds 3
    } else { Log "ANR dialog present but Wait not found" }
  } else { Log "no ANR dialog" }
}
Log "######## V03 FINAL $(Get-Date -Format 'HH:mm:ss') ########"
$cmdLine = "`"$emulator`" -avd TreeOS_Phone -no-snapshot -no-audio -gpu swiftshader_indirect -writable-system"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Log "LAUNCH Return=$($r.ReturnValue)"
$ok = $false
for ($i=0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  if ($out.Trim() -eq '1') { Log "BOOT OK poll $i"; $ok = $true; break }
}
if (-not $ok) { Log "BOOT TIMEOUT"; exit 3 }
Start-Sleep -Seconds 5
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
$inst = & $adb -s emulator-5554 install -r 'C:\Users\cloud\treeos3\treeos-0.3.0-debug.apk' 2>&1 | Out-String
Log "INSTALL: $($inst.Trim())"
& $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
& $adb -s emulator-5554 shell input tap 540 473 2>&1 | Out-Null
Start-Sleep -Seconds 2
& $adb -s emulator-5554 shell input text clock 2>&1 | Out-Null
Start-Sleep -Seconds 2
Shot 'qa-final-portrait-filtered.png'
& $adb -s emulator-5554 shell input keyevent 4 2>&1 | Out-Null
Start-Sleep -Seconds 2
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system user_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 5
DismissAnr
Shot 'qa-final-landscape-filtered.png'
& $adb -s emulator-5554 shell settings put system user_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 5
DismissAnr
Shot 'qa-final-portrait-back.png'
$log = A shell logcat -d
Log "FATAL_COUNT=$(([regex]::Matches($log, 'FATAL EXCEPTION')).Count)"
Log "PID: [$( (A shell pidof dev.treeos.launcher).Trim() )]"
& $adb -s emulator-5554 emu kill 2>&1 | Out-Null
Start-Sleep -Seconds 5
& $adb devices 2>&1 | Out-String | Write-Host
Log "=== FINAL DONE ==="
