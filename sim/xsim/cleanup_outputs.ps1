param(
  [switch]$ArchiveLegacyXsim = $true
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Push-Location $root
try {
  $webtalkFiles = Get-ChildItem -Recurse -Force -File | Where-Object {
    $_.Name -match "webtalk|\.xsim_webtallk\.info|usage_statistics_ext_xsim\.(html|wdm|xml)|xsim_webtalk\.tcl"
  }
  $webtalkDirs = Get-ChildItem -Recurse -Force -Directory | Where-Object {
    $_.Name -eq "webtalk" -or $_.FullName -match "\\\.Xil($|\\)"
  }

  if ($webtalkFiles.Count -gt 0) {
    $webtalkFiles | Remove-Item -Force
  }
  if ($webtalkDirs.Count -gt 0) {
    $webtalkDirs | Sort-Object FullName -Descending | Remove-Item -Recurse -Force
  }

  $rootLegacyLogs = @(
    "xelab.log",
    "xelab.pb",
    "xvlog.log",
    "xvlog.pb",
    "xsim.jou",
    "xsim.log",
    "xsim_*.backup.jou",
    "xsim_*.backup.log"
  )
  foreach ($pattern in $rootLegacyLogs) {
    Get-ChildItem -Path $root -File -Filter $pattern -ErrorAction SilentlyContinue | Remove-Item -Force
  }

  if ($ArchiveLegacyXsim) {
    $legacyDir = Join-Path $root "sim\work\xsim\root_legacy"
    $archiveDir = Join-Path $root "sim\work\xsim\archive"
    if (Test-Path $legacyDir) {
      New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
      $dst = Join-Path $archiveDir "root_legacy"
      if (Test-Path $dst) {
        Remove-Item -Recurse -Force $dst
      }
      Move-Item -Path $legacyDir -Destination $dst
    }
  }

  Write-Host "Cleanup done."
  Write-Host "Removed webtalk files/dirs and root legacy Vivado logs."
} finally {
  Pop-Location
}
