# Notes persistence across a full emulator reboot (TreeOS_Phone)
$ErrorActionPreference = 'Continue'
. 'C:\Users\cloud\treeos-complete\c-ui-lib.ps1'
& $adb -s emulator-5554 reboot 2>&1 | Out-Null
$booted = $false
for ($i=0; $i -lt 70; $i++) {
  Start-Sleep -Seconds 5
  $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  if ($out.Trim() -eq '1') { Write-Host "REBOOT OK at poll $i"; $booted = $true; break }
}
if (-not $booted) { Write-Host "REBOOT TIMEOUT"; exit 3 }
Start-Sleep -Seconds 4
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
$sh = & $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String
Write-Host "SET-HOME-AFTER-REBOOT: $($sh.Trim())"
$ver = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
$m = [regex]::Match($ver, 'versionName=(\S+)'); if ($m.Success) { Write-Host "VERSION-AFTER-REBOOT: $($m.Groups[1].Value)" }
Start-App '.NotesActivity'
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "NOTES-AFTER-REBOOT persisted=$([bool]($texts -match 'QA test note'))"
Shot 'v04-notes-after-reboot.png'
# cleanup: delete the test note so the iteration device is left tidy
$n = Find-Node $x 'QA test note'
if ($n) {
  Tap-Node $n | Out-Null
  Start-Sleep -Seconds 1
  $x = Dump-Ui
  Tap-Text $x 'Delete' | Out-Null
  Start-Sleep -Seconds 1
  $x = Dump-Ui
  $texts = All-Texts $x
  Write-Host "NOTES-CLEANUP deleted=$(-not [bool]($texts -match 'QA test note'))"
}
Write-Host "REBOOT FATAL=$(Fatal-Count)"
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Write-Host "=== VERIFY REBOOT DONE ==="
