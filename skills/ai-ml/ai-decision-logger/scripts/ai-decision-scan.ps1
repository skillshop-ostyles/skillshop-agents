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

$decisions = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    $contentLower = $content.ToLower()

    # Decision patterns: model output in conditionals
    $decisionMatches = @()
    $patterns = @(
        '(?i)(if|unless)\s*\(?\s*(model\.predict|result|score|confidence|prediction|output|decision|classification|sentiment|intent)',
        '(?i)(if|unless)\s*\(?\s*\w*\s*(>|<|>=|<=|==|!=)\s*(\d+\.?\d*|threshold|limit)',
        '(?i)(if|unless)\s*\(?\s*(flagged|blocked|approved|rejected|is_safe|is_spam|is_abuse)',
        '(?i)(==|!=)\s*["''](positive|negative|neutral|approved|rejected|safe|unsafe|spam|ham)["'']'
    )

    foreach ($p in $patterns) {
        $ms = [regex]::Matches($content, $p)
        foreach ($m in $ms) {
            $decisionMatches += @{ index = $m.Index; length = $m.Length }
        }
    }

    # Group nearby matches
    $processed = New-Object System.Collections.Generic.List[int]
    foreach ($dm in $decisionMatches) {
        $isDuplicate = $false
        foreach ($p in $processed) {
            if ([Math]::Abs($dm.index - $p) -lt 50) { $isDuplicate = $true; break }
        }
        if ($isDuplicate) { continue }
        [void]$processed.Add($dm.index)

        # Check for audit logging nearby
        $nearby = $content.Substring([Math]::Max(0, $dm.index - 300), [Math]::Min($dm.length + 600, $content.Length - [Math]::Max(0, $dm.index - 300)))
        $nearbyLower = $nearby.ToLower()

        $hasAuditLog = $nearby -match '(?i)(logger\.|log\.|logging\.|audit\.|print|console\.log)'
        $hasHumanReview = $nearbyLower -match '(review|approve|human|manual|requires_review|human_in_loop|manual_approval)'
        $includesContext = $nearby -match '(?i)(features|input|model_version|confidence|score|reason|timestamp|metadata|context)'

        $decisionType = 'classification'
        if ($nearbyLower -match '(approve|reject|grant|deny|allow|block)') { $decisionType = 'approval' }
        elseif ($nearbyLower -match '(recommend|suggest|prioritize|assign|route)') { $decisionType = 'recommendation' }
        elseif ($nearbyLower -match '(flag|block|filter|moderat)') { $decisionType = 'moderation' }

        $classification = 'auditable'
        if (-not $hasAuditLog) { $classification = 'black-box' }
        elseif (-not $includesContext) { $classification = 'partially-logged' }

        $decisions.Add([ordered]@{
                file = $relPath
                line = $dm.index
                decisionType = $decisionType
                hasAuditLog = $hasAuditLog
                includesContext = $includesContext
                hasHumanReview = $hasHumanReview
                classification = $classification
            })
    }
}

$counts = @{ total = $decisions.Count; auditable = 0; 'partially-logged' = 0; 'black-box' = 0 }
foreach ($d in $decisions) {
    if ($counts.ContainsKey($d.classification)) { $counts[$d.classification]++ }
}

$result = [ordered]@{
    decisions = $decisions.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== AI-DECISION ==="
Write-Output "  Decision points: $($decisions.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
