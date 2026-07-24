[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb', 'yaml', 'yml', 'json', 'cfg', 'ini'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-Excluded($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

# Reference deprecation data for known models (approximate - LLM should verify)
$deprecationData = @{
    'gpt-3.5-turbo-0301' = @{ base = 'gpt-3.5-turbo'; eol = '2024-06-13' }
    'gpt-3.5-turbo-0613' = @{ base = 'gpt-3.5-turbo'; eol = '2025-06-13' }
    'gpt-4-0314' = @{ base = 'gpt-4'; eol = '2024-06-13' }
    'gpt-4-0613' = @{ base = 'gpt-4'; eol = '2025-06-13' }
    'gpt-4-32k-0314' = @{ base = 'gpt-4-32k'; eol = '2024-06-13' }
    'gpt-4-32k-0613' = @{ base = 'gpt-4-32k'; eol = '2025-06-13' }
    'text-embedding-ada-002' = @{ base = 'text-embedding-ada-002'; eol = '2025-10-01' }
    'text-davinci-003' = @{ base = 'text-davinci'; eol = '2024-01-04' }
    'code-davinci-002' = @{ base = 'code-davinci'; eol = '2024-03-01' }
}

$now = Get-Date
$finetunes = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Find fine-tune references
    $fineTuneMatches = @()
    $patterns = @(
        '(?i)ft:[\w.-]+:[\w.-]+:[\w-]+'
        '(?i)fine[-_]?tune[:\s]*["'']*[\w./-]+["'']*'
        '(?i)model\s*[:=]\s*["'']ft:[\w.-:]+["'']'
        '(?i)["'']\w+/\w+["'']'
    )

    foreach ($p in $patterns) {
        $ms = [regex]::Matches($content, $p)
        foreach ($m in $ms) {
            $fineTuneMatches += $m.Value
        }
    }

    foreach ($ft in $fineTuneMatches) {
        $baseModel = 'unknown'
        $fineTuneName = $ft

        if ($ft -match 'ft:([\w.-]+):') {
            $baseModel = $matches[1]
        } elseif ($ft -match '([\w-]+-\d{4})' -or $ft -match '(gpt-\d[\w.-]*)') {
            $baseModel = $matches[1]
        }

        $isDeprecated = $false
        $deprecationDate = $null
        $alternative = $null

        foreach ($kv in $deprecationData.GetEnumerator()) {
            if ($ft -match [regex]::Escape($kv.Key)) {
                $isDeprecated = $true
                $deprecationDate = $kv.Value.eol
                $alternative = "$($kv.Value.base)-latest"
                break
            }
            if ($ft -match [regex]::Escape($kv.Value.base)) {
                $deprecationDate = $kv.Value.eol
                $isDeprecated = (Get-Date $deprecationDate) -lt $now
                break
            }
        }

        if ($baseModel -eq 'unknown') {
            $classification = 'unknown'
        } elseif ($isDeprecated) {
            $classification = 'deprecated'
        } elseif ($deprecationDate) {
            $eolDate = Get-Date $deprecationDate
            $daysUntilEol = ($eolDate - $now).Days
            $classification = if ($daysUntilEol -le 90) { 'expiring-soon' } else { 'current' }
        } else {
            $classification = 'current'
        }

        $finetunes.Add([ordered]@{
                file = $relPath
                line = 1
                baseModel = $baseModel
                fineTuneName = $fineTuneName
                isDeprecated = $isDeprecated
                deprecationDate = $deprecationDate
                alternativeModel = $alternative
                classification = $classification
            })
    }
}

$counts = @{ total = $finetunes.Count; current = 0; 'expiring-soon' = 0; deprecated = 0; unknown = 0 }
foreach ($f in $finetunes) {
    if ($counts.ContainsKey($f.classification)) { $counts[$f.classification]++ }
}

$result = [ordered]@{
    finetunes = $finetunes.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== FINETUNE-SCAN ==="
Write-Output "  Fine-tune refs found: $($finetunes.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
