[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$findings = @()
$excludeDirs = @('node_modules', '.next', 'dist', '.git')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $lineNum = 1
    $hasNextImage = $false
    foreach ($line in $lines) {
        if ($line -match "from 'next/image'|from `"next/image`"") { $hasNextImage = $true }

        # <img> without width/height
        if ($line -match '<img\s' -and $line -notmatch 'width\s*=' -and $line -notmatch 'height\s*=' -and $line -notmatch '\bclassName\s*=') {
            $findings += @{
                impact = 'high'
                type = 'layoutshift'
                file = $relative
                line = $lineNum
                element = '<img>'
                message = '<img> without width/height attributes - causes Cumulative Layout Shift'
                snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
            }
        }

        # <Image> without width/height/fill
        if ($line -match '<Image\s' -and $line -notmatch 'width\s*=' -and $line -notmatch 'height\s*=' -and $line -notmatch '\bfill\b') {
            $findings += @{
                impact = 'high'
                type = 'layoutshift'
                file = $relative
                line = $lineNum
                element = '<Image>'
                message = 'Next.js <Image> without width, height, or fill prop - CLS risk'
                snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
            }
        }

        # <Image> without sizes
        if ($hasNextImage -and $line -match '<Image\s' -and $line -notmatch '\bsizes\s*=' -and $line -match '\bfill\b') {
            $findings += @{
                impact = 'medium'
                type = 'layoutshift'
                file = $relative
                line = $lineNum
                element = '<Image fill>'
                message = '<Image fill> without sizes prop - may download oversized images'
                snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
            }
        }

        $lineNum++
    }
}

$highCount = @($findings | Where-Object { $_.impact -eq 'high' }).Count
$result = @{
    check = 'layoutshift'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $highCount; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
