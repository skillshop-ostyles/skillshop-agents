[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.sql,*.prisma"
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$highPatterns = @(
    'email', 'e-mail', 'mail',
    'ssn', 'social.security', 'social_security',
    'credit.card', 'creditcard', 'cc.number', 'card.number',
    'password', 'passwd', 'pwd', 'secret',
    'api.key', 'apikey', 'api_key',
    'token', 'access.token', 'auth.token',
    'passport', 'passport.number',
    'birth.date', 'birthdate', 'dob', 'date.of.birth',
    'salary', 'wage', 'pay.rate',
    'bank.account', 'bankaccount', 'routing.number', 'routing_number',
    'cvv', 'cvc', 'csc',
    'health', 'medical', 'diagnosis', 'patient', 'prescription',
    'insurance.id', 'insurance_id',
    'national.id', 'national_id',
    'driver.license', 'drivers.license', 'dl.number'
)

$mediumPatterns = @(
    'phone', 'telephone', 'mobile', 'cell',
    'address', 'addr', 'street', 'city', 'state', 'zip', 'postal', 'country',
    'ip.address', 'ip_address', 'ipaddr',
    'gender', 'race', 'ethnicity', 'religion',
    'geolocation', 'geo.location',
    'biometric', 'fingerprint'
)

$lowPatterns = @(
    'name', 'first.name', 'last.name', 'fullname',
    'username', 'user.name', 'login',
    'photo', 'picture', 'avatar'
)

$nonePatterns = @(
    'id', 'status', 'code', 'type', 'count', 'amount', 'total',
    'date', 'created', 'updated', 'modified', 'timestamp',
    'is_active', 'isactive', 'active', 'flag', 'enabled',
    'version', 'order', 'sort', 'priority', 'level',
    'category', 'cat', 'group', 'tag', 'label',
    'description', 'desc', 'note', 'comment', 'remark',
    'config', 'setting', 'preference', 'option',
    'metadata', 'meta', 'data', 'payload',
    'cache', 'temp', 'tmp', 'backup', 'audit'
)

$ambiguousPatterns = @(
    '_id$', 'id$', '_ref$', 'ref$',
    'notes', 'metadata', 'description', 'details',
    'external', 'external_id', 'external_ref',
    'reference', 'lookup', 'mapping'
)

$columns = @()
$scannedFiles = 0

function Classify-Column($columnName) {
    $name = $columnName.ToLower()
    $result = @{
        patternClass = 'none'
        sensitivity = 'none'
        confidence = 0.3
        ambiguous = $false
    }

    foreach ($pat in $highPatterns) {
        if ($name -match $pat) {
            $result.patternClass = 'high'
            $result.sensitivity = 'high'
            $result.confidence = if ($name -eq $pat) { 0.95 } else { 0.85 }
            return $result
        }
    }

    foreach ($pat in $mediumPatterns) {
        if ($name -match $pat) {
            $result.patternClass = 'medium'
            $result.sensitivity = 'medium'
            $result.confidence = if ($name -eq $pat) { 0.9 } else { 0.75 }
            return $result
        }
    }

    foreach ($pat in $lowPatterns) {
        if ($name -match $pat) {
            $result.patternClass = 'low'
            $result.sensitivity = 'low'
            $result.confidence = if ($name -eq $pat) { 0.85 } else { 0.65 }
            return $result
        }
    }

    foreach ($pat in $ambiguousPatterns) {
        if ($name -match $pat) {
            $result.patternClass = 'ambiguous'
            $result.sensitivity = 'unknown'
            $result.confidence = 0.3
            $result.ambiguous = $true
            return $result
        }
    }

    foreach ($pat in $nonePatterns) {
        if ($name -match $pat) {
            $result.patternClass = 'none'
            $result.sensitivity = 'none'
            $result.confidence = 0.9
            return $result
        }
    }

    return $result
}

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`r`n|`n"

        $currentTable = ''
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()

            if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?') {
                $currentTable = $matches[1]
                continue
            }

            if ($line -match '^\s*(\w+)\s+(\w+)') {
                $colName = $matches[1]
                $colType = $matches[2]

                if ($colName -in @('PRIMARY', 'FOREIGN', 'UNIQUE', 'CHECK', 'CONSTRAINT', 'KEY', 'INDEX', 'CREATE', 'ALTER', 'DROP', 'REFERENCES')) {
                    continue
                }

                $classification = Classify-Column $colName
                $columns += @{
                    table = $currentTable
                    column = $colName
                    type = $colType
                    patternClass = $classification.patternClass
                    sensitivity = $classification.sensitivity
                    confidence = $classification.confidence
                    ambiguous = $classification.ambiguous
                }
            }
        }
    }
}

$bySensitivity = @{}
foreach ($c in $columns) {
    $s = $c.sensitivity
    if (-not $bySensitivity.ContainsKey($s)) { $bySensitivity[$s] = 0 }
    $bySensitivity[$s]++
}

$result = @{
    columns = $columns
    counts = @{
        scannedFiles = $scannedFiles
        totalColumns = $columns.Count
        bySensitivity = $bySensitivity
    }
}

Write-Output "=== PII Schema Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Columns found: $($columns.Count)"
foreach ($sensKey in $bySensitivity.Keys) {
    Write-Output "  $sensKey : $($bySensitivity[$sensKey])"
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
