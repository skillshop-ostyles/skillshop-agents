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
$excludeDirs = @('node_modules', '.next', 'dist', '.git', '.vercel')

# Check public/ for large files
$publicDir = Join-Path $resolvedDir "public"
if (Test-Path $publicDir) {
    Get-ChildItem $publicDir -Recurse -File -Include '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp' -ErrorAction SilentlyContinue | ForEach-Object {
        $sizeKB = [Math]::Round($_.Length / 1024, 1)
        if ($sizeKB -gt 200) {
            $relative = $_.FullName.Substring($resolvedDir.Length + 1)
            $findings += @{
                impact = 'medium'
                type = 'images'
                file = $relative
                line = 1
                size_kb = $sizeKB
                message = "Large image: $($_.Name) is ${sizeKB}KB - consider optimizing or using next/image"
            }
        }
    }
}

# Check tsx/jsx for <img> instead of next/image
Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $lineNum = 1
    $hasNextImageImport = $content -match "from 'next/image'"

    foreach ($line in $lines) {
        if ($line -match '<img\s' -and $line -match 'src\s*=' -and $hasNextImageImport) {
            $findings += @{
                impact = 'medium'
                type = 'images'
                file = $relative
                line = $lineNum
                message = '<img> tag used despite next/image being available - use <Image> for optimization'
                snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
            }
        }
        $lineNum++
    }
}

$result = @{
    check = 'images'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
