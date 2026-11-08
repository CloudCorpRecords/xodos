# TreeOS Phase 2b SHIP: back up Phase 2a sysdir image, reassemble the VM-built native image,
# verify hashes at every stage, and only then replace the treeos sysdir system.img.
# Expected: gz sha256 B9C7A3F92FE0EC6E604DA5C7D180D9F471B3444EF9DBA901F83D1351F324CA18
#           img sha256 216A425BF482791CC77B566C4DF6B621C60D153B0415C874AAE4DB47E04F4BA1
#           old img sha256 DD53732D51899A6F43065632D33FA6210B144BA8D2A07D14B6952EB02B7BB602 (backup target)
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$sysdir = "$sdk\system-images\android-35\treeos\x86_64"
$work = 'C:\Users\cloud\treeos-image\p2work\phase2b'
$log = "$work\phase2b-ship.log"
New-Item -ItemType Directory -Force $work | Out-Null
function L($m) { $m | Tee-Object -FilePath $log -Append | Write-Host }
"=== PHASE2B SHIP START $(Get-Date -Format o) ===" | Set-Content $log

L "--- backup current sysdir system.img ---"
$cur = "$sysdir\system.img"
$bak = "$sysdir\system.img.phase2a-backup"
if (Test-Path $bak) { L "backup already exists: $bak ($((Get-Item $bak).Length) B) sha=$((Get-FileHash $bak -Algorithm SHA256).Hash)" }
else {
  Copy-Item $cur $bak -Force
  L "backup created: $bak ($((Get-Item $bak).Length) B) sha=$((Get-FileHash $bak -Algorithm SHA256).Hash)"
}

L "--- concat parts ---"
$gz = "$work\treeos-final.tar.gz"
$out = [System.IO.File]::Create($gz)
try {
  foreach ($i in 0..3) {
    $p = "$work\finalgz.part0$i"
    $in = [System.IO.File]::OpenRead($p)
    $in.CopyTo($out); $in.Close()
    L "appended $p"
  }
} finally { $out.Close() }
$gzHash = (Get-FileHash $gz -Algorithm SHA256).Hash
L "GZ sha256=$gzHash bytes=$((Get-Item $gz).Length)"
if ($gzHash -ne 'B9C7A3F92FE0EC6E604DA5C7D180D9F471B3444EF9DBA901F83D1351F324CA18') { L 'SHIP_ABORT=gz hash mismatch'; exit 4 }
L "GZ_HASH=PASS"

L "--- extract ---"
$ex = "$work\extract"; New-Item -ItemType Directory -Force $ex | Out-Null
& tar.exe -xzf $gz -C $ex 2>&1 | Out-String | L
$img = "$ex\treeos-system-final.img"
$imgHash = (Get-FileHash $img -Algorithm SHA256).Hash
L "IMG sha256=$imgHash bytes=$((Get-Item $img).Length)"
if ($imgHash -ne '216A425BF482791CC77B566C4DF6B621C60D153B0415C874AAE4DB47E04F4BA1') { L 'SHIP_ABORT=img hash mismatch'; exit 5 }
L "IMG_HASH=PASS"

L "--- replace sysdir system.img (treeos sysdir ONLY) ---"
Copy-Item $img $cur -Force
$after = (Get-FileHash $cur -Algorithm SHA256).Hash
L "SYSDIR system.img sha256 after=$after"
if ($after -eq '216A425BF482791CC77B566C4DF6B621C60D153B0415C874AAE4DB47E04F4BA1') { L 'SHIP=PASS' } else { L 'SHIP=FAIL readback mismatch' }
L "--- sysdir VerifiedBootParams.textproto (must still carry unlock params) ---"
Get-Content "$sysdir\VerifiedBootParams.textproto" | Out-String | L
L "=== PHASE2B SHIP DONE ==="
