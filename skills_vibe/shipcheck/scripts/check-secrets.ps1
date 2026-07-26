[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop

$patterns = @(
    @{ regex = '(?i)sk-[A-Za-z0-9-]{20,}'; label = 'OpenAI API Key (sk-)'; risk = 'critical' }
    @{ regex = 'ghp_[A-Za-z0-9]{36,}'; label = 'GitHub Personal Access Token'; risk = 'critical' }
    @{ regex = 'gho_[A-Za-z0-9]{36,}'; label = 'GitHub OAuth Token'; risk = 'critical' }
    @{ regex = 'AKIA[0-9A-Z]{16}'; label = 'AWS Access Key ID'; risk = 'critical' }
    @{ regex = '-----BEGIN\s+(RSA|EC|DSA|OPENSSH|PRIVATE)\s+KEY-----'; label = 'Private Key'; risk = 'critical' }
    @{ regex = '(?i)api[_-]?key\s*[:=]\s*[''"].{8,}[''"]'; label = 'Hardcoded API Key'; risk = 'high' }
    @{ regex = '(?i)password\s*[:=]\s*[''"].+[''"]'; label = 'Hardcoded Password'; risk = 'high' }
    @{ regex = '(?i)secret\s*[:=]\s*[''"].{8,}[''"]'; label = 'Hardcoded Secret'; risk = 'high' }
    @{ regex = '(?i)token\s*[:=]\s*[''"].{8,}[''"]'; label = 'Hardcoded Token'; risk = 'medium' }
)

$excludeDirs = @('node_modules', '.next', '.git', 'dist', '.vercel', '.wrangler', 'coverage')
$findings = @()
$criticalCount = 0
$highCount = 0
$mediumCount = 0

Get-ChildItem $resolvedDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_
    $relativePath = $file.FullName.Substring($resolvedDir.Length + 1)

    # Skip excluded directories
    $shouldSkip = $false
    foreach ($excl in $excludeDirs) {
        if ($relativePath -match "^$excl[\\/]") { $shouldSkip = $true; break }
    }
    if ($shouldSkip) { return }

    # Skip binary extensions
    $binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.woff', '.woff2', '.ttf', '.eot', '.pdf', '.zip', '.tar', '.gz', '.exe', '.dll')
    $skipExt = $false
    foreach ($ext in $binaryExtensions) {
        if ($file.Extension -eq $ext) { $skipExt = $true; break }
    }
    if ($skipExt) { return }

    try {
        $lines = Get-Content $file.FullName -Encoding UTF8
    } catch {
        return
    }

    $lineNum = 1
    foreach ($line in $lines) {
        foreach ($p in $patterns) {
            if ($line -match $p.regex) {
                $snippet = $line.Trim().Substring(0, [Math]::Min(80, $line.Trim().Length))
                $finding = @{
                    file = $relativePath
                    line = $lineNum
                    pattern = $p.label
                    snippet = $snippet
                    risk = $p.risk
                }
                $findings += $finding
                if ($p.risk -eq 'critical') { $criticalCount++ }
                elseif ($p.risk -eq 'high') { $highCount++ }
                else { $mediumCount++ }
                break
            }
        }
        $lineNum++
    }
}

$status = if ($criticalCount -gt 0) { 'fail' } elseif ($highCount -gt 0) { 'warn' } else { 'pass' }

$result = @{
    check = 'secrets'
    status = $status
    findings = $findings
    summary = @{ critical = $criticalCount; high = $highCount; medium = $mediumCount }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
