# TreeOS v0.3 build on Razer - fresh dir treeos3, v0.1 treeos dir untouched
$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$gradle = 'C:\Users\cloud\.gradle\wrapper\dists\gradle-9.1.0-bin\9agqghryom9wkf8r80qlhnts3\gradle-9.1.0\bin\gradle.bat'

Write-Host "=== JAVA ==="
& "$env:JAVA_HOME\bin\java.exe" -version 2>&1 | Out-String | Write-Host
Write-Host "=== GRADLE EXISTS: $(Test-Path $gradle) ==="
Write-Host "=== SDK EXISTS: $(Test-Path $env:ANDROID_HOME) ==="

if (Test-Path 'C:\Users\cloud\treeos3\project') { Remove-Item -Recurse -Force 'C:\Users\cloud\treeos3\project' }
New-Item -ItemType Directory -Force -Path 'C:\Users\cloud\treeos3\project' | Out-Null
tar -xzf 'C:\Users\cloud\treeos-v03.tar.gz' -C 'C:\Users\cloud\treeos3\project'
Write-Host "=== EXTRACTED ==="
Get-ChildItem -Recurse 'C:\Users\cloud\treeos3\project' | Select-Object -First 30 FullName | Out-String | Write-Host

Set-Location 'C:\Users\cloud\treeos3\project'
Write-Host "=== BUILD START ==="
& $gradle ':app:assembleDebug' '--console=plain' 2>&1 | Tee-Object -FilePath 'C:\Users\cloud\treeos3\build.log'
$buildExit = $LASTEXITCODE
Write-Host "=== BUILD EXIT: $buildExit ==="

$apk = 'C:\Users\cloud\treeos3\project\app\build\outputs\apk\debug\app-debug.apk'
if (Test-Path $apk) {
  $item = Get-Item $apk
  $hash = Get-FileHash -Algorithm SHA256 $apk
  Write-Host "APK_PATH=$apk"
  Write-Host "APK_SIZE=$($item.Length)"
  Write-Host "APK_SHA256=$($hash.Hash)"
  $bt = Get-ChildItem "$env:ANDROID_HOME\build-tools" -Directory | Sort-Object Name -Descending | Select-Object -First 1
  $aapt2 = Join-Path $bt.FullName 'aapt2.exe'
  Write-Host "AAPT2=$aapt2"
  & $aapt2 dump badging $apk 2>&1 | Out-String | Write-Host
  Copy-Item $apk 'C:\Users\cloud\treeos3\treeos-0.3.0-debug.apk' -Force
  Write-Host "=== BUILD SUCCESS ==="
  exit 0
} else {
  Write-Host "=== BUILD FAILED - NO APK ==="
  exit 1
}
