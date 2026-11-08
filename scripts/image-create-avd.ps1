$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$avdm = "$sdk\cmdline-tools\latest\bin\avdmanager.bat"
Write-Host "=== DEVICES AVAILABLE ==="
& $avdm list device 2>&1 | Select-String -Pattern 'id:|Name:' | Select-Object -First 60 | Out-String | Write-Host
Write-Host "=== CREATE AVD TreeOS_Phone (medium_phone) ==="
'no' | & $avdm create avd -n TreeOS_Phone -k 'system-images;android-35;google_apis;x86_64' -d medium_phone --force 2>&1 | Out-String | Write-Host
Write-Host "create_exit=$LASTEXITCODE"
Write-Host "=== AVD LIST ==="
& "$sdk\emulator\emulator.exe" -list-avds 2>&1 | Out-String | Write-Host
Write-Host "=== TreeOS_Phone config summary ==="
$c = "$env:USERPROFILE\.android\avd\TreeOS_Phone.avd\config.ini"
if (Test-Path $c) { Get-Content $c | Select-String -Pattern 'image\.sysdir|tag\.|abi\.type|PlayStore|hw\.device\.name|skin' | Out-String | Write-Host } else { Write-Host "NO CONFIG at $c" }
Write-Host "=== DONE CREATE ==="
