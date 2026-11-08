# TreeOS default-home PROOF harness (parameterized).
#   -Tag            label used in output + saved logcat name
#   -Shot           screenshot filename to produce on the Razer ('' = none)
#   -Puts           include the labeled provisioning settings puts (TEST NAVIGATION ONLY)
#   -TapWizard      instead of puts, drive the setup wizard UI with adb taps (uiautomator-guided)
#   -CheckRecents   also exercise KEYCODE_APP_SWITCH and report the top activity + SysUI errors
# Always: plain launch of TreeOS_Image + -wipe-data, NO -writable-system, NO set-home-activity,
# NO role mutation commands. Every adb call: -s emulator-5554 only.
param(
  [string]$Tag = 'variant',
  [string]$Shot = '',
  [switch]$Puts,
  [switch]$TapWizard,
  [switch]$CheckRecents
)
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$work = 'C:\Users\cloud\treeos-image\p2work\defhome'
$shotDir = 'C:\Users\cloud\treeos-image\shots'
New-Item -ItemType Directory -Force $work, $shotDir | Out-Null

function Wait-Boot {
  for ($i=0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"; return $false
}
function Role-Home {
  $r = & $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String
  return $r.Trim()
}
function Top-Activity {
  $d = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
  $m = [regex]::Match($d, 'topResumedActivity=\S+ \S+ (\S+)')
  if ($m.Success) { return $m.Groups[1].Value }
  $m2 = [regex]::Match($d, 'ResumedActivity:\s+\S+ \S+ (\S+)')
  if ($m2.Success) { return $m2.Groups[1].Value }
  $w = & $adb -s emulator-5554 shell dumpsys window windows 2>&1 | Out-String
  $m3 = [regex]::Match($w, 'mCurrentFocus=Window\{\S+ \S+ (\S+)\}')
  if ($m3.Success) { return $m3.Groups[1].Value }
  return '(none)'
}

Write-Host "######## DEFHOME PROOF [$Tag] puts=$Puts tapWizard=$TapWizard recents=$CheckRecents ########"
& $adb devices 2>&1 | Out-String | Write-Host
$cmdLine = "`"$emulator`" -avd TreeOS_Image -no-snapshot -no-audio -gpu swiftshader_indirect -wipe-data"
Write-Host "LAUNCH: $cmdLine"
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
if (-not (Wait-Boot)) { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null; exit 3 }
Start-Sleep -Seconds 5

Write-Host "--- DISPLAY WAKE HARNESS (display only; NOT provisioning, NOT role/home state) ---"
& $adb -s emulator-5554 shell settings put global stay_on_while_plugged_in 7 2>&1 | Out-Null
& $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
Start-Sleep -Seconds 1

Write-Host "--- STATE AT BOOT (no provisioning/role state changes) ---"
$pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
Write-Host "PM_PATH: $($pmp.Trim())"
$prov = & $adb -s emulator-5554 shell settings get global device_provisioned 2>&1 | Out-String
$usc = & $adb -s emulator-5554 shell settings get secure user_setup_complete 2>&1 | Out-String
Write-Host "device_provisioned=$($prov.Trim()) user_setup_complete=$($usc.Trim())"
Write-Host "ROLE_AT_BOOT: $(Role-Home)"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
Write-Host "TOP_AT_BOOT: $(Top-Activity)"
$ovl = & $adb -s emulator-5554 shell cmd overlay list 2>&1 | Out-String
($ovl -split "`n" | Select-String -Pattern 'treeos') | Out-String | Write-Host
& $adb -s emulator-5554 shell dumpsys overlay 2>&1 | Out-String | Set-Content "$work\dumpsys-overlay-$Tag.txt"

if ($Puts) {
  Write-Host "--- PROVISIONING PUTS (TEST NAVIGATION ONLY) ---"
  & $adb -s emulator-5554 shell settings put global device_provisioned 1 2>&1 | Out-Null
  & $adb -s emulator-5554 shell settings put secure user_setup_complete 1 2>&1 | Out-Null
}

if ($TapWizard) {
  Write-Host "--- WIZARD TAP-THROUGH (adb input only; no settings/role commands) ---"
  $want = @('Start','Next','Skip','Skip anyway','Done','Accept','Agree','No thanks','Set up offline','Continue','Got it','Later','Not now')
  for ($round=0; $round -lt 14; $round++) {
    $role = Role-Home
    $top = Top-Activity
    Write-Host "wizard round $round : role=[$role] top=$top"
    if ($top -notmatch 'googlesdksetup|setupwizard') { Write-Host "WIZARD_DONE (top left setup)"; break }
    & $adb -s emulator-5554 shell uiautomator dump /sdcard/win.xml 2>&1 | Out-Null
    $xml = & $adb -s emulator-5554 shell cat /sdcard/win.xml 2>&1 | Out-String
    $tapped = $false
    foreach ($w in $want) {
      $m = [regex]::Match($xml, "text=`"$([regex]::Escape($w))`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"")
      if ($m.Success) {
        $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
        $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
        Write-Host "  tap '$w' at $x,$y"
        & $adb -s emulator-5554 shell input tap $x $y 2>&1 | Out-Null
        $tapped = $true
        break
      }
    }
    if (-not $tapped) { Write-Host "  no known button; pressing BACK-free wait"; }
    Start-Sleep -Seconds 4
  }
}

Write-Host "--- POLL ROLE HOLDERS (no set-home anywhere in this script) ---"
for ($i=0; $i -lt 12; $i++) {
  Write-Host "role poll $i : [$(Role-Home)] top=$(Top-Activity)"
  if ((Role-Home) -match 'dev\.treeos\.launcher') { break }
  Start-Sleep -Seconds 5
}
$finalRole = Role-Home
Write-Host "ROLE_FINAL: $finalRole"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host

Write-Host "--- HOME KEY TEST: open Settings, press HOME ---"
& $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
$topHome = Top-Activity
Write-Host "TOP_AFTER_HOME: $topHome"
if ($topHome -match 'dev\.treeos\.launcher') { Write-Host "HOME_TOP_TREEOS=PASS" } else { Write-Host "HOME_TOP_TREEOS=FAIL" }
$topPid = & $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String
Write-Host "PIDOF_TREEOS: $($topPid.Trim())"

if ($CheckRecents) {
  Write-Host "--- RECENTS TEST (NexusLauncher/QuickStep tradeoff check) ---"
  & $adb -s emulator-5554 shell am start -a android.settings.SETTINGS 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  & $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  & $adb -s emulator-5554 shell input keyevent 187 2>&1 | Out-Null
  Start-Sleep -Seconds 3
  Write-Host "TOP_AFTER_RECENTS: $(Top-Activity)"
  & $adb -s emulator-5554 shell screencap -p /sdcard/recents-$Tag.png 2>&1 | Out-Null
  & $adb -s emulator-5554 pull /sdcard/recents-$Tag.png "$shotDir\recents-$Tag.png" 2>&1 | Out-String | Write-Host
}

if ($Shot -ne '') {
  Write-Host "--- screenshot ---"
  & $adb -s emulator-5554 shell settings put global stay_on_while_plugged_in 7 2>&1 | Out-Null
  & $adb -s emulator-5554 shell svc power stayon true 2>&1 | Out-Null
  & $adb -s emulator-5554 shell input keyevent 224 2>&1 | Out-Null
  Start-Sleep -Seconds 1
  & $adb -s emulator-5554 shell wm dismiss-keyguard 2>&1 | Out-Null
  Start-Sleep -Seconds 1
  & $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
  Start-Sleep -Seconds 2
  & $adb -s emulator-5554 shell screencap -p /sdcard/$Shot 2>&1 | Out-Null
  & $adb -s emulator-5554 pull /sdcard/$Shot "$shotDir\$Shot" 2>&1 | Out-String | Write-Host
  $f = Get-Item "$shotDir\$Shot" -ErrorAction SilentlyContinue
  if ($f) { Write-Host "SHOT bytes=$($f.Length) sha256=$((Get-FileHash $f.FullName -Algorithm SHA256).Hash)" }
}

$log = & $adb -s emulator-5554 shell logcat -d 2>&1 | Out-String
$log | Set-Content "$work\defhome-$Tag-logcat.txt"
$fatal = ([regex]::Matches($log, 'FATAL EXCEPTION')).Count
Write-Host "FATAL_COUNT=$fatal"
$sysuiErr = ([regex]::Matches($log, 'com\.android\.systemui.*(FATAL|died)|Recents.*(died|error)')).Count
Write-Host "SYSUI_RECENTS_ERR_COUNT=$sysuiErr"
if ($finalRole -match 'dev\.treeos\.launcher') { Write-Host "DEFHOME_RESULT=PASS" } else { Write-Host "DEFHOME_RESULT=FAIL" }

Write-Host "=== SHUTDOWN ==="
& $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb devices 2>&1 | Out-String | Write-Host
Write-Host "=== DEFHOME PROOF [$Tag] DONE ==="
