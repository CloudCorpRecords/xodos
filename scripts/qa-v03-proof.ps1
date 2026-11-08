# v0.3 proof on TreeOS_Phone (writable iteration device): install, re-run BUG-3 + BUG-2 repros
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$shotDir = 'C:\Users\cloud\treeos-image\shots'
$res = 'C:\Users\cloud\treeos-image\p2work\qa-v03-results.txt'
function Log($s) { $s | Tee-Object -FilePath $res -Append | Write-Host }
function A { & $adb -s emulator-5554 @args 2>&1 | Out-String }
function Top {
  $d = A shell dumpsys activity activities
  $m = [regex]::Match($d, 'topResumedActivity=\S+ \S+ (\S+)')
  if ($m.Success) { return $m.Groups[1].Value } else { return '(none)' }
}
function Shot($name) {
  & $adb -s emulator-5554 shell screencap -p /sdcard/$name 2>&1 | Out-Null
  & $adb -s emulator-5554 pull /sdcard/$name "$shotDir\$name" 2>&1 | Out-Null
}
function UiDump {
  & $adb -s emulator-5554 shell uiautomator dump /sdcard/win.xml 2>&1 | Out-Null
  return (A shell cat /sdcard/win.xml)
}
Log "######## V03 PROOF $(Get-Date -Format 'HH:mm:ss') ########"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Phone -no-snapshot -no-audio -gpu swiftshader_indirect -writable-system"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Log "LAUNCH TreeOS_Phone WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
$ok = $false
for ($i=0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  if ($out.Trim() -eq '1') { Log "BOOT OK at poll $i"; $ok = $true; break }
}
if (-not $ok) { Log "BOOT TIMEOUT"; exit 3 }
Start-Sleep -Seconds 5
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
$inst = & $adb -s emulator-5554 install -r 'C:\Users\cloud\treeos3\treeos-0.3.0-debug.apk' 2>&1 | Out-String
Log "INSTALL: $($inst.Trim())"
$ver = A shell dumpsys package dev.treeos.launcher
$m = [regex]::Match($ver, 'versionName=(\S+)')
Log "VERSION on device: $($m.Groups[1].Value)"
$sh = & $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String
Log "SET-HOME: $($sh.Trim())"
$role = (& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String).Trim()
Log "ROLE: [$role]"
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
Log "TOP: $(Top)"
$xml = UiDump
Log "BRAND 0.3: $($xml -match '0\.3')"
Shot 'qa-v03-home.png'

Log "--- REPRO BUG-3: search filter desync on rotation ---"
& $adb -s emulator-5554 shell input tap 540 473 2>&1 | Out-Null
Start-Sleep -Seconds 2
& $adb -s emulator-5554 shell input text clock 2>&1 | Out-Null
Start-Sleep -Seconds 2
$xml = UiDump
Log "portrait filtered: clockApp=$($xml -match 'text="Clock"') calendarGone=$(-not ($xml -match 'text="Calendar"'))"
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system user_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 4
$xml = UiDump
Log "LANDSCAPE after rotation: queryInBox=$($xml -match 'text="clock"') clockApp=$($xml -match 'text="Clock"') calendarGone=$(-not ($xml -match 'text="Calendar"'))"
Shot 'qa-v03-landscape-filtered.png'
& $adb -s emulator-5554 shell settings put system user_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 4
$xml = UiDump
Log "PORTRAIT back: queryInBox=$($xml -match 'text="clock"') calendarGone=$(-not ($xml -match 'text="Calendar"'))"
# clear query for the layout shot
for ($i=0; $i -lt 10; $i++) { & $adb -s emulator-5554 shell input keyevent 67 2>&1 | Out-Null }

Log "--- REPRO BUG-2: landscape layout (full grid) ---"
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system user_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 4
Shot 'qa-v03-landscape.png'
$xml = UiDump
$labels = ([regex]::Matches($xml, 'text="(Calendar|Camera|Chrome|Clock|Contacts|Drive|Files|Gmail|Google|Maps|Messages|Phone|Photos|Safety|Settings|YouTube)"')).Count
Log "LANDSCAPE visible app labels in dump: $labels"
& $adb -s emulator-5554 shell settings put system user_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 3

Log "--- Tree panel version ---"
$xml = UiDump
$mt = [regex]::Match($xml, 'text="[^"]*Tree"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
if ($mt.Success) {
  $x = ([int]$mt.Groups[1].Value + [int]$mt.Groups[3].Value) / 2
  $y = ([int]$mt.Groups[2].Value + [int]$mt.Groups[4].Value) / 2
  & $adb -s emulator-5554 shell input tap $x $y 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  $xml = UiDump
  Log "PANEL v0.3 text: $($xml -match 'v0\.3') gotIt=$($xml -match 'text="Got it"')"
  Shot 'qa-v03-panel.png'
}
$log = A shell logcat -d
Log "FATAL_COUNT=$(([regex]::Matches($log, 'FATAL EXCEPTION')).Count)"
Log "--- SHUTDOWN ---"
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb devices 2>&1 | Out-String | Write-Host
Log "=== V03 PROOF DONE ==="
