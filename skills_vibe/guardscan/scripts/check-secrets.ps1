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
$excludeDirs = @('node_modules', '.next', 'dist', '.git', '.vercel', '.env', '.env.local')
$excludeFiles = @('.env.example', '.env.sample')

$secretPatterns = @(
    @{ pattern = 'sk-[a-zA-Z0-9]{20,}'; label = 'OpenAI API key' }
    @{ pattern = 'AKIA[0-9A-Z]{16}'; label = 'AWS Access Key' }
    @{ pattern = 'ghp_[a-zA-Z0-9]{36}'; label = 'GitHub Personal Access Token' }
    @{ pattern = 'gho_[a-zA-Z0-9]{36}'; label = 'GitHub OAuth Token' }
    @{ pattern = '-----BEGIN\s+(?:RSA\s+)?PRIVATE\s+KEY-----'; label = 'Private Key (PEM)' }
    @{ pattern = '-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----'; label = 'SSH Private Key' }
    @{ pattern = '-----BEGIN\s+PGP\s+PRIVATE\s+KEY\s+BLOCK-----'; label = 'PGP Private Key' }
    @{ pattern = '"password"\s*:\s*".{3,}"'; label = 'Hardcoded password (JSON)' }
    @{ pattern = "'password'\s*=>\s*'.{3,}'"; label = 'Hardcoded password (PHP)' }
    @{ pattern = 'password\s*=\s*["''](?![$<])'; label = 'Hardcoded password (assignment)' }
    @{ pattern = 'api[_-]?key\s*=\s*["''](?![$<])'; label = 'Hardcoded API key' }
    @{ pattern = 'api[_-]?secret\s*=\s*["''](?![$<])'; label = 'Hardcoded API secret' }
    @{ pattern = 'private[_-]?key\s*=\s*["''](?![$<])'; label = 'Hardcoded private key' }
)

$srcExtensions = @('*.ts', '*.tsx', '*.js', '*.jsx', '*.py', '*.rb', '*.php', '*.env', '*.yml', '*.yaml', '*.json', '*.toml')

Get-ChildItem $resolvedDir -Recurse -File -Include $srcExtensions -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    if ($relative -in $excludeFiles) { return }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $lineNum = 1
    foreach ($line in $lines) {
        foreach ($sp in $secretPatterns) {
            if ($line -match $sp.pattern) {
                $findings += @{
                    impact = 'high'
                    type = 'secrets'
                    file = $relative
                    line = $lineNum
                    message = "Possible $($sp.label) in source code"
                    snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                    incident = '14% of AI-generated projects ship with leaked secrets (Quality Clouds 2026)'
                    confidence = 'likely'
                }
            }
        }
        $lineNum++
    }
}

# Check .gitignore for .env
$gitignorePath = Join-Path $resolvedDir '.gitignore'
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Encoding UTF8 -ErrorAction SilentlyContinue
    $hasEnvEntry = $false
    foreach ($gLine in $gitignoreContent) {
        if ($gLine.Trim() -eq '.env' -or $gLine.Trim() -eq '.env*' -or $gLine.Trim() -eq '.env.local') {
            $hasEnvEntry = $true
            break
        }
    }
    if (-not $hasEnvEntry) {
        $findings += @{
            impact = 'high'
            type = 'secrets'
            file = '.gitignore'
            line = 1
            message = ".gitignore does not contain '.env'  secrets may be committed (missing .gitignore)"
            snippet = '.gitignore exists but .env not listed'
            incident = '14% of AI projects leak secrets via missing .gitignore entries'
            confidence = 'proven'
        }
    }
} else {
    $findings += @{
        impact = 'high'
        type = 'secrets'
        file = '.gitignore'
        line = 1
        message = ".gitignore is missing  '.env' file may be committed with secrets"
        snippet = 'No .gitignore found in project root'
        incident = '14% of AI projects leak secrets via missing .gitignore'
        confidence = 'proven'
    }
}

$result = @{
    check = 'secrets'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
