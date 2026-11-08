# Shared UI helpers for completeness verification scripts (sourced by c-verify-*.ps1)
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$adb = "$sdk\platform-tools\adb.exe"
$shots = 'C:\Users\cloud\treeos-audit\shots'
New-Item -ItemType Directory -Force -Path $shots | Out-Null

function Dump-Ui {
  & $adb -s emulator-5554 shell uiautomator dump /sdcard/w.xml 2>&1 | Out-Null
  & $adb -s emulator-5554 pull /sdcard/w.xml 'C:\Users\cloud\treeos-audit\w.xml' 2>&1 | Out-Null
  [xml]$x = Get-Content 'C:\Users\cloud\treeos-audit\w.xml' -Encoding UTF8
  return $x
}
function Find-Node($xml, $text, $exact = $true) {
  $nodes = $xml.SelectNodes('//node')
  foreach ($n in $nodes) {
    $t = $n.GetAttribute('text')
    if ($exact -and $t -eq $text) { return $n }
    if (-not $exact -and $t -like "*$text*") { return $n }
  }
  return $null
}
function All-Texts($xml) {
  $out = @()
  foreach ($n in $xml.SelectNodes('//node')) { $t = $n.GetAttribute('text'); if ($t) { $out += $t } }
  return $out
}
function Tap-Node($node) {
  $b = $node.GetAttribute('bounds')
  if ($b -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    $cx = ([int]$Matches[1] + [int]$Matches[3]) / 2
    $cy = ([int]$Matches[2] + [int]$Matches[4]) / 2
    & $adb -s emulator-5554 shell input tap $cx $cy 2>&1 | Out-Null
    Start-Sleep -Milliseconds 700
    return $true
  }
  return $false
}
function Tap-Text($xml, $text, $exact = $true) {
  $n = Find-Node $xml $text $exact
  if ($n) { return Tap-Node $n }
  Write-Host "TAP-MISS: [$text]"
  return $false
}
function Shot($name) {
  & $adb -s emulator-5554 shell screencap -p "/sdcard/$name" 2>&1 | Out-Null
  & $adb -s emulator-5554 pull "/sdcard/$name" "$shots\$name" 2>&1 | Out-Null
  Write-Host "SHOT: $name"
}
function Top-Activity {
  $d = & $adb -s emulator-5554 shell dumpsys activity activities 2>&1 | Out-String
  $m = [regex]::Match($d, 'topResumedActivity=\S+ \S+ (\S+)')
  if ($m.Success) { return $m.Groups[1].Value }
  return 'unknown'
}
function Fatal-Count {
  $log = & $adb -s emulator-5554 shell logcat -d 2>&1 | Out-String
  return ([regex]::Matches($log, 'FATAL EXCEPTION')).Count
}
function Start-App($cls) {
  & $adb -s emulator-5554 shell am start -n "dev.treeos.launcher/$cls" 2>&1 | Out-String | Write-Host
  Start-Sleep -Seconds 2
}
