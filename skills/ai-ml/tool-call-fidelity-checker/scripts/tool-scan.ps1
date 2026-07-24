[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb'),
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

$tools = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Find tool/function definitions - search for name + parameters proximity
    $toolBlocks = New-Object System.Collections.Generic.List[object]
    $namePositions = @([regex]::Matches($content, '(?i)["'']?name["'']?\s*[:=]\s*["'']([^"'']+)["'']'))
    $paramPositions = @([regex]::Matches($content, '(?i)(["'']?parameters["'']?|["'']?properties["'']?)\s*:\s*\{'))
    foreach ($n in $namePositions) {
        foreach ($p in $paramPositions) {
            if ($p.Index -gt $n.Index -and $p.Index -lt $n.Index + 500) {
                $blockStart = [Math]::Max(0, $n.Index - 50)
                $blockEnd = [Math]::Min($content.Length, $n.Index + 1000)
                $block = $content.Substring($blockStart, $blockEnd - $blockStart)
                $toolBlocks.Add([ordered]@{ block = $block; line = $n.Index; name = $n.Groups[1].Value })
                break
            }
        }
    }
    foreach ($tb in $toolBlocks) {
        $block = $tb.block
        $blockLower = $block.ToLower()

        # Extract tool name
        $toolName = $tb.name

# Find parameter descriptions
$paramDescriptions = @([regex]::Matches($block, '(?i)["'']?description["'']?\s*:\s*["'']([^"'']+)["'']'))
$allParams = @([regex]::Matches($block, '(?i)["'']?properties["'']?\s*:\s*\{'))

        # Find enums
        $hasEnums = $block -match '(?i)(enum|allowed_values|choices)'

        # Missing descriptions within parameters
        $missingDescs = @()
        $paramBlocks = @([regex]::Matches($block, '(?i)["''](\w+)["'']\s*:\s*\{[^}]*\}'))
        foreach ($pb in $paramBlocks) {
            $paramName = $pb.Groups[1].Value
            if ($paramName -in @('type', 'properties', 'required', 'additionalProperties')) { continue }
            if ($block.Substring($pb.Index, $pb.Length) -notmatch '(?i)description') {
                $missingDescs += $paramName
            }
        }

        # Ambiguous types
        $ambiguousTypes = @()
        $typeMatches = @([regex]::Matches($block, '(?i)["'']?type["'']?\s*:\s*["''](\w+)["'']'))
        foreach ($tm in $typeMatches) {
            $t = $tm.Groups[1].Value.ToLower()
            if ($t -eq 'string' -and -not $hasEnums) { $ambiguousTypes += "string without enum" }
            if ($t -eq 'object' -and $block -notmatch '(?i)properties') { $ambiguousTypes += "object without properties" }
        }

        # Parameter count
        $paramCount = $allParams.Count

        # TOCTOU risk
        $hasTOCTOU = $block -match '(?i)(current|existing|latest|active|now|today|current_user|current_time)'

        # Hallucination risk
        $hallucinationRisk = 'safe'
        if ($missingDescs.Count -gt 0 -and $ambiguousTypes.Count -gt 0) { $hallucinationRisk = 'dangerous' }
        elseif ($missingDescs.Count -gt 0 -or $ambiguousTypes.Count -gt 0) { $hallucinationRisk = 'risky' }

        $tools.Add([ordered]@{
                file = $relPath
                line = $tb.line
                toolName = $toolName
                parameterCount = $paramCount
                missingDescriptions = $missingDescs
                ambiguousTypes = $ambiguousTypes
                hasTOCTOURisk = $hasTOCTOU
                hallucinationRisk = $hallucinationRisk
            })
    }
}

$counts = @{ total = $tools.Count; safe = 0; risky = 0; dangerous = 0 }
foreach ($t in $tools) {
    if ($counts.ContainsKey($t.hallucinationRisk)) { $counts[$t.hallucinationRisk]++ }
}

$result = [ordered]@{
    tools = $tools.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== TOOL-SCAN ==="
Write-Output "  Tools found: $($tools.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
