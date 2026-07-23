[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.yml,*.yaml,*.json,*.toml,*.cfg,*.ini,.env",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$envVars = @{}
$configFiles = @()
$cliFlags = @()

# Detect env var reads in source files
$envPatterns = @(
    'process\.env\.(\w+)',
    'process\.env\[[\.\x27\x22](\w+)[\.\x27\x22]\]',
    'os\.environ\.get\([\x27\x22](\w+)[\x27\x22]',
    'os\.getenv\([\x27\x22](\w+)[\x27\x22]',
    'Environment\.GetEnvironmentVariable\([\x27\x22](\w+)[\x27\x22]',
    'System\.getenv\([\x27\x22](\w+)[\x27\x22]',
    'os\.Getenv\([\x27\x22](\w+)[\x27\x22]',
    'std::env::var\([\x27\x22](\w+)[\x27\x22]'
)

# Detect CLI flags
$cliPatterns = @(
    '\.option\([\x27\x22]--?(\w[\w-]*)[\x27\x22]',
    'add_argument\([\x27\x22]--?(\w[\w-]*)[\x27\x22]',
    '@click\.option\([\x27\x22]--?(\w[\w-]*)[\x27\x22]'
)

$count = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $count += 1
        $lines = $content -split "`n"

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $t = $lines[$li].Trim()
            if ($t -match '^\s*(//|#|import|require)') { continue }

            foreach ($pat in $envPatterns) {
                if ($t -match $pat) {
                    $name = $matches[1]
                    if (-not $envVars.ContainsKey($name)) { $envVars[$name] = @{ name = $name; source = "env"; usageSites = @(); defaultValue = $null; type = "string"; isSecret = $false } }
                    $envVars[$name].usageSites += @{ file = $rel; line = $li + 1 }
                    if ($t -match "=\s*[\x27\x22](\w+)[\x27\x22]") { $envVars[$name].defaultValue = $matches[1] }
                    if ($name -match 'KEY|SECRET|PASS|TOKEN|PASSWORD') { $envVars[$name].isSecret = $true; $envVars[$name].type = "secret" }
                    if ($t -match '\?\?[^a-zA-Z]') {
                        $defaultMatch = [regex]::Match($t, '\?\?\s*([\x27\x22]?(\w+)[\x27\x22]?)')
                        if ($defaultMatch.Success) { $envVars[$name].defaultValue = $defaultMatch.Groups[1].Value -replace '[\x27\x22]', '' }
                    }
                }
            }
            foreach ($pat in $cliPatterns) {
                if ($t -match $pat) {
                    $flagName = $matches[1]
                    $cliFlags += @{ file = $rel; line = $li + 1; name = "--$flagName" }
                }
            }
        }
    }
}

# Detect config files (YAML/JSON/TOML)
$configFilePatterns = @("*.yml", "*.yaml", "*.json", "*.toml", "*.cfg", "*.ini", ".env")
foreach ($pat in $configFilePatterns) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $pat -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $configFiles += @{ file = $rel; format = [System.IO.Path]::GetExtension($fn).Trim('.') }
    }
}

Write-Output "=== Config Doc Scan Complete ==="
Write-Output "  Files scanned: $count"
Write-Output "  Env vars read: $($envVars.Count)"
Write-Output "  Config files: $($configFiles.Count)"
Write-Output "  CLI flags: $($cliFlags.Count)"

$result = @{
    scannedFiles = $count
    configKeys = $envVars.Values
    configFiles = $configFiles
    cliFlags = $cliFlags
}
Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
