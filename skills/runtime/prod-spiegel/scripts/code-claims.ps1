[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)

$logPattern = "(?i)\b(log|logger|console)\s*\.\s*(error|warn|info|debug|log)\s*\(|(?<![\w.])Log\("
$catchPattern = '\bcatch\b'
# Ohne Anker am (getrimmten) Zeilenanfang matcht "get("/"post(" etc. auch
# generische Methodenaufrufe wie "request.headers.get(...)" oder "cache.get(...)"
# - echte Routen-Registrierungen (app.get(...), router.post(...)) stehen so gut
# wie immer als eigene Anweisung am Zeilenanfang, Sub-Ausdruecke wie "const x =
# foo.headers.get(...)" tun das nicht. Beim Akzeptanz-Lauf gegen dreamzzz-api_vs
# gefunden (27 falsch-positive Treffer auf Headers.get() etc.).
$routePattern = "(?i)^\s*[\w.]*\b(get|post|put|delete|patch)\s*\(\s*[`"']|@(Get|Post|Put|Delete|Patch)\(|app\.route\(|\[Http(Get|Post|Put|Delete|Patch)\]"

$logStatements = New-Object System.Collections.Generic.List[object]
$catchBlocks = New-Object System.Collections.Generic.List[object]
$routes = New-Object System.Collections.Generic.List[object]

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]

        if ($line -match $logPattern) {
            $logStatements.Add([ordered]@{ file = $relPath; line = ($i + 1); text = $line.Trim() })
        }
        if ($line -match $catchPattern) {
            $context = @()
            for ($j = $i + 1; $j -le $i + 3 -and $j -lt $lines.Count; $j++) { $context += [string]$lines[$j] }
            $contextText = $context -join "`n"
            $hasRethrow = $contextText -match '(?i)\bthrow\b'
            $hasLog = $contextText -match $logPattern
            $swallowGuess = (-not $hasRethrow) -and (-not $hasLog)
            $catchBlocks.Add([ordered]@{
                    file         = $relPath
                    line         = ($i + 1)
                    text         = $line.Trim()
                    context      = $context
                    swallowGuess = $swallowGuess
                })
        }
        if ($line -match $routePattern) {
            $routes.Add([ordered]@{ file = $relPath; line = ($i + 1); text = $line.Trim() })
        }
    }
}

$result = [ordered]@{
    logStatements = $logStatements.ToArray()
    catchBlocks   = $catchBlocks.ToArray()
    routes        = $routes.ToArray()
    scannedFiles  = $allFiles.Count
}

Write-Output (ConvertTo-Json $result -Depth 6)

$swallowCount = @($catchBlocks | Where-Object { $_.swallowGuess }).Count
Write-Output "`n=== CODE-CLAIMS ==="
Write-Output "  Gescannte Dateien: $($allFiles.Count)"
Write-Output "  Log-Statements: $($logStatements.Count)"
Write-Output "  Catch-Bloecke: $($catchBlocks.Count) (davon swallowGuess: $swallowCount)"
Write-Output "  Routen/Kommandos: $($routes.Count)"
