$ErrorActionPreference = 'Continue'
Write-Host "=== PROCESSES matching image-get-tools / cmdline ==="
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'image-get-tools|cmdline-tools' } | ForEach-Object {
  Write-Host "PID=$($_.ProcessId) NAME=$($_.Name) CMD=$($_.CommandLine)"
}
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'image-get-tools' } | ForEach-Object {
  Write-Host "KILLING $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
foreach ($f in 'C:\Users\cloud\treeos-image\cmdline-tools.zip','C:\Users\cloud\treeos-image\cmdline-tools-v3.zip') {
  if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue; Write-Host "$f existsAfter=$(Test-Path $f)" }
}
Write-Host "=== DONE CLEANUP ==="
