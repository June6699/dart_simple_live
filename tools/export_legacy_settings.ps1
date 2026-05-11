param(
  [string]$DataDir,
  [string]$OutFile,
  [string]$DartExe
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot "simple_live_app"
$dartScript = Join-Path $appDir "tool\export_legacy_settings.dart"
$compiledExporter = Join-Path $PSScriptRoot "export_legacy_settings_windows.exe"

function Find-Dart {
  if ($DartExe -and (Test-Path -LiteralPath $DartExe)) {
    return $DartExe
  }

  $candidates = @(
    "C:\softwares\flutter\bin\dart.bat",
    "C:\softwares\flutter\bin\dart.exe",
    "C:\softwares\flutter_windows_3.41.0-stable\flutter\bin\dart.bat",
    "C:\softwares\flutter_windows_3.41.0-stable\flutter\bin\dart.exe"
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $cmd = Get-Command dart -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }
  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutter) {
    $flutterBin = Split-Path -Parent $flutter.Source
    $dartBat = Join-Path $flutterBin "dart.bat"
    $dartExe = Join-Path $flutterBin "dart.exe"
    if (Test-Path -LiteralPath $dartBat) {
      return $dartBat
    }
    if (Test-Path -LiteralPath $dartExe) {
      return $dartExe
    }
  }

  throw "Cannot find Dart. Pass -DartExe or install Flutter/Dart."
}

function Test-HiveDir([string]$Path) {
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
    return $false
  }
  $expected = @(
    "localstorage.hive",
    "danmushield.hive",
    "danmushieldpreset.hive",
    "followuser.hive",
    "followusertag.hive",
    "history.hive",
    "hostiry.hive"
  )
  foreach ($name in $expected) {
    if (Test-Path -LiteralPath (Join-Path $Path $name)) {
      return $true
    }
  }
  return $false
}

function Find-SimpleLiveDataDir {
  $roots = @(
    $env:APPDATA,
    $env:LOCALAPPDATA,
    [Environment]::GetFolderPath("MyDocuments")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  $directNames = @(
    "com.xycz\simple_live_app",
    "com.slotsun\slive",
    "simple_live_app",
    "Simple Live",
    "SimpleLive",
    "simple_live",
    "com.example.simple_live_app"
  )
  foreach ($root in $roots) {
    foreach ($name in $directNames) {
      $candidate = Join-Path $root $name
      if (Test-HiveDir $candidate) {
        return $candidate
      }
    }
  }

  foreach ($root in $roots) {
    $match = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "localstorage.hive" -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match "simple|live|Simple|Live|dart" } |
      Select-Object -First 1
    if ($match) {
      return $match.DirectoryName
    }
  }

  return $null
}

if (-not $DataDir) {
  $DataDir = Find-SimpleLiveDataDir
}
if (-not $DataDir) {
  throw "Cannot find Simple Live data directory automatically. Re-run with -DataDir, for example: .\tools\export_legacy_settings.ps1 -DataDir `"$env:APPDATA\simple_live_app`""
}
$DataDir = (Resolve-Path -LiteralPath $DataDir).Path

if (-not (Test-HiveDir $DataDir)) {
  throw "No Simple Live Hive files were found in: $DataDir"
}

if (-not $OutFile) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutFile = Join-Path ([Environment]::GetFolderPath("Desktop")) "simple-live-settings-$stamp.json"
}

if (Test-Path -LiteralPath $dartScript) {
  $dart = Find-Dart
  Push-Location $appDir
  try {
    & $dart pub get | Out-Host
    & $dart run tool/export_legacy_settings.dart --data-dir "$DataDir" --out "$OutFile"
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
} elseif (Test-Path -LiteralPath $compiledExporter) {
  & $compiledExporter --data-dir "$DataDir" --out "$OutFile"
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} else {
  throw "Cannot find exporter script or compiled exporter. Expected: $dartScript or $compiledExporter"
}

Write-Host "Exported Simple Live settings to: $OutFile"
