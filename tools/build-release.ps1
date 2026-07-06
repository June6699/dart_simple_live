param(
  [ValidateSet("AllLocal", "All", "Windows", "Android", "TVWindows", "TVAndroid", "Linux", "IOS", "MacOS")]
  [string[]]$Target = @("AllLocal"),

  [string]$ReleaseName,
  [switch]$KeepBuild,
  [switch]$DryRun,
  [switch]$AllowGitHubActions,
  [string]$Ref = "master",
  [string]$Proxy = "http://127.0.0.1:51888",
  [switch]$NoProxy,
  [string]$GitHubRepo = "June6699/dart_simple_live_own"
)

$ErrorActionPreference = "Stop"

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom
$PSDefaultParameterValues["Out-File:Encoding"] = "utf8"
$PSDefaultParameterValues["Set-Content:Encoding"] = "utf8"
$PSDefaultParameterValues["Add-Content:Encoding"] = "utf8"

$ScriptPath = $MyInvocation.MyCommand.Path
$ToolsDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ToolsDir
$AppDir = Join-Path $RepoRoot "simple_live_app"
$TvDir = Join-Path $RepoRoot "simple_live_tv_app"
$ReleaseRoot = Join-Path $RepoRoot "release"
$ExperiencePath = Join-Path $RepoRoot ".codex\project-experience.md"

$Flutter = "C:\softwares\flutter\bin\flutter.bat"
$FlutterRoot = "C:\softwares\flutter"
$AndroidSdk = "C:\softwares\Android_Sdk"
$Gh = "C:\softwares\GitHubCli\gh.exe"
$VsCMake = "C:\softwares\Visual Studio Workspace\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$NuGet = "C:\softwares\nuget\nuget.exe"
$ProxyClient = "C:\softwares\v2rayN-windows-64\v2rayN.exe"

$script:LogDir = $null
$script:ReleaseDir = $null
$script:Artifacts = @()
$script:LocalAppBuildTouched = $false
$script:LocalTvBuildTouched = $false
$script:LastRecordedFailure = $null
$script:ExternalStagingDirs = @()

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Write-Note {
  param([string]$Message)
  Write-Host "    $Message"
}

function ConvertTo-SafeName {
  param([string]$Name)
  return ($Name -replace "[^\w\.-]+", "_")
}

function Quote-Arg {
  param([string]$Value)
  if ($null -eq $Value) { return "" }
  if ($Value -match "[\s`"']") {
    return '"' + ($Value -replace '"', '\"') + '"'
  }
  return $Value
}

function Format-CommandLine {
  param([string]$WorkingDirectory, [string]$FilePath, [string[]]$Arguments)
  $parts = @("&", (Quote-Arg $FilePath))
  foreach ($arg in $Arguments) {
    $parts += (Quote-Arg $arg)
  }
  return "cd $(Quote-Arg $WorkingDirectory); " + ($parts -join " ")
}

function Get-PubspecVersionName {
  param([string]$ProjectDir)
  $pubspec = Join-Path $ProjectDir "pubspec.yaml"
  $text = [System.IO.File]::ReadAllText($pubspec, $Utf8NoBom)
  if ($text -notmatch "(?m)^version:\s*([^\s#]+)") {
    throw "Cannot read version from $pubspec"
  }
  return (($Matches[1] -split "\+")[0])
}

function Add-UniqueTarget {
  param([System.Collections.ArrayList]$List, [string]$Value)
  if (-not $List.Contains($Value)) {
    [void]$List.Add($Value)
  }
}

function Resolve-Targets {
  $result = New-Object System.Collections.ArrayList
  foreach ($item in $Target) {
    switch ($item) {
      "AllLocal" {
        Add-UniqueTarget $result "Windows"
        Add-UniqueTarget $result "Android"
        Add-UniqueTarget $result "TVWindows"
        Add-UniqueTarget $result "TVAndroid"
      }
      "All" {
        Add-UniqueTarget $result "Windows"
        Add-UniqueTarget $result "Android"
        Add-UniqueTarget $result "TVWindows"
        Add-UniqueTarget $result "TVAndroid"
        Add-UniqueTarget $result "Linux"
        Add-UniqueTarget $result "IOS"
        Add-UniqueTarget $result "MacOS"
      }
      default {
        Add-UniqueTarget $result $item
      }
    }
  }
  return @($result)
}

function Test-TargetIn {
  param([string[]]$Targets, [string[]]$Set)
  foreach ($item in $Targets) {
    if ($Set -contains $item) {
      return $true
    }
  }
  return $false
}

function Resolve-ReleaseName {
  param([string[]]$Targets, [string]$AppVersion, [string]$TvVersion)
  if (-not [string]::IsNullOrWhiteSpace($ReleaseName)) {
    return $ReleaseName
  }
  $mainTargets = @("Windows", "Android", "Linux", "IOS", "MacOS")
  $tvTargets = @("TVWindows", "TVAndroid")
  $hasMain = Test-TargetIn $Targets $mainTargets
  $hasTv = Test-TargetIn $Targets $tvTargets
  if ($hasMain -and -not $hasTv) {
    return "v$AppVersion"
  }
  if ($hasTv -and -not $hasMain) {
    return "tv_v$TvVersion"
  }
  return "v$AppVersion`_tv_v$TvVersion"
}

function Ensure-Directory {
  param([string]$Path)
  if ($DryRun) {
    Write-Note "[dry-run] ensure directory $Path"
    return
  }
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Get-LogTail {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) {
    $latestLog = Get-ChildItem -LiteralPath $Path -Filter "*.log" -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if (-not $latestLog) {
      return ""
    }
    $Path = $latestLog.FullName
  }
  $tail = Get-Content -LiteralPath $Path -Encoding UTF8 -Tail 20 -ErrorAction SilentlyContinue
  $text = (($tail | ForEach-Object { "$_" }) -join " ")
  if ($text.Length -gt 900) {
    return $text.Substring(0, 900) + "..."
  }
  return $text
}

function Add-BuildFailureExperience {
  param(
    [string]$Name,
    [string]$Command,
    [string]$LogPath,
    [string]$Suggestion
  )

  if ($DryRun) {
    return
  }

  $fingerprint = "$Name|$Command|$LogPath"
  if ($script:LastRecordedFailure -eq $fingerprint) {
    return
  }
  $script:LastRecordedFailure = $fingerprint

  $experienceDir = Split-Path -Parent $ExperiencePath
  New-Item -ItemType Directory -Force -Path $experienceDir | Out-Null
  if (-not (Test-Path -LiteralPath $ExperiencePath)) {
    $header = "# Project Experience: dart_simple_live`r`n`r`nThis file records reusable lessons for this project. Keep entries short, actionable, and free of secrets.`r`n`r`n## Entries`r`n"
    [System.IO.File]::WriteAllText($ExperiencePath, $header, $Utf8NoBom)
  }

  $date = Get-Date -Format "yyyy-MM-dd"
  $tail = Get-LogTail $LogPath
  if ([string]::IsNullOrWhiteSpace($tail)) {
    $tail = "No log tail captured."
  }

  $entry = @"

### $date | failure | Build script: $Name

- Source: tools\build-release.ps1
- Command: ``$Command``
- Log: ``$LogPath``
- Symptom: $tail
- Next action: $Suggestion
"@
  [System.IO.File]::AppendAllText($ExperiencePath, $entry + "`r`n", $Utf8NoBom)
}

function Invoke-LoggedCommand {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$Suggestion = "Open the log, fix the root cause, then rerun the same target.",
    [switch]$ContinueOnFailure
  )

  $commandText = Format-CommandLine $WorkingDirectory $FilePath $Arguments
  $safeName = ConvertTo-SafeName $Name
  $logPath = if ($script:LogDir) { Join-Path $script:LogDir "$safeName.log" } else { Join-Path $RepoRoot "$safeName.log" }

  if ($DryRun) {
    Write-Host "[dry-run] $commandText"
    return $true
  }

  Ensure-Directory $script:LogDir
  Write-Step $Name
  Write-Note $commandText
  $result = Invoke-CapturedCommand $WorkingDirectory $FilePath $Arguments

  $result.Output | ForEach-Object { Write-Host $_ }
  $result.Output | Out-File -FilePath $logPath -Encoding UTF8

  if ($result.ExitCode -ne 0) {
    if ((-not $NoProxy) -and (Test-LikelyNetworkFailure $result.Output)) {
      Write-Note "Command looks like a network failure. Starting/checking v2rayN and retrying once through $Proxy."
      Start-ProxyClient
      Set-ProxyEnvironment
      $retry = Invoke-CapturedCommand $WorkingDirectory $FilePath $Arguments
      $retryLogPath = Join-Path $script:LogDir "$safeName.retry.log"
      $retry.Output | ForEach-Object { Write-Host $_ }
      $retry.Output | Out-File -FilePath $retryLogPath -Encoding UTF8
      if ($retry.ExitCode -eq 0) {
        return $true
      }
      Add-BuildFailureExperience -Name "$Name-network-retry" -Command $commandText -LogPath $retryLogPath -Suggestion "The URL may be correct but network/proxy still failed. Confirm v2rayN is running on 127.0.0.1:51888, then check small issues such as ref, auth, file path, release/tag existence, or corrupted local cache before retrying."
    } else {
      Add-BuildFailureExperience -Name $Name -Command $commandText -LogPath $logPath -Suggestion $Suggestion
    }
    if ($ContinueOnFailure) {
      Write-Host "Command failed but fallback is enabled. Log: $logPath"
      return $false
    }
    throw "Command failed: $Name. Log: $logPath"
  }
  return $true
}

function Invoke-CapturedCommand {
  param([string]$WorkingDirectory, [string]$FilePath, [string[]]$Arguments)
  Push-Location $WorkingDirectory
  $exitCode = 0
  $oldErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) {
      $exitCode = 0
    }
  } catch {
    $output = @($_.Exception.Message)
    $exitCode = 1
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    Pop-Location
  }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = @($output)
  }
}

function Test-LikelyNetworkFailure {
  param([object[]]$Output)
  $text = (($Output | ForEach-Object { "$_" }) -join "`n")
  return $text -match "(?i)(timed out|timeout|connection reset|connection refused|failed to connect|could not resolve|network is unreachable|tls handshake|ssl|certificate|unable to access|failed host lookup|connection closed|recv failure|send failure|502|503|504|下载|连接|网络|代理)"
}

function Set-ProxyEnvironment {
  if ($NoProxy) {
    return
  }
  $env:HTTP_PROXY = $Proxy
  $env:HTTPS_PROXY = $Proxy
  $env:ALL_PROXY = $Proxy
}

function Start-ProxyClient {
  if ($NoProxy) {
    return
  }
  $uri = $null
  try {
    $uri = [System.Uri]$Proxy
  } catch {
    return
  }
  $hostName = $uri.Host
  $port = $uri.Port
  if ([string]::IsNullOrWhiteSpace($hostName) -or $port -le 0) {
    return
  }
  if (Test-TcpPort $hostName $port) {
    return
  }
  if (Test-Path -LiteralPath $ProxyClient) {
    Write-Note "Proxy port $hostName`:$port is not open. Starting $ProxyClient"
    Start-Process -FilePath $ProxyClient -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 3
  }
}

function Test-TcpPort {
  param([string]$HostName, [int]$Port)
  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $iar = $client.BeginConnect($HostName, $Port, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne(700, $false)) {
      return $false
    }
    $client.EndConnect($iar)
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

function Find-Jdk {
  $candidates = @(
    "C:\softwares\jdk-17",
    "C:\softwares\jdk-21",
    "C:\softwares\Android Studio\jbr",
    "C:\Program Files\Android\Android Studio\jbr",
    "C:\Program Files (x86)\Android\Android Studio\jbr"
  )
  if ($env:JAVA_HOME) {
    $candidates += $env:JAVA_HOME
  }
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "bin\java.exe"))) {
      return $candidate
    }
  }
  throw "JDK not found. Install JDK 17+ or Android Studio JBR under C:\softwares."
}

function Set-CommonEnvironment {
  Set-ProxyEnvironment
  Start-ProxyClient
  $pathPrefixes = @("C:\softwares\flutter\bin")
  if (Test-Path -LiteralPath $NuGet) {
    $pathPrefixes += (Split-Path -Parent $NuGet)
  }
  $env:PATH = (($pathPrefixes | Select-Object -Unique) -join ";") + ";$env:PATH"
}

function Set-AndroidEnvironment {
  $jdk = Find-Jdk
  $env:JAVA_HOME = $jdk
  $env:ANDROID_HOME = $AndroidSdk
  $env:ANDROID_SDK_ROOT = $AndroidSdk
  $env:PATH = "C:\softwares\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"
  Write-Note "JAVA_HOME=$env:JAVA_HOME"
  Write-Note "ANDROID_HOME=$env:ANDROID_HOME"
}

function Ensure-Tool {
  param([string]$Path, [string]$Name)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Name not found: $Path"
  }
}

function Get-CurlProxy {
  if ($NoProxy -or [string]::IsNullOrWhiteSpace($Proxy)) {
    return $null
  }
  if ($Proxy -match "^https?://127\.0\.0\.1:51888/?$") {
    return "socks5h://127.0.0.1:51888"
  }
  return $Proxy
}

function Ensure-ArchiveMd5 {
  param(
    [string]$Path,
    [string]$Url,
    [string]$ExpectedMd5,
    [string]$Name
  )

  if ($DryRun) {
    Write-Note "[dry-run] ensure $Name archive $Path"
    return
  }

  if (Test-Path -LiteralPath $Path) {
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant()
    if ($hash -eq $ExpectedMd5.ToLowerInvariant()) {
      return
    }
    Write-Note "$Name archive MD5 mismatch or corrupt. Removing $Path"
    Remove-Item -LiteralPath $Path -Force
  }

  $tmp = "$Path.download"
  if (Test-Path -LiteralPath $tmp) {
    Remove-Item -LiteralPath $tmp -Force
  }
  $curlArgs = @("-L", "--retry", "3", "--retry-delay", "2", "--connect-timeout", "20", "--output", $tmp)
  $curlProxy = Get-CurlProxy
  if (-not [string]::IsNullOrWhiteSpace($curlProxy)) {
    $curlArgs = @("--proxy", $curlProxy) + $curlArgs
  }
  $curlArgs += $Url

  Write-Note "Downloading $Name archive through curl.exe"
  & curl.exe @curlArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to download $Name archive: $Url"
  }
  $hash = (Get-FileHash -LiteralPath $tmp -Algorithm MD5).Hash.ToLowerInvariant()
  if ($hash -ne $ExpectedMd5.ToLowerInvariant()) {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    throw "$Name archive MD5 mismatch. Expected $ExpectedMd5, got $hash"
  }
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Ensure-WindowsMediaKitArchives {
  param([string]$ProjectDir)

  $x64Dir = Join-Path $ProjectDir "build\windows\x64"
  Ensure-Directory $x64Dir
  Ensure-ArchiveMd5 `
    -Path (Join-Path $x64Dir "mpv-dev-x86_64-20230924-git-652a1dd.7z") `
    -Url "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z" `
    -ExpectedMd5 "a832ef24b3a6ff97cd2560b5b9d04cd8" `
    -Name "libmpv"
  Ensure-ArchiveMd5 `
    -Path (Join-Path $x64Dir "ANGLE.7z") `
    -Url "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z" `
    -ExpectedMd5 "e866f13e8d552348058afaafe869b1ed" `
    -Name "ANGLE"
}

function Ensure-AndroidLocalProperties {
  param([string]$ProjectDir)
  $androidDir = Join-Path $ProjectDir "android"
  $localProperties = Join-Path $androidDir "local.properties"
  $required = @(
    "sdk.dir=C:\\softwares\\Android_Sdk",
    "flutter.sdk=C:\\softwares\\flutter"
  )
  if ($DryRun) {
    Write-Note "[dry-run] ensure $localProperties contains sdk.dir and flutter.sdk"
    return
  }
  $existing = ""
  if (Test-Path -LiteralPath $localProperties) {
    $existing = [System.IO.File]::ReadAllText($localProperties, $Utf8NoBom)
  }
  $lines = New-Object System.Collections.Generic.List[string]
  if (-not [string]::IsNullOrWhiteSpace($existing)) {
    foreach ($line in ($existing -split "\r?\n")) {
      if ($line.Length -gt 0) {
        $lines.Add($line)
      }
    }
  }
  if ($existing -notmatch "(?m)^sdk\.dir=") {
    $lines.Add($required[0])
  }
  if ($existing -notmatch "(?m)^flutter\.sdk=") {
    $lines.Add($required[1])
  }
  if ($lines.Count -eq 0) {
    $lines.AddRange($required)
  }
  $body = ($lines -join "`r`n") + "`r`n"
  [System.IO.File]::WriteAllText($localProperties, $body, $Utf8NoBom)
}

function Assert-WithinRepo {
  param([string]$Path)
  $fullRepo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd("\")
  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
  if (-not $fullPath.StartsWith($fullRepo + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to touch path outside repo: $fullPath"
  }
}

function Test-PackageDir {
  param([string]$Dir, [string[]]$Required)
  if (-not (Test-Path -LiteralPath $Dir)) {
    return $false
  }
  foreach ($item in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Dir $item))) {
      return $false
    }
  }
  return $true
}

function New-ZipFromDirectoryContents {
  param([string]$SourceDir, [string]$ZipPath)
  if ($DryRun) {
    Write-Note "[dry-run] zip contents of $SourceDir -> $ZipPath"
    return
  }
  if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
  }
  Compress-Archive -Path (Join-Path $SourceDir "*") -DestinationPath $ZipPath -Force
}

function Assert-ZipEntries {
  param([string]$ZipPath, [string[]]$Entries)
  if ($DryRun) {
    Write-Note "[dry-run] verify zip entries in $ZipPath"
    return
  }
  $actual = tar.exe -tf $ZipPath | ForEach-Object { $_ -replace "\\", "/" }
  foreach ($entry in $Entries) {
    $normalizedEntry = $entry -replace "\\", "/"
    if ($actual -notcontains $normalizedEntry) {
      throw "Zip is missing required entry '$normalizedEntry': $ZipPath"
    }
  }
}

function Test-ArchiveEntries {
  param([string]$Path, [string[]]$Entries)
  if (-not (Test-Path -LiteralPath $Path)) {
    return $false
  }
  $actual = tar.exe -tf $Path
  foreach ($entry in $Entries) {
    if ($actual -notcontains $entry) {
      return $false
    }
  }
  return $true
}

function Assert-ApkEntries {
  param([string]$ApkPath, [string[]]$Entries)
  if ($DryRun) {
    Write-Note "[dry-run] verify APK entries in $ApkPath"
    return
  }
  if (-not (Test-ArchiveEntries $ApkPath $Entries)) {
    throw "APK is missing required entries '$($Entries -join ', ')': $ApkPath"
  }
}

function Add-Artifact {
  param([string]$Path, [string]$Kind)
  if ($DryRun) {
    return
  }
  $item = Get-Item -LiteralPath $Path
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  $script:Artifacts += [pscustomobject]@{
    Kind = $Kind
    Path = $item.FullName
    SizeMB = [math]::Round($item.Length / 1MB, 2)
    SHA256 = $hash.Hash
  }
}

function Copy-ArtifactFile {
  param([string]$Source, [string]$Destination, [string]$Kind)
  if ($DryRun) {
    Write-Note "[dry-run] copy $Source -> $Destination"
    return
  }
  if (-not (Test-Path -LiteralPath $Source)) {
    throw "Artifact not found: $Source"
  }
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
  Add-Artifact -Path $Destination -Kind $Kind
}

function Get-QuickJsAndroidNativeAssets {
  param([string]$ProjectDir)
  $hookRoot = Join-Path $ProjectDir ".dart_tool\hooks_runner\dart_quickjs"
  if (-not (Test-Path -LiteralPath $hookRoot)) {
    return @()
  }
  $abiByArch = @{
    arm = "armeabi-v7a"
    arm64 = "arm64-v8a"
    x64 = "x86_64"
  }
  $candidates = @()
  $outputFiles = Get-ChildItem -LiteralPath $hookRoot -Recurse -File -Filter "output.json" -ErrorAction SilentlyContinue
  foreach ($outputFile in $outputFiles) {
    $inputFile = Join-Path $outputFile.DirectoryName "input.json"
    if (-not (Test-Path -LiteralPath $inputFile)) {
      continue
    }
    try {
      $input = Get-Content -LiteralPath $inputFile -Encoding UTF8 -Raw | ConvertFrom-Json
      $output = Get-Content -LiteralPath $outputFile.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
    } catch {
      Write-Note "QuickJS native asset metadata read skipped: $($_.Exception.Message)"
      continue
    }
    $codeAssets = $input.config.extensions.code_assets
    if ($null -eq $codeAssets -or [string]$codeAssets.target_os -ne "android") {
      continue
    }
    $arch = [string]$codeAssets.target_architecture
    if (-not $abiByArch.ContainsKey($arch)) {
      continue
    }
    foreach ($asset in @($output.assets)) {
      if ([string]$asset.type -ne "code_assets/code") {
        continue
      }
      $encoding = $asset.encoding
      if ($null -eq $encoding) {
        continue
      }
      if ([string]$encoding.id -ne "package:dart_quickjs/src/quickjs_bindings.g.dart") {
        continue
      }
      $file = [string]$encoding.file
      if (-not (Test-Path -LiteralPath $file)) {
        continue
      }
      $item = Get-Item -LiteralPath $file
      $candidates += [pscustomobject]@{
        Abi = $abiByArch[$arch]
        Source = $item.FullName
        LinkingEnabled = [bool]$input.config.linking_enabled
        LastWriteTime = $item.LastWriteTime
      }
    }
  }

  $selected = @()
  foreach ($abi in @("armeabi-v7a", "arm64-v8a", "x86_64")) {
    $abiCandidates = @($candidates | Where-Object { $_.Abi -eq $abi })
    $preferred = @($abiCandidates | Where-Object { $_.LinkingEnabled })
    if ($preferred.Count -eq 0) {
      $preferred = $abiCandidates
    }
    $match = $preferred | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($match) {
      $selected += $match
    }
  }
  return $selected
}

function Get-AndroidQuickJsGeneratedDir {
  param([string]$ProjectDir)
  return (Join-Path $ProjectDir "android\app\build\generated\dart_quickjs\jniLibs")
}

function Test-AndroidNativeAssetsQuickJs {
  param([string]$ProjectDir)
  $jniRoot = Join-Path $ProjectDir "build\native_assets\android\jniLibs\lib"
  foreach ($abi in @("armeabi-v7a", "arm64-v8a", "x86_64")) {
    $so = Join-Path $jniRoot "$abi\libdart_quickjs.so"
    if (-not (Test-Path -LiteralPath $so)) {
      return $false
    }
    if ((Get-Item -LiteralPath $so).Length -le 0) {
      return $false
    }
  }
  return $true
}

function Clear-GeneratedQuickJsAndroidJniLibs {
  param([string]$ProjectDir)
  $jniRoot = Get-AndroidQuickJsGeneratedDir $ProjectDir
  if ($DryRun) {
    Write-Note "[dry-run] clear generated dart_quickjs Android JNI libraries"
    return
  }
  if (Test-Path -LiteralPath $jniRoot) {
    Remove-Item -LiteralPath $jniRoot -Recurse -Force
    Write-Note "Cleared generated dart_quickjs Android JNI libraries from $jniRoot"
  }
}

function Sync-QuickJsAndroidJniLibsIfNeeded {
  param([string]$ProjectDir, [switch]$Required)
  Clear-GeneratedQuickJsAndroidJniLibs $ProjectDir
  if (Test-AndroidNativeAssetsQuickJs $ProjectDir) {
    Write-Note "Using Flutter native assets for dart_quickjs Android libraries."
    return $true
  }
  return (Sync-QuickJsAndroidJniLibs $ProjectDir -Required:$Required)
}

function Sync-QuickJsAndroidJniLibs {
  param([string]$ProjectDir, [switch]$Required)
  if ($DryRun) {
    Write-Note "[dry-run] sync dart_quickjs Android native libraries"
    return $true
  }
  $assets = @(Get-QuickJsAndroidNativeAssets $ProjectDir)
  if ($assets.Count -eq 0) {
    if ($Required) {
      throw "No dart_quickjs Android native assets were found under $ProjectDir\.dart_tool\hooks_runner."
    }
    return $false
  }

  $jniRoot = Join-Path $ProjectDir "android\app\build\generated\dart_quickjs\jniLibs"
  $synced = @{}
  foreach ($asset in $assets) {
    $destDir = Join-Path $jniRoot $asset.Abi
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $dest = Join-Path $destDir "libdart_quickjs.so"
    Copy-Item -LiteralPath $asset.Source -Destination $dest -Force
    $synced[$asset.Abi] = $dest
  }

  $missing = @("armeabi-v7a", "arm64-v8a", "x86_64") | Where-Object { -not $synced.ContainsKey($_) }
  if ($missing.Count -gt 0) {
    if ($Required) {
      throw "Missing dart_quickjs Android native assets for ABI: $($missing -join ', ')"
    }
    Write-Note "QuickJS Android native assets are incomplete; missing: $($missing -join ', ')"
    return $false
  }

  Write-Note "Synced dart_quickjs Android native libraries to $jniRoot"
  return $true
}

function Test-SplitApksQuickJs {
  param([string]$ApkDir)
  $map = @(
    @{ Source = "app-armeabi-v7a-release.apk"; Abi = "armeabi-v7a" },
    @{ Source = "app-arm64-v8a-release.apk"; Abi = "arm64-v8a" },
    @{ Source = "app-x86_64-release.apk"; Abi = "x86_64" }
  )
  foreach ($item in $map) {
    $apk = Join-Path $ApkDir $item.Source
    if (-not (Test-ArchiveEntries $apk @("lib/$($item.Abi)/libdart_quickjs.so"))) {
      return $false
    }
  }
  return $true
}

function Build-Windows {
  param([string]$AppVersion)
  $script:LocalAppBuildTouched = $true
  Ensure-Tool $Flutter "Flutter"
  if (Test-Path -LiteralPath $NuGet) {
    $env:PATH = "$(Split-Path -Parent $NuGet);$env:PATH"
  }
  $null = Invoke-LoggedCommand "windows-pub-get" $AppDir $Flutter @("pub", "get")
  Ensure-Directory (Join-Path $AppDir "build\native_assets\windows")
  Ensure-WindowsMediaKitArchives $AppDir
  $null = Invoke-LoggedCommand "windows-build" $AppDir $Flutter @("build", "windows", "--release") "If NUGET-NOTFOUND appears, ensure C:\softwares\nuget is on PATH and clear build\windows\x64\CMakeCache.txt plus CMakeFiles. If media_kit archive integrity fails, delete the broken archive, prefill it through proxy 127.0.0.1:51888, verify MD5, and rerun."

  $zip = Join-Path $script:ReleaseDir "SimpleLive-Windows-v$AppVersion.zip"
  if ($DryRun) {
    Write-Note "[dry-run] would package Windows zip -> $zip"
    return
  }

  $runner = Join-Path $AppDir "build\windows\x64\runner\Release"
  $install = Join-Path $AppDir "build\windows\x64\install"
  $nativeAssetsDir = Join-Path $AppDir "build\native_assets\windows"
  $nativeAssetsManifest = Join-Path $runner "data\flutter_assets\NativeAssetsManifest.json"
  $required = @("simple_live_app.exe", "flutter_windows.dll", "data\flutter_assets\AssetManifest.bin", "data\flutter_assets\NativeAssetsManifest.json", "dart_quickjs.dll")
  $requiredBase = @("simple_live_app.exe", "flutter_windows.dll", "data\flutter_assets\AssetManifest.bin", "data\flutter_assets\NativeAssetsManifest.json")
  $stage = Join-Path $script:ReleaseDir "SimpleLive-Windows-v$AppVersion"

  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  $quickJsCandidates = @(
    (Join-Path $install "dart_quickjs.dll"),
    (Join-Path $runner "dart_quickjs.dll"),
    (Join-Path $nativeAssetsDir "dart_quickjs.dll")
  )
  if (Test-Path -LiteralPath $nativeAssetsManifest) {
    try {
      $manifestText = [System.IO.File]::ReadAllText($nativeAssetsManifest, $Utf8NoBom)
      if ($manifestText -match 'dart_quickjs\.dll') {
        $manifestDir = Split-Path -Parent $nativeAssetsManifest
        $quickJsCandidates += (Join-Path $manifestDir "dart_quickjs.dll")
      }
    } catch {
      Write-Note "NativeAssetsManifest read skipped: $($_.Exception.Message)"
    }
  }
  $hookDlls = Get-ChildItem -Path (Join-Path $AppDir ".dart_tool") -Recurse -File -Filter "dart_quickjs.dll" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -ExpandProperty FullName
  if ($hookDlls) {
    $quickJsCandidates += $hookDlls
  }
  $quickJsPath = $quickJsCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1

  if (Test-PackageDir $install $required) {
    $source = $install
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $stage -Recurse -Force
  } elseif (Test-PackageDir $runner $requiredBase) {
    $source = $runner
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $stage -Recurse -Force
    if ($quickJsPath) {
      Copy-Item -LiteralPath $quickJsPath -Destination (Join-Path $stage "dart_quickjs.dll") -Force
    }
  } else {
    throw "Windows package directory is incomplete. Checked $runner and $install."
  }

  if (-not (Test-PackageDir $stage $required)) {
    throw "Windows package staging directory is incomplete: $stage"
  }

  New-ZipFromDirectoryContents $stage $zip
  Assert-ZipEntries $zip @("simple_live_app.exe", "flutter_windows.dll", "dart_quickjs.dll", "data/flutter_assets/AssetManifest.bin", "data/flutter_assets/NativeAssetsManifest.json")
  Add-Artifact -Path $zip -Kind "Windows"
}

function Build-TVWindows {
  param([string]$TvVersion)
  $script:LocalTvBuildTouched = $true
  Ensure-Tool $Flutter "Flutter"
  if (Test-Path -LiteralPath $NuGet) {
    $env:PATH = "$(Split-Path -Parent $NuGet);$env:PATH"
  }
  $null = Invoke-LoggedCommand "tv-windows-pub-get" $TvDir $Flutter @("pub", "get")
  Ensure-WindowsMediaKitArchives $TvDir
  $null = Invoke-LoggedCommand "tv-windows-build" $TvDir $Flutter @("build", "windows", "--release") "If NUGET-NOTFOUND appears, ensure C:\softwares\nuget is on PATH and clear build\windows\x64\CMakeCache.txt plus CMakeFiles. If media_kit archive integrity fails, delete the broken archive, prefill it through proxy 127.0.0.1:51888, verify MD5, and rerun."

  $zip = Join-Path $script:ReleaseDir "SimpleLiveTV-Windows-tv_v$TvVersion.zip"
  if ($DryRun) {
    Write-Note "[dry-run] would package TV-Windows zip from simple_live_tv_app\build\windows\x64\install -> $zip"
    return
  }

  $install = Join-Path $TvDir "build\windows\x64\install"
  $runner = Join-Path $TvDir "build\windows\x64\runner\Release"
  $nativeAssetsDir = Join-Path $TvDir "build\native_assets\windows"
  $nativeAssetsManifest = Join-Path $install "data\flutter_assets\NativeAssetsManifest.json"
  $required = @("simple_live_tv_app.exe", "flutter_windows.dll", "libmpv-2.dll", "data\app.so", "data\flutter_assets\AssetManifest.bin", "data\flutter_assets\NativeAssetsManifest.json", "dart_quickjs.dll")
  $requiredBase = @("simple_live_tv_app.exe", "flutter_windows.dll", "libmpv-2.dll", "data\app.so", "data\flutter_assets\AssetManifest.bin", "data\flutter_assets\NativeAssetsManifest.json")
  if (-not (Test-PackageDir $install $requiredBase)) {
    $x64 = Join-Path $TvDir "build\windows\x64"
    if (Test-Path -LiteralPath $VsCMake) {
      $null = Invoke-LoggedCommand "tv-windows-fix-install-prefix" $x64 $VsCMake @("-DCMAKE_INSTALL_PREFIX=C:/softwares/dart_simple_live/simple_live_tv_app/build/windows/x64/install", ".") "CMake install prefix should point to simple_live_tv_app/build/windows/x64/install."
      $null = Invoke-LoggedCommand "tv-windows-rebuild-after-prefix" $TvDir $Flutter @("build", "windows", "--release")
    }
  }

  $quickJsCandidates = @(
    (Join-Path $install "dart_quickjs.dll"),
    (Join-Path $runner "dart_quickjs.dll"),
    (Join-Path $nativeAssetsDir "dart_quickjs.dll")
  )
  if (Test-Path -LiteralPath $nativeAssetsManifest) {
    try {
      $manifestText = [System.IO.File]::ReadAllText($nativeAssetsManifest, $Utf8NoBom)
      if ($manifestText -match 'dart_quickjs\.dll') {
        $manifestDir = Split-Path -Parent $nativeAssetsManifest
        $quickJsCandidates += (Join-Path $manifestDir "dart_quickjs.dll")
      }
    } catch {
      Write-Note "TV NativeAssetsManifest read skipped: $($_.Exception.Message)"
    }
  }
  $hookDlls = Get-ChildItem -Path (Join-Path $TvDir ".dart_tool") -Recurse -File -Filter "dart_quickjs.dll" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -ExpandProperty FullName
  if ($hookDlls) {
    $quickJsCandidates += $hookDlls
  }
  $quickJsPath = $quickJsCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -First 1
  if ((Test-PackageDir $install $requiredBase) -and -not (Test-Path -LiteralPath (Join-Path $install "dart_quickjs.dll")) -and $quickJsPath) {
    Copy-Item -LiteralPath $quickJsPath -Destination (Join-Path $install "dart_quickjs.dll") -Force
  }

  if (-not (Test-PackageDir $install $required)) {
    throw "TV-Windows install directory is incomplete: $install"
  }

  New-ZipFromDirectoryContents $install $zip
  Assert-ZipEntries $zip @("simple_live_tv_app.exe", "flutter_windows.dll", "libmpv-2.dll", "media_kit_video_plugin.dll", "dart_quickjs.dll", "data/app.so", "data/flutter_assets/AssetManifest.bin", "data/flutter_assets/NativeAssetsManifest.json")
  Add-Artifact -Path $zip -Kind "TVWindows"

  $extractedDir = Join-Path $script:ReleaseDir "SimpleLiveTV-Windows-tv_v$TvVersion"
  if (Test-Path -LiteralPath $extractedDir) {
    Remove-Item -LiteralPath $extractedDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $extractedDir | Out-Null
  Get-ChildItem -LiteralPath $install -Force | Copy-Item -Destination $extractedDir -Recurse -Force
  if (-not (Test-PackageDir $extractedDir $required)) {
    throw "Extracted TV-Windows release directory is incomplete: $extractedDir"
  }
  Write-Note "TV-Windows extracted directory: $extractedDir"
}

function Copy-SplitApks {
  param([string]$ApkDir, [string]$Prefix, [string]$Kind)
  $map = @(
    @{ Source = "app-armeabi-v7a-release.apk"; Abi = "armeabi-v7a" },
    @{ Source = "app-arm64-v8a-release.apk"; Abi = "arm64-v8a" },
    @{ Source = "app-x86_64-release.apk"; Abi = "x86_64" }
  )
  foreach ($item in $map) {
    $src = Join-Path $ApkDir $item.Source
    if (-not (Test-Path -LiteralPath $src)) {
      return $false
    }
  }
  foreach ($item in $map) {
    $src = Join-Path $ApkDir $item.Source
    Assert-ApkEntries $src @("lib/$($item.Abi)/libdart_quickjs.so")
    $dest = Join-Path $script:ReleaseDir "$Prefix-$($item.Abi)-release.apk"
    Copy-ArtifactFile $src $dest $Kind
  }
  return $true
}

function Build-SingleAbiApks {
  param([string]$ProjectDir, [string]$Prefix, [string]$Kind)
  $apkDir = Join-Path $ProjectDir "build\app\outputs\flutter-apk"
  $abis = @(
    @{ Platform = "android-arm"; Abi = "armeabi-v7a" },
    @{ Platform = "android-arm64"; Abi = "arm64-v8a" },
    @{ Platform = "android-x64"; Abi = "x86_64" }
  )
  foreach ($abi in $abis) {
    $null = Invoke-LoggedCommand "$Kind-single-$($abi.Abi)" $ProjectDir $Flutter @("build", "apk", "--release", "--target-platform", $abi.Platform) "Single ABI fallback failed. Check native assets and Android signing configuration."
    $src = Join-Path $apkDir "app-release.apk"
    if (-not (Test-ArchiveEntries $src @("lib/$($abi.Abi)/libdart_quickjs.so"))) {
      Write-Note "$Kind $($abi.Abi) APK is missing dart_quickjs; syncing native assets and rebuilding."
      $null = Sync-QuickJsAndroidJniLibsIfNeeded $ProjectDir -Required
      $null = Invoke-LoggedCommand "$Kind-single-$($abi.Abi)-quickjs-rebuild" $ProjectDir $Flutter @("build", "apk", "--release", "--target-platform", $abi.Platform) "Single ABI quickjs rebuild failed."
      Assert-ApkEntries $src @("lib/$($abi.Abi)/libdart_quickjs.so")
    }
    $dest = Join-Path $script:ReleaseDir "$Prefix-$($abi.Abi)-release.apk"
    Copy-ArtifactFile $src $dest $Kind
  }
}

function Build-AndroidLike {
  param([string]$ProjectDir, [string]$Prefix, [string]$Kind)
  Set-AndroidEnvironment
  Ensure-Tool $Flutter "Flutter"
  Ensure-Tool (Join-Path $AndroidSdk "platform-tools") "Android SDK platform-tools"
  Ensure-AndroidLocalProperties $ProjectDir
  $null = Invoke-LoggedCommand "$Kind-pub-get" $ProjectDir $Flutter @("pub", "get")
  Clear-GeneratedQuickJsAndroidJniLibs $ProjectDir
  $splitOk = Invoke-LoggedCommand "$Kind-split-apk" $ProjectDir $Flutter @("build", "apk", "--release", "--split-per-abi") "Split ABI build failed. The script will retry one ABI at a time; check dart_quickjs/native assets if armeabi-v7a is missing." -ContinueOnFailure
  if ($DryRun) {
    Write-Note "[dry-run] would copy APK outputs with prefix $Prefix"
    return
  }
  $apkDir = Join-Path $ProjectDir "build\app\outputs\flutter-apk"
  if ($splitOk -and -not (Test-SplitApksQuickJs $apkDir)) {
    Write-Note "$Kind split APKs are missing dart_quickjs; syncing native assets and rebuilding split APKs."
    $null = Sync-QuickJsAndroidJniLibsIfNeeded $ProjectDir -Required
    $splitOk = Invoke-LoggedCommand "$Kind-split-apk-quickjs-rebuild" $ProjectDir $Flutter @("build", "apk", "--release", "--split-per-abi") "Split ABI quickjs rebuild failed; falling back to single ABI builds." -ContinueOnFailure
  }
  if ($splitOk) {
    if (-not (Test-SplitApksQuickJs $apkDir)) {
      throw "$Kind split APKs do not contain libdart_quickjs.so after rebuild."
    }
    $copiedSplit = Copy-SplitApks $apkDir $Prefix $Kind
    if (-not $copiedSplit) {
      Add-BuildFailureExperience -Name "$Kind-split-apk-output-check" -Command "flutter build apk --release --split-per-abi" -LogPath (Join-Path $script:LogDir "$Kind-split-apk.log") -Suggestion "Split ABI command finished but at least one expected APK was missing; retrying one ABI at a time."
      Build-SingleAbiApks $ProjectDir $Prefix $Kind
    }
  } else {
    Build-SingleAbiApks $ProjectDir $Prefix $Kind
  }
}

function Build-Android {
  param([string]$AppVersion)
  $script:LocalAppBuildTouched = $true
  Build-AndroidLike $AppDir "SimpleLive-v$AppVersion" "Android"
}

function Build-TVAndroid {
  param([string]$TvVersion)
  $script:LocalTvBuildTouched = $true
  $script:ExternalStagingDirs += "C:\softwares\SimpleLiveAndroidTV"
  Build-AndroidLike $TvDir "SimpleLive-TV-tv_v$TvVersion" "TVAndroid"
}

function Copy-DistArtifacts {
  param([string]$Pattern, [string]$Kind)
  if ($DryRun) {
    Write-Note "[dry-run] copy artifacts matching $Pattern"
    return
  }
  $files = Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue
  if (-not $files) {
    throw "No artifacts found for pattern: $Pattern"
  }
  foreach ($file in $files) {
    $dest = Join-Path $script:ReleaseDir $file.Name
    Copy-ArtifactFile $file.FullName $dest $Kind
  }
}

function Test-WslDistro {
  param([string]$Name)
  try {
    $distros = & wsl.exe -l -q 2>$null
    foreach ($distro in $distros) {
      if ($distro.Trim([char]0).Trim() -eq $Name) {
        return $true
      }
    }
  } catch {
    return $false
  }
  return $false
}

function Invoke-GitHubWorkflow {
  param([string]$Kind, [string]$Workflow, [hashtable]$Inputs)
  if (-not $AllowGitHubActions) {
    if ($DryRun) {
      Write-Note "[dry-run] $Kind would require GitHub Actions. Add -AllowGitHubActions -Ref <tag-or-branch> to trigger $Workflow."
      return
    }
    throw "$Kind requires GitHub Actions. Rerun with -AllowGitHubActions -Ref <tag-or-branch>."
  }
  Ensure-Tool $Gh "GitHub CLI"
  $args = @("workflow", "run", $Workflow, "--repo", $GitHubRepo)
  foreach ($key in $Inputs.Keys) {
    $args += @("-f", "$key=$($Inputs[$key])")
  }
  $null = Invoke-LoggedCommand "$Kind-gh-run" $RepoRoot $Gh $args "Check gh auth status, workflow inputs, and GitHub Actions quota."

  if ($DryRun) {
    Write-Note "[dry-run] would watch latest $Workflow run and download artifacts to $script:ReleaseDir"
    return
  }

  Start-Sleep -Seconds 8
  $runJson = & $Gh run list --repo $GitHubRepo --workflow $Workflow --limit 1 --json databaseId,status,conclusion 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to locate GitHub Actions run for $Workflow`: $runJson"
  }
  $run = $runJson | ConvertFrom-Json
  if (-not $run -or -not $run[0].databaseId) {
    throw "No GitHub Actions run found for $Workflow"
  }
  $runId = [string]$run[0].databaseId
  Invoke-LoggedCommand "$Kind-gh-watch" $RepoRoot $Gh @("run", "watch", $runId, "--repo", $GitHubRepo, "--exit-status") "Open the failed GitHub Actions run and inspect logs."
  $downloadDir = Join-Path $script:ReleaseDir "$Kind-artifacts"
  Ensure-Directory $downloadDir
  Invoke-LoggedCommand "$Kind-gh-download" $RepoRoot $Gh @("run", "download", $runId, "--repo", $GitHubRepo, "-D", $downloadDir) "If gh download hangs, download artifact zip through the GitHub API with proxy 127.0.0.1:51888."

  $downloaded = Get-ChildItem -LiteralPath $downloadDir -File -Recurse -ErrorAction SilentlyContinue
  foreach ($file in $downloaded) {
    Add-Artifact -Path $file.FullName -Kind $Kind
  }
}

function Build-Linux {
  if (Test-WslDistro "Ubuntu-24.04") {
    $script:LocalAppBuildTouched = $true
    $bash = "cd /mnt/c/softwares/dart_simple_live/simple_live_app && command -v flutter && flutter pub get && dart pub global activate flutter_distributor && flutter_distributor package --platform linux --targets deb,zip --skip-clean"
    $null = Invoke-LoggedCommand "linux-wsl-build" $RepoRoot "wsl.exe" @("-d", "Ubuntu-24.04", "bash", "-lc", $bash) "Linux release needs Ubuntu 24.04 and a Linux-native Flutter in PATH. Otherwise rerun with -AllowGitHubActions."
    if ($DryRun) {
      Write-Note "[dry-run] would copy Linux deb/zip from simple_live_app\build\dist"
      return
    }
    Copy-DistArtifacts (Join-Path $AppDir "build\dist\*\*.deb") "Linux"
    Copy-DistArtifacts (Join-Path $AppDir "build\dist\*\*.zip") "Linux"
    return
  }

  Invoke-GitHubWorkflow "Linux" "publish_app_release_linux.yml" @{
    build_linux = "true"
    ref = $Ref
    upload_release = "false"
  }
}

function Build-IOS {
  Invoke-GitHubWorkflow "IOS" "publish_app_release_ios_manual.yml" @{
    build_ios = "true"
    ref = $Ref
    upload_release = "false"
    build_note = "Triggered by tools/build-release.ps1"
  }
}

function Build-MacOS {
  Invoke-GitHubWorkflow "MacOS" "publish_app_release_macos_manual.yml" @{
    ref = $Ref
    upload_release = "false"
    build_note = "Triggered by tools/build-release.ps1"
  }
}

function Stop-GradleDaemons {
  if ($DryRun) {
    Write-Note "[dry-run] stop Gradle daemons"
    return
  }
  foreach ($projectDir in @($AppDir, $TvDir)) {
    $gradlew = Join-Path $projectDir "android\gradlew.bat"
    if (Test-Path -LiteralPath $gradlew) {
      try {
        & $gradlew --stop | Out-Null
      } catch {
        Write-Note "Gradle daemon stop skipped for $projectDir`: $($_.Exception.Message)"
      }
    }
  }
}

function Remove-BuildDir {
  param([string]$Path)
  Assert-WithinRepo $Path
  if ($DryRun) {
    Write-Note "[dry-run] remove $Path"
    return
  }
  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }
  $lastError = $null
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    try {
      Remove-Item -LiteralPath $Path -Recurse -Force
      return
    } catch {
      $lastError = $_
      if ($attempt -eq 1) {
        Stop-GradleDaemons
      }
      Start-Sleep -Seconds ([Math]::Min($attempt * 2, 8))
    }
  }
  throw $lastError
}

function Remove-ExternalStagingDir {
  param([string]$Path)
  $allowed = @("C:\softwares\SimpleLiveAndroidTV")
  if ($allowed -notcontains $Path) {
    throw "Refusing to clean unknown external staging path: $Path"
  }
  if ($DryRun) {
    Write-Note "[dry-run] remove external staging $Path"
    return
  }
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Cleanup-BuildOutputs {
  if ($KeepBuild) {
    Write-Step "Keeping build directories because -KeepBuild was set"
    return
  }
  Write-Step "Cleaning build directories"
  if ($script:LocalAppBuildTouched -or $script:LocalTvBuildTouched) {
    Stop-GradleDaemons
  }
  if ($script:LocalAppBuildTouched) {
    Remove-BuildDir (Join-Path $AppDir "build")
  }
  if ($script:LocalTvBuildTouched) {
    Remove-BuildDir (Join-Path $TvDir "build")
  }
  foreach ($path in ($script:ExternalStagingDirs | Select-Object -Unique)) {
    Remove-ExternalStagingDir $path
  }
}

function Cleanup-SuccessLogs {
  if ($KeepBuild) {
    return
  }
  if ($script:LogDir -and (Test-Path -LiteralPath $script:LogDir)) {
    Remove-Item -LiteralPath $script:LogDir -Recurse -Force
  }
}

function Write-ReleaseBuildNotes {
  param([string[]]$Targets)
  if ($DryRun -or $script:Artifacts.Count -eq 0) {
    return
  }
  $date = Get-Date -Format "yyyy-MM-dd HH:mm"
  $releaseNote = Join-Path $RepoRoot ".release-$resolvedReleaseName.md"
  $artifactLines = $script:Artifacts | ForEach-Object {
    "- $($_.Kind): $([System.IO.Path]::GetFileName($_.Path)) ($($_.SizeMB) MB, SHA256 $($_.SHA256))"
  }
  $extraLines = @()
  if ($Targets -contains "TVWindows") {
    $tvExtracted = Join-Path $script:ReleaseDir "SimpleLiveTV-Windows-tv_v$tvVersion"
    if (Test-Path -LiteralPath $tvExtracted) {
      $extraLines += "- TVWindowsExtracted: $([System.IO.Path]::GetFileName($tvExtracted))"
    }
  }
  $allArtifactLines = @($artifactLines + $extraLines)
  $entry = @"

## $date build

- Targets: $($Targets -join ', ')
- Release directory: $script:ReleaseDir
$($allArtifactLines -join "`r`n")
"@
  [System.IO.File]::AppendAllText($releaseNote, $entry + "`r`n", $Utf8NoBom)
  $releaseNoteCopy = Join-Path $script:ReleaseDir "RELEASE_NOTES.md"
  Copy-Item -LiteralPath $releaseNote -Destination $releaseNoteCopy -Force
  $updatePath = Join-Path $RepoRoot "Update.md"
  $updateEntry = @"

## $date

- Build: $($Targets -join ', ') -> $script:ReleaseDir
"@
  [System.IO.File]::AppendAllText($updatePath, $updateEntry + "`r`n", $Utf8NoBom)
}

function Print-Summary {
  Write-Step "Build summary"
  Write-Note "Release directory: $script:ReleaseDir"
  if ($DryRun) {
    Write-Note "Dry run only. No build, copy, GitHub Action, or cleanup was performed."
    return
  }
  if ($script:Artifacts.Count -eq 0) {
    Write-Note "No local artifacts were recorded."
    return
  }
  $script:Artifacts | Format-Table Kind, SizeMB, SHA256, Path -AutoSize
}

$resolvedTargets = Resolve-Targets
$appVersion = Get-PubspecVersionName $AppDir
$tvVersion = Get-PubspecVersionName $TvDir
$resolvedReleaseName = Resolve-ReleaseName $resolvedTargets $appVersion $tvVersion
$script:ReleaseDir = Join-Path $ReleaseRoot $resolvedReleaseName
$script:LogDir = Join-Path $script:ReleaseDir "logs"

Write-Step "Release build plan"
Write-Note "Targets: $($resolvedTargets -join ', ')"
Write-Note "Main app version: v$appVersion"
Write-Note "TV app version: tv_v$tvVersion"
Write-Note "Release directory: $script:ReleaseDir"
Write-Note "Ref for GitHub Actions: $Ref"
if ($KeepBuild) {
  Write-Note "Cleanup: keep build directories"
} else {
  Write-Note "Cleanup: remove touched build directories after successful build"
}

Set-CommonEnvironment
if (-not $DryRun) {
  Ensure-Directory $script:ReleaseDir
  Ensure-Directory $script:LogDir
}

try {
  foreach ($item in $resolvedTargets) {
    switch ($item) {
      "Windows" { Build-Windows $appVersion }
      "Android" { Build-Android $appVersion }
      "TVWindows" { Build-TVWindows $tvVersion }
      "TVAndroid" { Build-TVAndroid $tvVersion }
      "Linux" { Build-Linux }
      "IOS" { Build-IOS }
      "MacOS" { Build-MacOS }
      default { throw "Unsupported target: $item" }
    }
  }
  Cleanup-BuildOutputs
  Write-ReleaseBuildNotes $resolvedTargets
  Cleanup-SuccessLogs
  Print-Summary
} catch {
  Write-Host ""
  Write-Host "Build failed: $($_.Exception.Message)"
  Write-Host "Build directories were kept for inspection."
  if ($script:LogDir) {
    Write-Host "Logs: $script:LogDir"
  }
  Add-BuildFailureExperience -Name "build-release.ps1" -Command "Target=$($resolvedTargets -join ','); ReleaseDir=$script:ReleaseDir" -LogPath $script:LogDir -Suggestion "Read the printed error and logs, keep build directories for inspection, then rerun the failed target."
  throw
}
