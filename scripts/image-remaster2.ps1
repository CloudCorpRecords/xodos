# TreeOS Phase 1 remaster v2 - fixes v1 flow: remount requires a reboot before partitions go rw.
# Strict checks: adb exit codes + on-device byte-size verification. Every adb call: -s emulator-5554 only.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$apkLocal = 'C:\Users\cloud\treeos-image\TreeOS.apk'
$apkBytes = 2453754
$shotDir = 'C:\Users\cloud\treeos-image\shots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

function Wait-Boot {
  for ($i=0; $i -lt 48; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"; return $false
}
function Reboot-Wait {
  & $adb -s emulator-5554 reboot 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 5
  & $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
  return (Wait-Boot)
}
function Launch-Emu([string]$extra) {
  Write-Host "=== DEVICES BEFORE LAUNCH ==="
  & $adb devices 2>&1 | Out-String | Write-Host
  $devs = & $adb devices 2>&1 | Out-String
  if ($devs -match 'emulator-5554') { Write-Host "REUSING RUNNING EMULATOR"; return }
  $cmdLine = "`"$emulator`" -avd TreeOS_Phone -no-snapshot -no-audio -gpu swiftshader_indirect $extra"
  Write-Host "LAUNCH: $cmdLine"
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
  Write-Host "WMI Return=$($r.ReturnValue) Pid=$($r.ProcessId)"
}
function Kill-Emu {
  & $adb -s emulator-5554 emu kill 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 4
  Write-Host "=== DEVICES AFTER KILL ==="
  & $adb devices 2>&1 | Out-String | Write-Host
}
function Root-Remount([string]$tag) {
  Write-Host "=== ROOT ($tag) ==="
  & $adb -s emulator-5554 root 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 3
  & $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
  if (-not (Wait-Boot)) { return $false }
  $who = & $adb -s emulator-5554 shell whoami 2>&1 | Out-String
  Write-Host "WHOAMI($tag)=$($who.Trim())"
  Write-Host "=== REMOUNT ($tag) ==="
  & $adb -s emulator-5554 remount 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 2
  & $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
  $bc = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
  if ($bc.Trim() -ne '1') { if (-not (Wait-Boot)) { return $false } }
  return $true
}
function Rw-Test([string]$base) {
  $t = & $adb -s emulator-5554 shell "touch $base/.rwtest 2>/dev/null && echo RW_OK; rm -f $base/.rwtest" 2>&1 | Out-String
  return ($t -match 'RW_OK')
}

# ---------------- BOOT W1: writable, remount-reboot-remount, push ----------------
Write-Host "######## BOOT W1 WRITABLE REMASTER v2 ########"
Launch-Emu "-writable-system"
if (-not (Wait-Boot)) { Kill-Emu; exit 3 }
if (-not (Root-Remount "first")) { Kill-Emu; exit 4 }
Write-Host "=== REBOOT so verity/overlayfs takes effect ==="
if (-not (Reboot-Wait)) { Kill-Emu; exit 5 }
if (-not (Root-Remount "second")) { Kill-Emu; exit 6 }
Write-Host "=== MOUNTS AFTER SECOND REMOUNT ==="
& $adb -s emulator-5554 shell mount 2>&1 | Select-String -Pattern 'product|overlay| /system ' | Select-Object -First 14 | Out-String | Write-Host

Write-Host "=== PUSH PRIV-APP (strict) ==="
$destUsed = ""
foreach ($base in '/product/priv-app','/system/priv-app') {
  $rw = Rw-Test $base
  Write-Host "RW_TEST $base = $rw"
  if (-not $rw) { continue }
  & $adb -s emulator-5554 shell mkdir -p "$base/TreeOS" 2>&1 | Out-String | Write-Host
  & $adb -s emulator-5554 push $apkLocal "$base/TreeOS/TreeOS.apk" 2>&1 | Out-String | Write-Host
  Write-Host "push_exit=$LASTEXITCODE"
  if ($LASTEXITCODE -ne 0) { continue }
  $sz = & $adb -s emulator-5554 shell "stat -c %s $base/TreeOS/TreeOS.apk" 2>&1 | Out-String
  Write-Host "ONDEVICE_SIZE $base = [$($sz.Trim())] expected $apkBytes"
  if ($sz.Trim() -eq "$apkBytes") {
    & $adb -s emulator-5554 shell chmod 644 "$base/TreeOS/TreeOS.apk" 2>&1 | Out-String | Write-Host
    & $adb -s emulator-5554 shell "ls -l $base/TreeOS/" 2>&1 | Out-String | Write-Host
    $destUsed = "$base/TreeOS/TreeOS.apk"
    break
  }
}
Write-Host "DEST_USED=$destUsed"
if ($destUsed -eq "") { Write-Host "PRIVAPP_PUSH_FAILED_STRICT"; Kill-Emu; exit 7 }

Write-Host "=== REBOOT after push ==="
if (-not (Reboot-Wait)) { Kill-Emu; exit 8 }
Write-Host "=== VERIFY AFTER PUSH-REBOOT ==="
Write-Host "--- pm path ---"
& $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "--- dumpsys package ---"
$dump = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
($dump -split "`n" | Select-String -Pattern 'flags=|pkgFlags|codePath|versionName|versionCode' | Select-Object -First 12) | Out-String | Write-Host
Write-Host "=== SET HOME ==="
& $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell cmd role add-role-holder android.app.role.HOME dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "--- role holders ---"
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
Write-Host "--- resolve HOME ---"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-Null
& $adb -s emulator-5554 shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
$d0 = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($d0 -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 3) | Out-String | Write-Host
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
$log = & $adb -s emulator-5554 logcat -d 2>&1 | Out-String
$fatal = ($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION')
Write-Host "FATAL_COUNT=$(@($fatal).Count)"
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-image-0.png 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/treeos-image-0.png "$shotDir\emu-treeos-image-0.png" 2>&1 | Out-String | Write-Host

Write-Host "=== IN-INSTANCE REBOOT PERSISTENCE (adb reboot, no writes) ==="
if (-not (Reboot-Wait)) { Kill-Emu; exit 9 }
& $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
Kill-Emu
Start-Sleep -Seconds 3

# ---------------- BOOT P1: fresh PLAIN relaunch persistence ----------------
Write-Host "######## BOOT P1 PLAIN RELAUNCH PERSISTENCE ########"
Launch-Emu ""
if (-not (Wait-Boot)) { Kill-Emu; exit 10 }
Write-Host "--- pm path (plain relaunch) ---"
$pmp = & $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String
Write-Host $pmp
if ($pmp -match '/product/|/system/') { Write-Host "PLAIN_RELAUNCH_PRIVAPP=PASS" } else { Write-Host "PLAIN_RELAUNCH_PRIVAPP=MISS" }
Write-Host "--- role holders (plain relaunch) ---"
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-Null
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
$d1 = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($d1 -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 3) | Out-String | Write-Host
if ($d1 -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "PERSIST_HOME_TOP=PASS" } else { Write-Host "PERSIST_HOME_TOP=CHECK_DUMP" }
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-image-1.png 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/treeos-image-1.png "$shotDir\emu-treeos-image-1.png" 2>&1 | Out-String | Write-Host
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }
Kill-Emu
Write-Host "=== DONE REMASTER2 ==="
