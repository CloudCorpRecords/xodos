# Functional verification of the v0.4 suite apps on TreeOS_Phone (emulator-5554 only)
$ErrorActionPreference = 'Continue'
. 'C:\Users\cloud\treeos-complete\c-ui-lib.ps1'

Write-Host "########## CALCULATOR ##########"
Start-App '.CalcActivity'
Write-Host "TOP: $(Top-Activity)"
$x = Dump-Ui
Tap-Text $x '7' | Out-Null; $x = Dump-Ui
Tap-Text $x '+' | Out-Null; $x = Dump-Ui
Tap-Text $x '8' | Out-Null; $x = Dump-Ui
Tap-Text $x '=' | Out-Null; $x = Dump-Ui
$texts = All-Texts $x
Write-Host "CALC-A 7+8= -> contains15=$($texts -contains '15')"
Shot 'v04-calc-a.png'
Tap-Text $x 'C' | Out-Null; $x = Dump-Ui
Tap-Text $x '9' | Out-Null; $x = Dump-Ui
Tap-Text $x '÷' | Out-Null; $x = Dump-Ui
Tap-Text $x '0' | Out-Null; $x = Dump-Ui
Tap-Text $x '=' | Out-Null; $x = Dump-Ui
$texts = All-Texts $x
Write-Host "CALC-B 9/0= -> divzero=$([bool]($texts -match "Can't divide by 0"))"
Shot 'v04-calc-b.png'
Tap-Text $x 'C' | Out-Null; $x = Dump-Ui
foreach ($k in @('(','2','+','3',')','×','4','=')) { Tap-Text $x $k | Out-Null; $x = Dump-Ui }
$texts = All-Texts $x
Write-Host "CALC-C (2+3)x4= -> contains20=$($texts -contains '20')"
Tap-Text $x 'C' | Out-Null; $x = Dump-Ui
foreach ($k in @('−','5','+','3','=')) { Tap-Text $x $k | Out-Null; $x = Dump-Ui }
$texts = All-Texts $x
Write-Host "CALC-D -5+3= -> contains-2=$($texts -contains '-2')"
Write-Host "CALC FATAL=$(Fatal-Count)"

Write-Host "########## NOTES ##########"
Start-App '.NotesActivity'
Write-Host "TOP: $(Top-Activity)"
$x = Dump-Ui
Tap-Text $x '＋ New note' $false | Out-Null
Start-Sleep -Seconds 1
$x = Dump-Ui
$ets = @()
foreach ($nd in $x.SelectNodes('//node')) { if ($nd.GetAttribute('class') -eq 'android.widget.EditText') { $ets += $nd } }
Write-Host "NOTES-EDITOR edittexts=$($ets.Count)"
if ($ets.Count -ge 1) { Tap-Node $ets[0] | Out-Null; & $adb -s emulator-5554 shell input text 'QA%stest%snote' 2>&1 | Out-Null; Start-Sleep -Milliseconds 500 }
if ($ets.Count -ge 2) { Tap-Node $ets[1] | Out-Null; & $adb -s emulator-5554 shell input text 'Body%stext%s42' 2>&1 | Out-Null; Start-Sleep -Milliseconds 500 }
$x = Dump-Ui
Tap-Text $x 'Save' | Out-Null
Start-Sleep -Seconds 1
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "NOTES-SAVED inlist=$([bool]($texts -match 'QA test note'))"
Shot 'v04-notes-list.png'
& $adb -s emulator-5554 shell am force-stop dev.treeos.launcher 2>&1 | Out-Null
Start-Sleep -Seconds 2
Start-App '.NotesActivity'
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "NOTES-AFTER-KILL persisted=$([bool]($texts -match 'QA test note'))"
# open the note and delete it at the very end of all notes tests (cleanup in reboot script keeps it)
Write-Host "NOTES FATAL=$(Fatal-Count)"

Write-Host "########## FLASHLIGHT ##########"
Start-App '.FlashlightActivity'
Write-Host "TOP: $(Top-Activity)"
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "FLASH-TEXTS: $($texts -join ' | ')"
Shot 'v04-flashlight.png'
$tgl = Find-Node $x 'Turn on'
if ($tgl -and $tgl.GetAttribute('enabled') -eq 'true') {
  Tap-Node $tgl | Out-Null
  Start-Sleep -Seconds 1
  $x = Dump-Ui
  $texts = All-Texts $x
  Write-Host "FLASH-AFTER-TAP: $($texts -join ' | ')"
  Shot 'v04-flashlight-on.png'
}
Write-Host "FLASH FATAL=$(Fatal-Count)"

Write-Host "########## ABOUT ##########"
Start-App '.AboutActivity'
Write-Host "TOP: $(Top-Activity)"
$x = Dump-Ui
$texts = All-Texts $x
$joined = $texts -join ' '
Write-Host "ABOUT has-version=$([bool]($joined -match 'TreeOS 0\.4\.0')) opensource=$([bool]($joined -match 'open-source')) manifest=$([bool]($joined -match 'CONTENT-MANIFEST'))"
Shot 'v04-about.png'
Write-Host "ABOUT FATAL=$(Fatal-Count)"
Write-Host "=== VERIFY APPS DONE ==="
