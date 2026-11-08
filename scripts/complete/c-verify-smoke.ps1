# Smoke regression on v0.4 (TreeOS_Phone): home, grid contains new apps, search, Tree panel -> About, rotation
$ErrorActionPreference = 'Continue'
. 'C:\Users\cloud\treeos-complete\c-ui-lib.ps1'

& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "TOP-AFTER-HOME: $(Top-Activity)"
$x = Dump-Ui
$texts = All-Texts $x
foreach ($a in @('Calculator','Notes','Flashlight','About TreeOS','Settings','Chrome')) {
  Write-Host "GRID has-$a = $($texts -contains $a)"
}
Shot 'v04-home-grid.png'

# Tree panel -> About TreeOS
$tree = Find-Node $x 'Tree' $false
if ($tree) { Tap-Node $tree | Out-Null } else { & $adb -s emulator-5554 shell input tap 850 2250 2>&1 | Out-Null }
Start-Sleep -Seconds 1
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "PANEL open=$([bool]($texts -match 'Tree is your OS layer')) aboutBtn=$([bool]($texts -match 'About TreeOS'))"
Shot 'v04-tree-panel.png'
Tap-Text $x 'About TreeOS' | Out-Null
Start-Sleep -Seconds 2
Write-Host "TOP-AFTER-PANEL-ABOUT: $(Top-Activity)"
& $adb -s emulator-5554 shell input keyevent 4 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 2

# Search smoke: tap search box, type 'calc'
$x = Dump-Ui
$sb = Find-Node $x 'Search apps'
if ($sb) { Tap-Node $sb | Out-Null; Start-Sleep -Milliseconds 800; & $adb -s emulator-5554 shell input text 'calc' 2>&1 | Out-Null; Start-Sleep -Seconds 1 }
$x = Dump-Ui
$texts = All-Texts $x
Write-Host "SEARCH calc -> Calculator=$($texts -contains 'Calculator') Notes-shown=$($texts -contains 'Notes')"
Shot 'v04-search.png'
& $adb -s emulator-5554 shell input keyevent 4 2>&1 | Out-Null
Start-Sleep -Milliseconds 600

# Rotation smoke on home
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system user_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 3
Shot 'v04-home-landscape.png'
Write-Host "TOP-LANDSCAPE: $(Top-Activity)"
& $adb -s emulator-5554 shell settings put system user_rotation 0 2>&1 | Out-Null
& $adb -s emulator-5554 shell settings put system accelerometer_rotation 1 2>&1 | Out-Null
Start-Sleep -Seconds 3
Write-Host "TOP-BACK-PORTRAIT: $(Top-Activity)"
Write-Host "SMOKE FATAL=$(Fatal-Count)"
Write-Host "=== VERIFY SMOKE DONE ==="
