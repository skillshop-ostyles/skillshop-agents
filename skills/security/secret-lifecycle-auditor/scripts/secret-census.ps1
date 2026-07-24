[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Exclude = "",
    [int]$MinKeyLength = 16,
    [string[]]$SecretFilePatterns = @('.env','.env.example','.env.local','.env.*','docker-compose*.yml','docker-compose*.yaml',
                                     'secrets.yml','secrets.yaml','*.toml','*.ini','*.cfg','*.tf','*.tfvars')
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Key=Value patterns. Match per-file with language-aware comment markers.
$secretNamePattern = '^[ \t]*([A-Za-z_][A-Za-z0-9_]*(?:[A-Z][A-Za-z0-9_]*)*)'
# Token regex: base64-ish, hex-ish, JWT-ish. Min length to filter trivial values.
$secretTokenPattern = '(?:[A-Za-z0-9_\-\+\/\=\.]{16,})'

# Berlin-list for the LLM to weigh rotation cadence.
$sensitiveHints = @('api', 'key', 'token', 'secret', 'password', 'passwd', 'pwd', 'auth', 'private', 'jwt', 'session', 'bearer', 'credential', 'sas', 'connect')

# Manifest-style: AWS_ACCESS_KEY_ID=AKIA..., STRIPE_API_KEY=sk_live_...
# Vault-style: key=value toml blocks.

$secrets = @()
$fileList = @()

function Get-FilesForPattern($proj, $pattern) {
    # PowerShell -Filter does not support wildcards in directory parts well.
    # We'll iterate top-level then use -Include with -Recurse for the file glob.
    $pattern = [regex]::Escape($pattern)
    Get-ChildItem -LiteralPath $proj -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like $pattern -or $_.FullName -like "*\*$pattern"
    }
}

# Build file list across all patterns.
foreach ($p in $SecretFilePatterns) {
    foreach ($f in (Get-FilesForPattern $ProjectDir $p)) {
        if ($f.FullName -notmatch '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') {
            if ($f.FullName -notin $fileList) { $fileList += $f.FullName }
        }
    }
}

# Read package.json/requirements.txt for reachability mapping.
$reachabilityIndex = @{}
$pj = Join-Path $ProjectDir 'package.json'
if (Test-Path -LiteralPath $pj) {
    try {
        $parsed = Get-Content -LiteralPath $pj -Raw | ConvertFrom-Json
        if ($parsed.dependencies) {
            foreach ($p in $parsed.dependencies.PSObject.Properties) {
                $reachabilityIndex[$p.Name] = $true
            }
        }
    } catch {}
}
$rt = Join-Path $ProjectDir 'requirements.txt'
if (Test-Path -LiteralPath $rt) {
    Get-Content -LiteralPath $rt | ForEach-Object {
        if ($_ -match '^([A-Za-z0-9_.\-]+)') { $reachabilityIndex[$matches[1]] = $true }
    }
}

foreach ($fp in $fileList) {
    $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
    $lines = $content -split "`n"

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $line = $lines[$li]
        $trim = $line.Trim()

        # Skip comment-ish lines for config formats.
        if ($rel -match '\.(env|env\.example|env\.local|toml|ini|cfg|yaml|yml|tf|tfvars)$') {
            if ($trim.StartsWith('#') -or $trim.StartsWith(';') -or $trim.StartsWith('//')) { continue }
        }
        if ($rel -match '\.(json)$') {
            # Skip JSON comments not relevant in JSON.
        }

        if ($trim -match '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*[:=]\s*["\x27]?(.+?)["\x27]?\s*$') {
            $key = $matches[1]
            $val = $matches[2]
            $keyLower = $key.ToLower()

            $isSensitive = $false
            foreach ($hint in $sensitiveHints) {
                if ($keyLower -match [regex]::Escape($hint)) { $isSensitive = $true; break }
            }
            if (-not $isSensitive) { continue }

            # Skip placeholders with obvious markers.
            if ($val -match '<.+>' -or $val -match '\$\{' -or $val -match '^your-' -or $val -match '^change-?me') { continue }
            if ($val -match '^null$' -or $val -match '^true$' -or $val -match '^false$') { continue }
            if ($val.Length -lt $MinKeyLength) { continue }

            # Mask: first-8 + last-4 for security.
            $masked = if ($val.Length -ge 12) {
                $val.Substring(0, 8) + '***' + $val.Substring($val.Length - 4)
            } else {
                '***'
            }

            # Git age via git log -S on the key name (first commit introducing it).
            $firstCommit = $null
            $firstSubject = $null
            $ageDays = $null
            if (Test-Path -LiteralPath (Join-Path $ProjectDir '.git') -PathType Any) {
                $logOut = git -C $ProjectDir log -S $key --format="%H|%s|%ct" -- $rel 2>&1 | Out-String
                if ($logOut -notmatch 'fatal:' -and $logOut.Trim()) {
                    $firstLine = ($logOut.Trim() -split "`n" | Select-Object -First 1)
                    if ($firstLine -match '^([0-9a-f]+)\|(.+?)\|(\d+)$') {
                        $firstCommit = $matches[1]
                        $firstSubject = $matches[2]
                        $ts = [int]$matches[3]
                        $ageDays = [int]((Get-Date).ToUniversalTime() - [DateTime]::FromUnixTimeSeconds($ts).ToUniversalTime()).TotalDays
                    }
                }
            }

            # Reachability heuristic: do any installed deps reference this key shape
            # in their docs? Here we use a heuristic on the secret name (twitter, stripe,
            # aws are recognizable).
            $serviceGuess = $null
            if ($keyLower -match 'stripe') { $serviceGuess = 'stripe' }
            elseif ($keyLower -match 'aws|amazon|akia') { $serviceGuess = 'aws' }
            elseif ($keyLower -match 'openai|sk-|sk_') { $serviceGuess = 'openai' }
            elseif ($keyLower -match 'sendgrid') { $serviceGuess = 'sendgrid' }
            elseif ($keyLower -match 'github|ghp_|gho_') { $serviceGuess = 'github' }
            elseif ($keyLower -match 'twilio') { $serviceGuess = 'twilio' }
            elseif ($keyLower -match 'slack|xox') { $serviceGuess = 'slack' }

            $referencedByDeps = $false
            if ($serviceGuess -and ($reachabilityIndex.ContainsKey($serviceGuess) -or $reachabilityIndex.ContainsKey($serviceGuess + '.js'))) {
                $referencedByDeps = $true
            }

            $secrets += @{
                key = $key
                file = $rel
                line = $li + 1
                maskedValue = $masked
                length = $val.Length
                firstCommit = $firstCommit
                firstSubject = $firstSubject
                ageDays = $ageDays
                serviceGuess = $serviceGuess
                referencedByDeps = $referencedByDeps
            }
        }
    }
}

Write-Output "=== Secret Lifecycle Audit Complete ==="
Write-Output "  Files scanned: $($fileList.Count)"
Write-Output "  Secrets inventoried: $($secrets.Count)"
$withAge = @($secrets | Where-Object { $_.ageDays -ne $null }).Count
Write-Output "  With git age: $withAge"
$overSixMonths = @($secrets | Where-Object { $_.ageDays -ne $null -and $_.ageDays -gt 180 }).Count
Write-Output "  Older than 180 days (stale): $overSixMonths"

$result = @{
    secrets = $secrets
    counts = @{
        scannedFiles = $fileList.Count
        totalSecrets = $secrets.Count
        withAge = $withAge
        overSixMonths = $overSixMonths
        referencedByInstalledDeps = (@($secrets | Where-Object { $_.referencedByDeps }).Count)
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
