# TreeOS Phase 1 remaster: boot TreeOS_Phone, root+remount, push APK as priv-app, verify, persistence reboot.
# Every adb call: -s emulator-5554. A real phone (<real-phone-serial>) is attached - never touch it.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"
$apkLocal = 'C:\Users\cloud\treeos-image\TreeOS.apk'
$shotDir = 'C:\Users\cloud\treeos-image\shots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

function Wait-Boot {
  for ($i=0; $i -lt 48; $i++) {
    Start-Sleep -Seconds 5
    $out = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
    if ($out.Trim() -eq '1') { Write-Host "BOOT OK at poll $i"; return $true }
  }
  Write-Host "BOOT TIMEOUT"
  return $false
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

# ---------------- BOOT 1: plain, candidate props ----------------
Write-Host "######## BOOT1 PLAIN (candidate props) ########"
Launch-Emu ""
if (-not (Wait-Boot)) { Kill-Emu; exit 2 }
foreach ($p in 'ro.build.type','ro.build.flavor','ro.build.tags','ro.build.version.sdk','ro.build.version.release','ro.product.cpu.abi','ro.debuggable','ro.secure') {
  $v = & $adb -s emulator-5554 shell getprop $p 2>&1 | Out-String
  Write-Host "PROP $p = $($v.Trim())"
}
Kill-Emu
Start-Sleep -Seconds 3

# ---------------- BOOT 2: -writable-system remaster ----------------
Write-Host "######## BOOT2 WRITABLE-SYSTEM REMASTER ########"
Launch-Emu "-writable-system"
if (-not (Wait-Boot)) { Kill-Emu; exit 3 }
Write-Host "=== ADB ROOT ==="
& $adb -s emulator-5554 root 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
& $adb -s emulator-5554 wait-for-device 2>&1 | Out-String | Write-Host
if (-not (Wait-Boot)) { Kill-Emu; exit 4 }
$who = & $adb -s emulator-5554 shell whoami 2>&1 | Out-String
Write-Host "WHOAMI=$($who.Trim())"
Write-Host "=== ADB REMOUNT ==="
$remountOut = & $adb -s emulator-5554 remount 2>&1 | Out-String
Write-Host $remountOut
if ($remountOut -match 'remount succeeded|Now reboot|remount of .* succeeded') { Write-Host "REMOUNT_RESULT=OK" } else { Write-Host "REMOUNT_RESULT=CHECK_OUTPUT_ABOVE" }
Start-Sleep -Seconds 2
& $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
# Some images reboot themselves after disabling verity; wait for boot again if needed
$bc = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String
if ($bc.Trim() -ne '1') { Write-Host "post-remount boot not complete, waiting..."; if (-not (Wait-Boot)) { Kill-Emu; exit 5 } }
Write-Host "=== MOUNTS ==="
& $adb -s emulator-5554 shell mount 2>&1 | Select-String -Pattern ' /product | /system | / ' | Select-Object -First 10 | Out-String | Write-Host
Write-Host "=== LS PARTITIONS ==="
& $adb -s emulator-5554 shell "ls /product/priv-app/ 2>/dev/null | head; echo ---; ls /system/priv-app/ 2>/dev/null | head" 2>&1 | Out-String | Write-Host

Write-Host "=== PUSH PRIV-APP ==="
$destUsed = ""
foreach ($base in '/product/priv-app','/system/priv-app') {
  Write-Host "--- trying $base ---"
  & $adb -s emulator-5554 shell mkdir -p "$base/TreeOS" 2>&1 | Out-String | Write-Host
  & $adb -s emulator-5554 push $apkLocal "$base/TreeOS/TreeOS.apk" 2>&1 | Out-String | Write-Host
  $ls = & $adb -s emulator-5554 shell "ls -l $base/TreeOS/TreeOS.apk" 2>&1 | Out-String
  Write-Host "LS: $($ls.Trim())"
  if ($ls -match 'TreeOS\.apk') {
    & $adb -s emulator-5554 shell chmod 644 "$base/TreeOS/TreeOS.apk" 2>&1 | Out-String | Write-Host
    $destUsed = "$base/TreeOS/TreeOS.apk"
    break
  }
}
Write-Host "DEST_USED=$destUsed"
if ($destUsed -eq "") { Write-Host "PRIVAPP_PUSH_FAILED"; Kill-Emu; exit 6 }

Write-Host "=== REBOOT (in-instance, after push) ==="
& $adb -s emulator-5554 reboot 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 5
& $adb -s emulator-5554 wait-for-device 2>&1 | Out-Null
if (-not (Wait-Boot)) { Kill-Emu; exit 7 }

Write-Host "=== VERIFY AFTER REBOOT ==="
Write-Host "--- pm path ---"
& $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "--- dumpsys package flags ---"
$dump = & $adb -s emulator-5554 shell dumpsys package dev.treeos.launcher 2>&1 | Out-String
($dump -split "`n" | Select-String -Pattern 'flags=|pkgFlags|codePath|versionName|versionCode' | Select-Object -First 12) | Out-String | Write-Host

Write-Host "=== SET HOME ==="
& $adb -s emulator-5554 shell cmd package set-home-activity dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell cmd role add-role-holder android.app.role.HOME dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "--- role holders readback ---"
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
Write-Host "--- resolve-activity HOME readback ---"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host

Write-Host "=== LAUNCH HOME + SCREENCAP image-0 ==="
& $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-Null
& $adb -s emulator-5554 shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n dev.treeos.launcher/.MainActivity 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 3
$dumpTop = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dumpTop -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 3) | Out-String | Write-Host
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-image-0.png 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/treeos-image-0.png "$shotDir\emu-treeos-image-0.png" 2>&1 | Out-String | Write-Host
Write-Host "=== PIDOF ==="
& $adb -s emulator-5554 shell pidof dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "=== FATAL CHECK ==="
$log = & $adb -s emulator-5554 logcat -d 2>&1 | Out-String
$fatal = ($log -split "`n" | Select-String -Pattern 'FATAL EXCEPTION')
Write-Host "FATAL_COUNT=$(@($fatal).Count)"

Kill-Emu
Start-Sleep -Seconds 3

# ---------------- BOOT 3: persistence proof, NO writes ----------------
Write-Host "######## BOOT3 PERSISTENCE PROOF (no install/push) ########"
Launch-Emu ""
if (-not (Wait-Boot)) { Kill-Emu; exit 8 }
Write-Host "--- pm path (persistence) ---"
& $adb -s emulator-5554 shell pm path dev.treeos.launcher 2>&1 | Out-String | Write-Host
Write-Host "--- role holders (persistence) ---"
& $adb -s emulator-5554 shell cmd role get-role-holders android.app.role.HOME 2>&1 | Out-String | Write-Host
Write-Host "--- resolve HOME (persistence) ---"
& $adb -s emulator-5554 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | Out-String | Write-Host
& $adb -s emulator-5554 shell input keyevent 82 2>&1 | Out-Null
Write-Host "--- press HOME key ---"
& $adb -s emulator-5554 shell input keyevent 3 2>&1 | Out-Null
Start-Sleep -Seconds 3
$dumpTop3 = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
($dumpTop3 -split "`n" | Select-String -Pattern 'topResumedActivity' | Select-Object -First 3) | Out-String | Write-Host
if ($dumpTop3 -match 'dev\.treeos\.launcher/.MainActivity') { Write-Host "PERSIST_HOME_TOP=PASS" } else { Write-Host "PERSIST_HOME_TOP=CHECK_DUMP" }
& $adb -s emulator-5554 shell screencap -p /sdcard/treeos-image-1.png 2>&1 | Out-Null
& $adb -s emulator-5554 pull /sdcard/treeos-image-1.png "$shotDir\emu-treeos-image-1.png" 2>&1 | Out-String | Write-Host
Get-ChildItem $shotDir | ForEach-Object { Write-Host "SHOT $($_.Name) $($_.Length)" }
Kill-Emu
Write-Host "=== DONE REMASTER ==="
