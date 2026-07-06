param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Convert-ToPlainObject {
  param([object]$Value)

  if ($null -eq $Value -or
      $Value -is [string] -or
      $Value -is [bool] -or
      $Value -is [int] -or
      $Value -is [long] -or
      $Value -is [double] -or
      $Value -is [decimal]) {
    return $Value
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $map = [ordered]@{}
    foreach ($key in $Value.Keys) {
      $map[$key.ToString()] = Convert-ToPlainObject $Value[$key]
    }
    return $map
  }

  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
    $items = @()
    foreach ($item in $Value) {
      $items += Convert-ToPlainObject $item
    }
    return $items
  }

  if ($Value.PSObject.Properties.Count -gt 0) {
    $map = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
      $map[$property.Name] = Convert-ToPlainObject $property.Value
    }
    return $map
  }

  return $Value.ToString()
}

function Get-LegacyShieldValues {
  param([object]$Shield)

  if ($null -eq $Shield -or $Shield.PSObject.Properties.Count -eq 0) {
    return @()
  }

  $values = New-Object System.Collections.Generic.HashSet[string]
  foreach ($property in $Shield.PSObject.Properties) {
    $text = $property.Value.ToString().Trim()
    if ($text.Length -gt 0) {
      [void]$values.Add($text)
    }
  }

  return @($values) | Sort-Object
}

$inputFullPath = [System.IO.Path]::GetFullPath($InputPath)
if (-not (Test-Path -LiteralPath $inputFullPath)) {
  throw "Input file not found: $inputFullPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $dir = [System.IO.Path]::GetDirectoryName($inputFullPath)
  $OutputPath = [System.IO.Path]::Combine($dir, "simple_live_profile_converted.json")
}
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)

$utf8 = [System.Text.UTF8Encoding]::new($false)
$raw = [System.IO.File]::ReadAllText($inputFullPath, $utf8)
$legacy = $raw | ConvertFrom-Json

if ($legacy.type -ne "simple_live") {
  throw "This is not a legacy Simple Live config file."
}

$excludedSettings = @(
  "FirstRun",
  "LastLiveRoom",
  "LastLiveRoomResumePending",
  "WebDAVUri",
  "WebDAVUser",
  "kWebDAVPassword",
  "kWebDAVLastUploadTime",
  "kWebDAVLastRecoverTime",
  "BilibiliCookie",
  "DouyinCookie"
)

$settings = [ordered]@{}
if ($null -ne $legacy.config) {
  foreach ($property in $legacy.config.PSObject.Properties) {
    if ($excludedSettings -contains $property.Name) {
      continue
    }
    $settings[$property.Name] = Convert-ToPlainObject $property.Value
  }
}

$rawShields = Get-LegacyShieldValues $legacy.shield
$keywords = @()
$users = @()
$userGroups = [ordered]@{}

foreach ($value in $rawShields) {
  if ($value.StartsWith("keyword:")) {
    $keywords += $value.Substring("keyword:".Length)
    continue
  }
  if ($value.StartsWith("user:")) {
    $rest = $value.Substring("user:".Length)
    $separator = $rest.IndexOf(":")
    if ($separator -gt 0) {
      $siteId = $rest.Substring(0, $separator)
      $name = $rest.Substring($separator + 1)
      if (-not $userGroups.Contains($siteId)) {
        $userGroups[$siteId] = @()
      }
      $userGroups[$siteId] += $name
    } else {
      $users += $rest
    }
  }
}

$profile = [ordered]@{
  schema = "simple_live_profile"
  schemaVersion = 2
  appVersion = "legacy-$($legacy.version)"
  platform = $legacy.platform
  exportedAt = [DateTime]::Now.ToString("o")
  settings = $settings
  danmuShield = [ordered]@{
    raw = $rawShields
    keywords = @($keywords | Sort-Object -Unique)
    users = @($users | Sort-Object -Unique)
    userGroups = $userGroups
  }
  shieldPresets = @()
  followUsers = @()
  followUserTags = @()
  histories = @()
  summary = [ordered]@{
    settingCount = $settings.Count
    keywordShieldCount = @($keywords).Count
    userShieldCount = @($users).Count
    followUserCount = 0
    followTagCount = 0
    historyCount = 0
  }
}

$json = $profile | ConvertTo-Json -Depth 50
[System.IO.File]::WriteAllText($outputFullPath, $json, $utf8)
Write-Output "Converted legacy config to: $outputFullPath"
Write-Output "Settings: $($settings.Count); Shield values: $(@($rawShields).Count)"
