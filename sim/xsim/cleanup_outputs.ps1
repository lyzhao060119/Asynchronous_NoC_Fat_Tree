param(
  [switch]$ArchiveLegacyXsim = $true
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$archiveDir = Join-Path $root "sim\work\xsim\archive"

function Get-RootLegacyItems([string]$RepoRoot) {
  $map = @{}

  $rootLegacyFiles = @(
    "xelab.log",
    "xelab.pb",
    "xvlog.log",
    "xvlog.pb",
    "xsim.jou",
    "xsim.log",
    "xsim_*.backup.jou",
    "xsim_*.backup.log",
    "*.wdb"
  )

  foreach ($pattern in $rootLegacyFiles) {
    Get-ChildItem -Path $RepoRoot -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
      $map[$_.FullName] = $_
    }
  }

  foreach ($dirName in @(".Xil", "xsim.dir", "webtalk")) {
    $full = Join-Path $RepoRoot $dirName
    if (Test-Path $full) {
      $item = Get-Item $full -Force
      $map[$item.FullName] = $item
    }
  }

  return @($map.Values)
}

function Remove-Items([object[]]$Items) {
  foreach ($item in $Items) {
    if (!(Test-Path $item.FullName)) {
      continue
    }
    if ($item.PSIsContainer) {
      Remove-Item -Path $item.FullName -Recurse -Force
    } else {
      Remove-Item -Path $item.FullName -Force
    }
  }
}

function Archive-RootLegacy([object[]]$Items, [string]$ArchiveRoot) {
  if ($Items.Count -eq 0) {
    return $null
  }
  New-Item -ItemType Directory -Force -Path $ArchiveRoot | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $dst = Join-Path $ArchiveRoot ("root_legacy_" + $stamp)
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  foreach ($item in $Items) {
    if (Test-Path $item.FullName) {
      Move-Item -Path $item.FullName -Destination (Join-Path $dst $item.Name) -Force
    }
  }
  return $dst
}

function Archive-OldRootLegacyFolder([string]$RepoRoot, [string]$ArchiveRoot) {
  $legacyDir = Join-Path $RepoRoot "sim\work\xsim\root_legacy"
  if (!(Test-Path $legacyDir)) {
    return $null
  }
  New-Item -ItemType Directory -Force -Path $ArchiveRoot | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $dst = Join-Path $ArchiveRoot ("root_legacy_existing_" + $stamp)
  Move-Item -Path $legacyDir -Destination $dst -Force
  return $dst
}

Push-Location $root
try {
  $rootLegacyItems = Get-RootLegacyItems -RepoRoot $root
  $rootArchive = $null
  if ($ArchiveLegacyXsim) {
    $rootArchive = Archive-RootLegacy -Items $rootLegacyItems -ArchiveRoot $archiveDir
  } else {
    Remove-Items -Items $rootLegacyItems
  }

  $migratedLegacy = Archive-OldRootLegacyFolder -RepoRoot $root -ArchiveRoot $archiveDir

  $webtalkFiles = Get-ChildItem -Path $root -Recurse -Force -File | Where-Object {
    $_.FullName -notlike "$archiveDir*" -and
    $_.Name -match "webtalk|\.xsim_webtallk\.info|usage_statistics_ext_xsim\.(html|wdm|xml)|xsim_webtalk\.tcl"
  }
  $webtalkDirs = Get-ChildItem -Path $root -Recurse -Force -Directory | Where-Object {
    $_.FullName -notlike "$archiveDir*" -and
    ($_.Name -eq "webtalk" -or $_.FullName -match "\\\.Xil($|\\)")
  }

  if ($webtalkFiles.Count -gt 0) {
    $webtalkFiles | ForEach-Object {
      if (Test-Path $_.FullName) {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
      }
    }
  }
  if ($webtalkDirs.Count -gt 0) {
    $webtalkDirs | Sort-Object FullName -Descending | ForEach-Object {
      if (Test-Path $_.FullName) {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Write-Host "Cleanup done."
  if ($ArchiveLegacyXsim -and $rootArchive) {
    Write-Host "Archived root legacy Vivado outputs to: $rootArchive"
  } else {
    Write-Host "Removed root legacy Vivado outputs."
  }
  if ($migratedLegacy) {
    Write-Host "Archived legacy sim/work/xsim/root_legacy to: $migratedLegacy"
  }
  Write-Host "Removed webtalk files/dirs outside archive."
} finally {
  Pop-Location
}
