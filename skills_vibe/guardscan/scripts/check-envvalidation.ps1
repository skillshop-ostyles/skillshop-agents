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

$srcExtensions = @('*.ts', '*.tsx', '*.js', '*.jsx')

Get-ChildItem $resolvedDir -Recurse -File -Include $srcExtensions -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    # Detect process.env.X usage that doesn't have a null/undefined check or fallback
    $lineNum = 1
    foreach ($line in $lines) {
        if ($line -match 'process\.env\.(\w+)') {
            $envVar = $Matches[1]
            $isPublic = $envVar -match '^NEXT_PUBLIC_'
            $hasFallback = $false

            # Check same line for fallback
            if ($line -match '\|\|\s*["'']' -or $line -match '\?\?' -or $line -match '\|\|\s*\d' -or $line -match '\|\|\s*true' -or $line -match '\|\|\s*false' -or $line -match '\|\|\s*null') {
                $hasFallback = $true
            }

            # Check next few lines for guard clause
            if (-not $hasFallback -and $lineNum -lt $lines.Count) {
                for ($i = [Math]::Min($lineNum, $lines.Count - 1); $i -lt [Math]::Min($lineNum + 3, $lines.Count); $i++) {
                    if ($lines[$i] -match 'if\s*\(!\s*' + [regex]::Escape($envVar) -or $lines[$i] -match 'if\s*\(typeof\s+' + [regex]::Escape($envVar)) {
                        $hasFallback = $true
                        break
                    }
                }
            }

            if (-not $hasFallback -and -not $isPublic) {
                $findings += @{
                    impact = 'low'
                    type = 'envvalidation'
                    file = $relative
                    line = $lineNum
                    message = "process.env.$envVar used without null/undefined check or fallback  may cause silent production failure"
                    snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                    incident = 'Missing env vars are a top cause of silent production failures in AI-deployed apps (New Relic 2026)'
                    confidence = 'likely'
                }
            }

            # Flag NEXT_PUBLIC_ vars that look like secrets
            if ($isPublic -and $envVar -match 'KEY|SECRET|TOKEN|PASSWORD') {
                $findings += @{
                    impact = 'medium'
                    type = 'envvalidation'
                    file = $relative
                    line = $lineNum
                    message = "NEXT_PUBLIC_$envVar exposes a sensitive variable to the browser bundle"
                    snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                    incident = 'Client-side exposure of sensitive env vars is a common AI code anti-pattern'
                    confidence = 'likely'
                }
            }
        }
        $lineNum++
    }
}

$result = @{
    check = 'envvalidation'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
