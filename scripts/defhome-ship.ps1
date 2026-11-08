# TreeOS default-home SHIP: apply a VM-built block delta to the Razer's pristine local copy
# of the Phase 2b image, verify the result hash, back up the outgoing sysdir image, and only
# then replace the treeos sysdir system.img.
#   -Variant   nexus | overlay | both   (selects delta-<variant>.bin/.idx in p2work\defhome)
param([Parameter(Mandatory=$true)][string]$Variant)
$ErrorActionPreference = 'Stop'
$sdk = 'C:\Users\cloud\AppData\Local\Android\Sdk'
$sysdir = "$sdk\system-images\android-35\treeos\x86_64"
$work = 'C:\Users\cloud\treeos-image\p2work\defhome'
$basePristine = 'C:\Users\cloud\treeos-image\p2work\phase2b\extract\treeos-system-final.img'
$BASE_SHA = '216A425BF482791CC77B566C4DF6B621C60D153B0415C874AAE4DB47E04F4BA1'

Write-Host "--- verify pristine base copy ---"
if (-not (Test-Path $basePristine)) { Write-Host "SHIP_ABORT=no pristine base at $basePristine"; exit 2 }
$baseHash = (Get-FileHash $basePristine -Algorithm SHA256).Hash
Write-Host "base sha256=$baseHash"
if ($baseHash -ne $BASE_SHA) { Write-Host 'SHIP_ABORT=base hash mismatch'; exit 2 }

Write-Host "--- apply delta-$Variant ---"
$idx = Get-Content "$work\delta-$Variant.bin.idx" -Raw | ConvertFrom-Json
$imgPath = "$work\img-under-test.img"
Copy-Item $basePristine $imgPath -Force
$BLOCK = [long]$idx.block_size
$img = [System.IO.File]::Open($imgPath, 'Open', 'ReadWrite')
$delta = [System.IO.File]::OpenRead("$work\delta-$Variant.bin")
try {
  $buf = New-Object byte[] $BLOCK
  $pos = 0
  foreach ($b in $idx.blocks) {
    $n = $delta.Read($buf, 0, $BLOCK)
    if ($n -ne $BLOCK) { Write-Host "SHIP_ABORT=delta short read at block $b"; exit 3 }
    $img.Seek([long]$b * $BLOCK, 'Begin') | Out-Null
    $img.Write($buf, 0, $BLOCK)
    $pos++
  }
  Write-Host "applied $pos blocks"
} finally { $img.Close(); $delta.Close() }
$got = (Get-FileHash $imgPath -Algorithm SHA256).Hash
Write-Host "result sha256=$got expected=$($idx.variant_sha256)"
if ($got -ne $idx.variant_sha256.ToUpper()) { Write-Host 'SHIP_ABORT=result hash mismatch'; exit 3 }
Write-Host "DELTA_APPLY=PASS"

Write-Host "--- back up outgoing sysdir image, then replace ---"
$cur = "$sysdir\system.img"
$curHash = (Get-FileHash $cur -Algorithm SHA256).Hash
$outBak = "$work\outgoing-$($curHash.Substring(0,8)).img"
if (-not (Test-Path $outBak)) { Copy-Item $cur $outBak -Force; Write-Host "outgoing backed up: $outBak" }
else { Write-Host "outgoing backup already present: $outBak" }
$bakHash = (Get-FileHash $outBak -Algorithm SHA256).Hash
if ($bakHash -ne $curHash) { Write-Host 'SHIP_ABORT=outgoing backup hash mismatch'; exit 4 }
Copy-Item $imgPath $cur -Force
$after = (Get-FileHash $cur -Algorithm SHA256).Hash
Write-Host "sysdir system.img sha256 after=$after"
if ($after -eq $idx.variant_sha256.ToUpper()) { Write-Host 'SHIP=PASS' } else { Write-Host 'SHIP=FAIL'; exit 5 }
Write-Host "=== DEFHOME SHIP [$Variant] DONE ==="
