<#
.SYNOPSIS
  Scans a project for runtime-dead code patterns: feature flags, date gates,
  environment checks, percentage rollouts, deprecated handlers, version
  gates, and compat shims.

.DESCRIPTION
  Outputs a JSON object with `deadCandidates[]` and summary counts.
  Also prints a human-readable === RUNTIME-DEAD-SCAN === summary to stdout.

.PARAMETER ProjectDir
  Root directory of the project to scan (mandatory).

.PARAMETER Extensions
  File extensions to include (default: .js,.ts,.jsx,.tsx,.mjs,.cjs,.vue,.svelte).

.PARAMETER Exclude
  Directories to exclude (default: node_modules,.git,dist,build,.next,.nuxt,coverage).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProjectDir,

  [string[]]$Extensions = @('.js', '.ts', '.jsx', '.tsx', '.mjs', '.cjs', '.vue', '.svelte'),

  [string[]]$Exclude = @('node_modules', '.git', 'dist', 'build', '.next', '.nuxt', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
  throw "ProjectDir '$ProjectDir' does not exist or is not a directory."
}

# ---- helpers ----

function Get-SourceFiles {
  param([string]$Dir)
  $extPatterns = $Extensions | ForEach-Object { "*$_" }
  Get-ChildItem -Path $Dir -Recurse -File -Include $extPatterns |
    Where-Object {
      $full = $_.FullName
      -not ($Exclude | Where-Object { $full -match [regex]::Escape($_) -or $full -match "(^|[\\/])$_([\\/]|$)" })
    }
}

function Get-GitBlameAge {
  param([string]$File, [int]$Line)
  try {
    $rel = Resolve-Path -LiteralPath $File -Relative
    $result = & git -C $ProjectDir blame -L "$Line,+1" --line-porcelain $rel 2>$null
    if ($result -match '^committer-time (\d+)') {
      $ts = [DateTimeOffset]::FromUnixTimeSeconds([long]$Matches[1])
      $days = [math]::Round(([DateTimeOffset]::UtcNow - $ts).TotalDays)
      return "$days days ago"
    }
    return "unknown"
  } catch {
    return "unknown"
  }
}

function Has-Tests {
  param([string]$Condition)
  $testFiles = Get-ChildItem -Path $ProjectDir -Recurse -File -Include @('*.test.*', '*.spec.*', '__tests__\*', 'test\*') -ErrorAction SilentlyContinue
  foreach ($tf in $testFiles) {
    $content = Get-Content -LiteralPath $tf.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match [regex]::Escape($Condition.Substring(0, [Math]::Min(40, $Condition.Length)))) {
      return $true
    }
  }
  return $false
}

function Is-InConfig {
  param([string]$FlagName)
  $configFiles = Get-ChildItem -Path $ProjectDir -Recurse -File -Include @('*.config.*', 'config.*', '.env*', '*.json', '*.yaml', '*.yml', '*.toml') -ErrorAction SilentlyContinue |
    Where-Object { -not ($Exclude | Where-Object { $_.FullName -match [regex]::Escape($_) }) }
  foreach ($cf in $configFiles) {
    $content = Get-Content -LiteralPath $cf.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match [regex]::Escape($FlagName)) {
      return $true
    }
  }
  return $false
}

function Get-Classify {
  param(
    [string]$ConditionType,
    [string]$Condition,
    [bool]$InConfig
  )
  switch ($ConditionType) {
    'date-gate' {
      $m = [regex]::Match($Condition, "new\s+Date\s*\(\s*['""](\d{4}-\d{2}-\d{2})")
      if ($m.Success) {
        $dateVal = [DateTime]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($dateVal -lt [DateTime]::UtcNow.AddDays(-7)) {
          return 'safe-to-remove'
        }
      }
      return 'requires-verification'
    }
    'deprecated' {
      return 'requires-verification'
    }
    'percentage' {
      return 'keep'
    }
    'env-check' {
      $envMatch = [regex]::Match($Condition, "(?:production|development|staging|test)")
      if ($envMatch.Success -and $envMatch.Value -in @('staging', 'test', 'development')) {
        return 'keep'
      }
      if ($envMatch.Success -and $envMatch.Value -eq 'production') {
        return 'requires-verification'
      }
      return 'requires-verification'
    }
    'feature-flag' {
      if (-not $InConfig) {
        return 'requires-verification'
      }
      return 'keep'
    }
    'version-gate' {
      return 'requires-verification'
    }
    'compat' {
      return 'requires-verification'
    }
    default {
      return 'requires-verification'
    }
  }
}

function Get-BranchContent {
  param([string[]]$Lines, [int]$StartLine)
  $end = $StartLine
  $depth = 0
  for ($i = $StartLine - 1; $i -lt $Lines.Length; $i++) {
    $line = $Lines[$i]
    $depth += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $depth -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    if ($depth -le 0 -and $i -gt $StartLine - 1) {
      $end = $i
      break
    }
  }
  $summaryStart = [Math]::Min($StartLine, $Lines.Length - 1)
  $summaryLine = $Lines[$summaryStart].Trim()
  if ($summaryLine.Length -gt 120) {
    $summaryLine = $summaryLine.Substring(0, 117) + '...'
  }
  return $summaryLine
}

# ---- scan ----

$files = Get-SourceFiles -Dir $ProjectDir
$candidates = @()

$patterns = @(
  @{ Name = 'feature-flag'; Regex = '(?:featureFlags?|experiment|toggle|rollout|enabled|feature_flag)\s*(?:\.|\[|=)' }
  @{ Name = 'date-gate';    Regex = '(?:new\s+Date\s*\([^)]*\)|Date\.now|Date\.parse)\s*[<>]' }
  @{ Name = 'env-check';    Regex = '(?:process\.env\.NODE_ENV|env\s*===|environment\s*===)' }
  @{ Name = 'percentage';   Regex = 'Math\.random\s*(?:\(\))?\s*<' }
  @{ Name = 'deprecated';   Regex = '(?:deprecated|@deprecated|legacy|old_|v1\b|backward)' }
  @{ Name = 'version-gate'; Regex = '\bif\s*\(\s*(?:version|apiVersion|semver)\b' }
  @{ Name = 'compat';       Regex = '(?:backwardCompat|compat|shim|polyfill)' }
)

foreach ($file in $files) {
  $contentLines = Get-Content -LiteralPath $file.FullName
  $content = $contentLines -join "`n"

  for ($i = 0; $i -lt $contentLines.Length; $i++) {
    $lineNum = $i + 1
    $line = $contentLines[$i]

    foreach ($pat in $patterns) {
      if ($line -match $pat.Regex) {
        # Skip lines that are entirely comments (the code line will be caught separately)
        if ($line.Trim() -match '^(//|#|<!--|/\*|\*)') {
          break
        }
        # Build condition expression from this and following lines up to a bracket or semicolon
        $condExpr = $line.Trim()
        $j = $i + 1
        while ($j -lt $contentLines.Length -and $condExpr -notmatch '[{;]' -and $condExpr -notmatch '\)\s*$') {
          $condExpr += ' ' + $contentLines[$j].Trim()
          $j++
        }
        if ($condExpr.Length -gt 200) {
          $condExpr = $condExpr.Substring(0, 197) + '...'
        }

        $branchContent = Get-BranchContent -Lines $contentLines -StartLine ($i + 1)
        $hasTests = Has-Tests -Condition $condExpr

        # Extract flag name for config lookup
        $flagName = ''
        if ($pat.Name -eq 'feature-flag') {
          $mFlag = [regex]::Match($line, '(?:featureFlag|experiment|toggle|rollout|enabled|feature_flag)[\s.]*([\w]+)')
          if ($mFlag.Success) {
            $flagName = $mFlag.Groups[1].Value
          } else {
            $mFlag2 = [regex]::Match($line, '([\w]+)\s*(?:\.|\[|=)')
            if ($mFlag2.Success) {
              $flagName = $mFlag2.Groups[1].Value
            }
          }
        }
        if ($pat.Name -eq 'deprecated') {
          $mFlag = [regex]::Match($line, '(?:deprecated|legacy|old_|v1|backward)\s*(\w*)')
          if ($mFlag.Success) {
            $flagName = $mFlag.Groups[1].Value
          }
        }

        $inConfig = Is-InConfig -FlagName $flagName
        $classification = Get-Classify -ConditionType $pat.Name -Condition $condExpr -InConfig $inConfig
        $gitAge = Get-GitBlameAge -File $file.FullName -Line $lineNum

        $candidates += @{
          file           = Resolve-Path -LiteralPath $file.FullName -Relative
          line           = $lineNum
          conditionType  = $pat.Name
          condition      = $condExpr
          branchContent  = $branchContent
          hasTests       = $hasTests
          classification = $classification
          gitBlameAge    = $gitAge
        }

        # Only first matching pattern per line
        break
      }
    }
  }
}

# ---- output ----

$safe = @($candidates | Where-Object { $_.classification -eq 'safe-to-remove' })
$verify = @($candidates | Where-Object { $_.classification -eq 'requires-verification' })
$keeps = @($candidates | Where-Object { $_.classification -eq 'keep' })

$result = @{
  deadCandidates = $candidates
  counts = @{
    total                   = $candidates.Count
    'safe-to-remove'        = $safe.Count
    'requires-verification' = $verify.Count
    keep                    = $keeps.Count
  }
}

# JSON output
$json = $result | ConvertTo-Json -Depth 10
Write-Output $json

# Human-readable summary
Write-Output ""
Write-Output "=== RUNTIME-DEAD-SCAN ==="
Write-Output "Scanned: $($files.Count) files in $ProjectDir"
Write-Output "Candidates found: $($candidates.Count)"
Write-Output "  safe-to-remove:        $($safe.Count)"
Write-Output "  requires-verification: $($verify.Count)"
Write-Output "  keep:                  $($keeps.Count)"

if ($safe.Count -gt 0) {
  Write-Output ""
  Write-Output "--- safe-to-remove ---"
  foreach ($c in $safe) {
    Write-Output "  $($c.file):$($c.line)  $($c.conditionType) - $($c.condition)"
  }
}

if ($verify.Count -gt 0) {
  Write-Output ""
  Write-Output "--- requires-verification ---"
  foreach ($c in $verify) {
    Write-Output "  $($c.file):$($c.line)  $($c.conditionType) - $($c.condition)"
  }
}

if ($keeps.Count -gt 0) {
  Write-Output ""
  Write-Output "--- keep ---"
  foreach ($c in $keeps) {
    Write-Output "  $($c.file):$($c.line)  $($c.conditionType) - $($c.condition)"
  }
}

Write-Output ""
Write-Output "=== END RUNTIME-DEAD-SCAN ==="