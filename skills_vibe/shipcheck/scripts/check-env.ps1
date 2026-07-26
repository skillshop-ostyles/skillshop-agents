[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$envExample = Join-Path $resolvedDir ".env.example"
$envFile = Join-Path $resolvedDir ".env"

$findings = @()
$passCount = 0
$warnCount = 0
$failCount = 0

function Add-Finding {
    param([string]$Key, [string]$Status, [string]$Message)
    $script:findings += @{ key = $Key; status = $Status; message = $Message }
    if ($Status -eq 'fail') { $script:failCount++ }
    elseif ($Status -eq 'warn') { $script:warnCount++ }
    else { $script:passCount++ }
}

# Check .env.example exists
if (-not (Test-Path $envExample)) {
    Add-Finding -Key '.env.example' -Status 'fail' -Message '.env.example file not found — no reference for required variables'
    $envExampleMissing = $true
} else {
    Add-Finding -Key '.env.example' -Status 'ok' -Message '.env.example exists'
    $envExampleMissing = $false
}

# Check .env exists
if (-not (Test-Path $envFile)) {
    Add-Finding -Key '.env' -Status 'fail' -Message '.env file not found — application may crash without environment variables'
    $envMissing = $true
} else {
    Add-Finding -Key '.env' -Status 'ok' -Message '.env exists'
    $envMissing = $false
}

# Compare keys if both exist
if (-not $envExampleMissing -and -not $envMissing) {
    $exampleContent = Get-Content $envExample -Encoding UTF8
    $envContent = Get-Content $envFile -Encoding UTF8

    $exampleKeys = @($exampleContent | Where-Object { $_ -match '^([A-Z_][A-Z0-9_]+)\s*=' } | ForEach-Object { $Matches[1] })
    $envKeys = @($envContent | Where-Object { $_ -match '^([A-Z_][A-Z0-9_]+)\s*=' } | ForEach-Object { $Matches[1] })
    $envValues = @{}
    $envContent | Where-Object { $_ -match '^([A-Z_][A-Z0-9_]+)\s*=\s*(.*)' } | ForEach-Object { $envValues[$Matches[1]] = $Matches[2] }

    $seenKeys = @{}

    foreach ($key in $exampleKeys) {
        $seenKeys[$key] = $true
        if ($key -in $envKeys) {
            $val = $envValues[$key]
            if ([string]::IsNullOrEmpty($val)) {
                Add-Finding -Key $key -Status 'fail' -Message "$key is present but has an empty value"
            } else {
                Add-Finding -Key $key -Status 'ok' -Message "$key is set"
            }
        } else {
            Add-Finding -Key $key -Status 'fail' -Message "$key is missing from .env (required by .env.example)"
        }
    }

    # Detect drift: keys in .env not in .env.example
    foreach ($key in $envKeys) {
        if (-not $seenKeys.ContainsKey($key)) {
            Add-Finding -Key $key -Status 'warn' -Message "$key is in .env but not in .env.example (possible drift)"
        }
    }
}

$result = @{
    check = 'env'
    status = if ($failCount -gt 0) { 'fail' } elseif ($warnCount -gt 0) { 'warn' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; pass = $passCount; warn = $warnCount; fail = $failCount }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
