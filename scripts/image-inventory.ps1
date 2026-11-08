$ErrorActionPreference = 'Continue'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
Write-Host "=== HOST ==="
hostname
Write-Host "=== ADB DEVICES BEFORE ==="
& "$env:ANDROID_HOME\platform-tools\adb.exe" devices 2>&1 | Out-String | Write-Host
Write-Host "=== AVD LIST ==="
& "$env:ANDROID_HOME\emulator\emulator.exe" -list-avds 2>&1 | Out-String | Write-Host
Write-Host "=== Medium_Phone config.ini ==="
$avdDir = "$env:USERPROFILE\.android\avd\Medium_Phone_API_37.0.avd"
Write-Host "AVD_DIR=$avdDir exists=$(Test-Path $avdDir)"
if (Test-Path "$avdDir\config.ini") { Get-Content "$avdDir\config.ini" | Out-String | Write-Host }
Write-Host "=== ALL AVD config.ini summaries ==="
Get-ChildItem "$env:USERPROFILE\.android\avd" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "--- AVD: $($_.Name) ---"
  $c = Join-Path $_.FullName 'config.ini'
  if (Test-Path $c) { Get-Content $c | Select-String -Pattern 'image\.sysdir|tag\.id|tag\.display|abi\.type|hw\.device|PlayStore|skin|disk\.dataPartition' | Out-String | Write-Host }
}
Write-Host "=== SYSTEM IMAGES INVENTORY ==="
$si = "$env:ANDROID_HOME\system-images"
Get-ChildItem $si -Recurse -Depth 2 -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
Write-Host "=== SYSTEM IMAGE source.properties ==="
Get-ChildItem $si -Recurse -Filter 'source.properties' -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "--- $($_.FullName) ---"
  Get-Content $_.FullName | Out-String | Write-Host
}
Write-Host "=== SYSTEM IMAGE sizes (img files) ==="
Get-ChildItem $si -Recurse -Include '*.img' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "$($_.FullName) $($_.Length)" }
Write-Host "=== SDKMANAGER / AVDMANAGER ==="
Get-ChildItem "$env:ANDROID_HOME\cmdline-tools" -Recurse -Filter 'sdkmanager.bat' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
Get-ChildItem "$env:ANDROID_HOME\cmdline-tools" -Recurse -Filter 'avdmanager.bat' -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
Get-ChildItem "$env:ANDROID_HOME\tools\bin" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
Write-Host "=== DISK ==="
Get-PSDrive C | ForEach-Object { Write-Host "C free=$($_.Free) used=$($_.Used)" }
Write-Host "=== DONE INVENTORY ==="
