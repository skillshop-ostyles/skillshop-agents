<#
.SYNOPSIS
  Scan a project for unvalidated LLM model output consumption patterns.

.DESCRIPTION
  Finds every place LLM model output is consumed without validation, type
  checking, or safety guardrails. Classifies each consumption by usage type
  (display, db-write, decision, api-call) and risk level.

.PARAMETER ProjectDir
  Root directory of the project to scan.

.PARAMETER Extensions
  File extensions to scan (default: .js,.ts,.py,.jsx,.tsx).

.PARAMETER Exclude
  Directories to exclude (default: node_modules,venv,.git,dist,build,__pycache__).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectDir,

  [string[]]$Extensions = @('.js', '.ts', '.py', '.jsx', '.tsx'),

  [string[]]$Exclude = @('node_modules', 'venv', '.git', 'dist', 'build', '__pycache__')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Error "Project directory not found: $ProjectDir"
  exit 1
}

# ---------------------------------------------------------------------------
# Pattern definitions
# ---------------------------------------------------------------------------

# Model call site regex (used in the main detection)
$modelCallPattern = '(?:const|let|var)\s+(\w+)\s*=\s*await\s+.*\.(create|generate|complete|chat|invoke)\s*\('

# Output parsing patterns
$parsePattern = '(JSON\.parse|json\.loads|\.json\(\))'

# DB write patterns — avoid matching model `.create(` by requiring a variable prefix
$dbWritePattern = '(db\.|\.save\s*\(|\.insert\s*\(|\.update\s*\()'

# Display patterns
$displayPattern = '(res\.json|res\.send|res\.render)'

# Decision patterns
$decisionPattern = '(if\s*\(|switch\s*\(|condition)'

# API call patterns
$apiCallPattern = '(api\.|fetch\s*\(|axios\.)'

# Validation patterns — exclude `JSON.parse` which is not a guardrail
$validationPattern = '(try|catch|Zod\.|z\.|pydantic|schema\.|\.validate\s*\()'

# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir
Write-Host "[GUARDRAIL-SCAN] Scanning $resolvedDir ..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $resolvedDir -Recurse -File |
  Where-Object {
    $ext = [System.IO.Path]::GetExtension($_.Name)
    $extMatch = $Extensions -contains $ext
    $excluded = $false
    foreach ($exDir in $Exclude) {
      if ($_.FullName -match [regex]::Escape($exDir)) { $excluded = $true; break }
    }
    $extMatch -and -not $excluded
  }

Write-Host "[GUARDRAIL-SCAN] Found $($files.Count) files to analyze" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

$consumptions = @()

foreach ($file in $files) {
  $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
  $lines = $content -split "`r`n|`n"
  $relPath = $file.FullName.Substring($resolvedDir.Path.Length).TrimStart('/', '\')

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $lineNum = $i + 1

    # Find model output assignment: const|let|var <var> = await <anything>.<modelCallMethod>(
    if ($line -match $modelCallPattern) {
      $sourceVar = $Matches[1]
      $hasValidation = $false
      $usageTypes = @()
      $foundUsage = $false

      # Track variable chain: model output → intermediate vars
      $watchVars = @($sourceVar)

      # Look ahead up to 10 lines for consumption patterns
      for ($j = 1; $j -le 10 -and ($i + $j) -lt $lines.Count; $j++) {
        $lookLine = $lines[$i + $j]

        # Check if this line references any watched variable
        $referencesSource = $false
        foreach ($wv in $watchVars) {
          if ($lookLine -match '\b' + [regex]::Escape($wv) + '\b') {
            $referencesSource = $true
            break
          }
        }

        if (-not $referencesSource) { continue }

        $foundUsage = $true

        # Track intermediate variable assignment: const|let|var <new> = <watched>...
        if ($lookLine -match '(?:const|let|var)\s+(\w+)\s*=\s*' + [regex]::Escape($watchVars[-1])) {
          $watchVars += $Matches[1]
        }

        # Detect usage type on this line
        if ($lookLine -match $parsePattern)    { $usageTypes += 'parse' }
        if ($lookLine -match $dbWritePattern)  { $usageTypes += 'db-write' }
        if ($lookLine -match $displayPattern)  { $usageTypes += 'display' }
        if ($lookLine -match $decisionPattern) { $usageTypes += 'decision' }
        if ($lookLine -match $apiCallPattern)  { $usageTypes += 'api-call' }

        # Check validation in vicinity (2 lines before through 2 lines after)
        $vStart = [Math]::Max(0, $i + $j - 2)
        $vEnd   = [Math]::Min($lines.Count - 1, $i + $j + 2)
        for ($k = $vStart; $k -le $vEnd; $k++) {
          $vl = $lines[$k]
          if ($vl -match $validationPattern) { $hasValidation = $true }
        }
      }

      # Handle the special case: parse happens on same line as the model call
      # e.g., `const result = JSON.parse(await openai...create(...).choices[0].message.content)`
      if ($line -match $parsePattern -and $line -match [regex]::Escape($sourceVar)) {
        $usageTypes += 'parse'
        $foundUsage = $true
        $hasValidation = $false
      }

      if (-not $foundUsage) { continue }

      $usageTypes = $usageTypes | Sort-Object -Unique

      # Priority: decision > parse > db-write > api-call > display
      $primaryType = 'display'
      if ($usageTypes -contains 'decision') { $primaryType = 'decision' }
      elseif ($usageTypes -contains 'parse')    { $primaryType = 'parse' }
      elseif ($usageTypes -contains 'db-write') { $primaryType = 'db-write' }
      elseif ($usageTypes -contains 'api-call') { $primaryType = 'api-call' }

      # Classification: dangerous (decision/parse without validation), risky (db-write without validation), safe
      $classification = 'safe'
      if (($primaryType -eq 'decision' -or $primaryType -eq 'parse') -and -not $hasValidation) {
        $classification = 'dangerous'
      } elseif ($primaryType -eq 'db-write' -and -not $hasValidation) {
        $classification = 'risky'
      }

      $consumptions += [PSCustomObject]@{
        file           = $relPath
        line           = $lineNum
        source         = $sourceVar
        hasValidation  = $hasValidation
        usageType      = $primaryType
        classification = $classification
        lineContent    = $line.Trim()
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

$result = @{ consumptions = $consumptions }
$json = $result | ConvertTo-Json -Depth 3 -Compress
Write-Output $json

Write-Host ""
Write-Host "=== GUARDRAIL-SCAN ===" -ForegroundColor Yellow
Write-Host "Files scanned: $($files.Count)"
Write-Host "Consumptions found: $($consumptions.Count)"
$dangerous = @($consumptions | Where-Object { $_.classification -eq 'dangerous' })
$risky     = @($consumptions | Where-Object { $_.classification -eq 'risky' })
$safe      = @($consumptions | Where-Object { $_.classification -eq 'safe' })
Write-Host "  Dangerous : $($dangerous.Count)" -ForegroundColor Red
Write-Host "  Risky     : $($risky.Count)" -ForegroundColor Yellow
Write-Host "  Safe      : $($safe.Count)" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Yellow