# Completeness audit: inventory the running TreeOS_Image emulator into audit.txt
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$dir = 'C:\Users\cloud\treeos-audit'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$log = "$dir\audit.txt"
"" | Out-File -Encoding utf8 $log

function Sec($name) { "`r`n===== $name =====" | Out-File -Encoding utf8 -Append $log }
function Run($label, $argsArr) {
  "--- $label ---" | Out-File -Encoding utf8 -Append $log
  try {
    $o = & $adb -s emulator-5554 @argsArr 2>&1 | Out-String
    $o | Out-File -Encoding utf8 -Append $log
  } catch { "ERROR: $_" | Out-File -Encoding utf8 -Append $log }
}
function Sh($label, $cmd) { Run $label @('shell', $cmd) }

Sec 'DEVICES (context only; all probes use -s emulator-5554)'
(& $adb devices 2>&1 | Out-String) | Out-File -Encoding utf8 -Append $log

Sec 'BUILD / PROPS'
Sh 'flavor+release+sdk' 'getprop ro.build.flavor; getprop ro.build.version.release; getprop ro.build.version.sdk; getprop ro.build.version.security_patch; getprop ro.build.type; getprop ro.build.tags; getprop ro.product.manufacturer; getprop ro.product.model; getprop ro.boot.verifiedbootstate; getprop ro.crypto.state; getprop persist.sys.safemode'
Sh 'treeos-pm-path' 'pm path dev.treeos.launcher'
Sh 'treeos-version' 'dumpsys package dev.treeos.launcher | grep -E "versionName|versionCode|flags=" | head -5'

Sec 'PACKAGE INVENTORY'
Sh 'count-all' 'pm list packages | wc -l'
Sh 'all-packages' 'pm list packages'
Sh 'system-packages' 'pm list packages -s'
Sh 'thirdparty-packages' 'pm list packages -3'

Sec 'ROLES'
foreach ($r in @('HOME','DIALER','SMS','BROWSER','ASSISTANT','CALL_SCREENING','GALLERY','NOTES','WELLBEING')) {
  Sh "role-$r" "cmd role get-role-holders android.app.role.$r"
}
Sh 'default-dialer-telecom' 'cmd telecom get-default-dialer 2>/dev/null || dumpsys telecom | grep -i -m2 "default dialer"'
Sh 'default-sms-app' 'settings get secure sms_default_application'
Sh 'default-browser' 'cmd package resolve-activity -a android.intent.action.VIEW -d http://example.com | head -12'
Sh 'default-assistant' 'settings get secure assistant; settings get secure voice_interaction_service'

Sec 'KEYBOARD / IME'
Sh 'default-input-method' 'settings get secure default_input_method'
Sh 'enabled-imes' 'ime list -s'
Sh 'all-imes' 'ime list'

Sec 'FEATURE CHECKS (specific packages)'
$pkgs = @(
 'com.android.dialer','com.google.android.dialer','com.android.incallui',
 'com.android.mms','com.google.android.apps.messaging',
 'com.android.contacts','com.google.android.contacts',
 'com.android.camera2','com.google.android.camera',
 'com.android.gallery3d','com.google.android.photos',
 'com.android.chrome','com.android.browser2','org.mozilla.firefox',
 'com.google.android.gm','com.android.email','org.thunderbird.android',
 'com.google.android.calendar','com.android.calendar',
 'com.google.android.deskclock','com.android.deskclock',
 'com.android.calculator2','com.google.android.calculator',
 'com.android.documentsui','com.google.android.documentsui',
 'com.google.android.googlequicksearchbox','com.android.quicksearchbox',
 'com.google.android.inputmethod.latin','com.android.inputmethod.latin',
 'com.android.settings','com.android.systemui',
 'com.google.android.marvin.talkback','com.android.vending','com.google.android.gms',
 'com.google.android.gsf','com.android.printspooler','com.android.nfc','com.android.emergency',
 'com.google.android.permissioncontroller','com.android.permissioncontroller',
 'com.android.providers.settings','com.android.shell','com.android.externalstorage',
 'com.google.android.setupwizard','com.google.android.gms.persistent'
)
foreach ($p in $pkgs) {
  $o = & $adb -s emulator-5554 shell pm path $p 2>&1 | Out-String
  if ($o.Trim()) { "PRESENT $p -> $($o.Trim())" | Out-File -Encoding utf8 -Append $log }
  else { "ABSENT  $p" | Out-File -Encoding utf8 -Append $log }
}

Sec 'FEATURES (pm list features)'
Sh 'features' 'pm list features | sort'

Sec 'SETTINGS SURFACES'
Sh 'settings-launch' 'cmd package resolve-activity -a android.settings.SETTINGS | head -6'
Sh 'wifi-settings-resolve' 'cmd package resolve-activity -a android.settings.WIFI_SETTINGS | head -6'
Sh 'bt-settings-resolve' 'cmd package resolve-activity -a android.settings.BLUETOOTH_SETTINGS | head -6'
Sh 'nfc-settings-resolve' 'cmd package resolve-activity -a android.settings.NFC_SETTINGS | head -6'
Sh 'location-mode' 'settings get secure location_mode; settings get secure location_providers_allowed'
Sh 'airplane' 'settings get global airplane_mode_on'

Sec 'SERVICES (service list grep)'
Sh 'services-key' 'service list | grep -iE "nfc|tether|print|clipboard|accessibility|location|telecom|telephony|backup|user|window|statusbar|notification" '

Sec 'LOCKSCREEN / SECURITY'
Sh 'keyguard-state' 'dumpsys window windows 2>/dev/null | grep -i -m3 keyguard; dumpsys trust | head -20'
Sh 'lock-settings' 'settings get secure lockscreen.enabled; settings get secure lock_screen_owner_info_enabled; cmd lock_settings get-disabled 2>/dev/null; ls /data/system/ | grep -iE "lock|gatekeeper|password|pattern" '
Sh 'biometric' 'cmd biometric 2>/dev/null | head -3; dumpsys fingerprint 2>/dev/null | head -5; dumpsys face 2>/dev/null | head -5'

Sec 'NOTIFICATIONS / QS'
Sh 'qs-tiles' 'settings get secure sysui_qs_tiles'
Sh 'dnd' 'settings get global zen_mode'

Sec 'INTENT RESOLUTION SANITY'
Sh 'view-http' 'cmd package resolve-activity -a android.intent.action.VIEW -d http://example.com | head -8'
Sh 'dial-tel' 'cmd package resolve-activity -a android.intent.action.DIAL -d tel:123 | head -8'
Sh 'view-sms' 'cmd package resolve-activity -a android.intent.action.VIEW -d sms: | head -8'
Sh 'send-text' 'cmd package query-activities -a android.intent.action.SEND -t text/plain 2>/dev/null | head -25'
Sh 'camera-still' 'cmd package resolve-activity -a android.media.action.STILL_IMAGE_CAMERA | head -8'
Sh 'home-intent' 'cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME | head -8'
Sh 'pick-contact' 'cmd package resolve-activity -a android.intent.action.PICK -t vnd.android.cursor.dir/contact | head -8'
Sh 'view-geo' 'cmd package resolve-activity -a android.intent.action.VIEW -d geo:37.7,-122.4 | head -8'
Sh 'mail-to' 'cmd package resolve-activity -a android.intent.action.SENDTO -d mailto:a@b.c | head -8'

Sec 'ACCESSIBILITY'
Sh 'a11y-enabled-services' 'settings get secure enabled_accessibility_services; settings get secure accessibility_enabled'
Sh 'talkback-path' 'pm path com.google.android.marvin.talkback; pm path com.android.talkback'

Sec 'BACKUP / UPDATE / USERS'
Sh 'bmgr' 'bmgr enabled; bmgr list transports'
Sh 'users' 'pm list users; cmd user list 2>/dev/null'
Sh 'max-users' 'pm get-max-users'

Sec 'LOCATION / GPS (emulator geo fix)'
Run 'geo-fix' @('emu','geo','fix','-122.4194','37.7749')
Start-Sleep -Seconds 3
Sh 'location-dumpsys' 'dumpsys location | grep -iE "last known|gps.*provider|Last Known Location" | head -20'

Sec 'SCREENSHOT CAPABILITY'
Run 'screencap' @('shell','screencap','-p','/sdcard/audit-shot.png')
Run 'pull-shot' @('pull','/sdcard/audit-shot.png',"$dir\audit-shot.png")

Sec 'CRASH SCAN'
$logcat = & $adb -s emulator-5554 shell logcat -d 2>&1 | Out-String
"FATAL_COUNT=$(([regex]::Matches($logcat, 'FATAL EXCEPTION')).Count)" | Out-File -Encoding utf8 -Append $log

Write-Host "AUDIT WRITTEN: $log"
Get-Item $log | Select-Object Length | Out-String | Write-Host
