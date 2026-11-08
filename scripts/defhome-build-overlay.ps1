# Build the TreeOS SettingsProvider RRO (route 3) on the Razer with the SDK build-tools.
# aapt2 compile+link (no framework -I: the RRO has no code and its resources are matched
# to the target package BY NAME when idmap is generated on-device), zipalign, apksigner
# with the standard debug keystore (same key that signs the TreeOS debug APKs).
$ErrorActionPreference = 'Stop'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$bt = Get-ChildItem "$sdk\build-tools" -Directory | Sort-Object Name -Descending | Select-Object -First 1
Write-Host "build-tools: $($bt.FullName)"
$aapt2 = "$($bt.FullName)\aapt2.exe"
$zipalign = "$($bt.FullName)\zipalign.exe"
$apksigner = "$($bt.FullName)\apksigner.bat"
$src = 'C:\Users\cloud\treeos-image\defhome\overlay-src\settings'
$out = 'C:\Users\cloud\treeos-image\defhome\overlay-out'
New-Item -ItemType Directory -Force $out | Out-Null

& $aapt2 compile --dir "$src\res" -o "$out\res.zip"
if ($LASTEXITCODE -ne 0) { Write-Host "AAPT2_COMPILE=FAIL"; exit 1 }
& $aapt2 link -o "$out\overlay-unsigned.apk" -I "$sdk\platforms\android-35\android.jar" --manifest "$src\AndroidManifest.xml" "$out\res.zip" --auto-add-overlay
if ($LASTEXITCODE -ne 0) { Write-Host "AAPT2_LINK=FAIL"; exit 1 }
& $zipalign -f 4 "$out\overlay-unsigned.apk" "$out\overlay-aligned.apk"
if ($LASTEXITCODE -ne 0) { Write-Host "ZIPALIGN=FAIL"; exit 1 }
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$ks = "$env:USERPROFILE\.android\debug.keystore"
Write-Host "keystore: $ks exists=$(Test-Path $ks)"
& $apksigner sign --ks $ks --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out "$out\TreeOSSettingsProviderOverlay.apk" "$out\overlay-aligned.apk"
if ($LASTEXITCODE -ne 0) { Write-Host "APKSIGNER=FAIL"; exit 1 }
& $apksigner verify --print-certs "$out\TreeOSSettingsProviderOverlay.apk" 2>&1 | Select-Object -First 4 | Out-String | Write-Host
& $aapt2 dump badging "$out\TreeOSSettingsProviderOverlay.apk" 2>&1 | Select-Object -First 4 | Out-String | Write-Host
& $aapt2 dump resources "$out\TreeOSSettingsProviderOverlay.apk" 2>&1 | Out-String | Write-Host
$f = Get-Item "$out\TreeOSSettingsProviderOverlay.apk"
Write-Host "OVERLAY_APK bytes=$($f.Length) sha256=$((Get-FileHash $f.FullName -Algorithm SHA256).Hash)"
Write-Host "=== BUILD OVERLAY DONE ==="
