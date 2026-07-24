[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
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

$errorPaths = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; monitored = 0; silent = 0; dangerous = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Find error origins: throw, reject, return error, SQL errors
    $originPatterns = @(
        '(?i)\bthrow\s+',
        '(?i)Promise\.reject\(',
        '(?i)\bpanic\b',
        '(?i)\braise\b',
        '(?i)return\s+(Error|err|null|false|undefined)\s*[);]',
        '(?i)(SQL|query|find|findOne|findMany)\.(error|catch)\(',
        '(?i)(reject|callback)\s*\(',
        '(?i)\b(status\s*[=:]\s*4\d{2}|status\s*[=:]\s*5\d{2})'
    )

    foreach ($pat in $originPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $originText = $m.Value.Trim()

            # Find the line
            $originLine = 0
            $originIdx = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $idx = $lines[$i].IndexOf($originText, [System.StringComparison]::OrdinalIgnoreCase)
                if ($idx -ge 0) {
                    $originLine = $i + 1
                    $originIdx = $i
                    break
                }
            }
            if ($originLine -eq 0) { continue }

            # Detect handling blocks in surrounding lines (up to 5 lines after)
            $handlerActions = @()
            $lookupEnd = [Math]::Min($lines.Count - 1, $originIdx + 10)
            for ($j = $originIdx; $j -le $lookupEnd; $j++) {
                $hl = [string]$lines[$j]
                if ($hl -match '(?i)(catch|rescue|except|onError|\.error|\.catch)') {
                    # What does the handler do?
                    if ($hl -match '(?i)(throw|reject|panic|raise)') { $handlerActions += 'rethrown' }
                    elseif ($hl -match '(?i)(log|logger|console\.(error|warn)|print|fmt\.Print)') { $handlerActions += 'logged' }
                    elseif ($hl -match '(?i)(return\s+null|return\s+false|return\s+undefined|return\s+default)') { $handlerActions += 'returns-default' }
                    elseif ($hl -match '(?i)(wrap|AppError|new\s+\w*Error|err\.message)') { $handlerActions += 'wrapped' }
                    elseif ($hl -match '(?i)(empty|//|#|\/\*|\*\/)') { $handlerActions += 'silent-catch' }
                    else { $handlerActions += 'caught' }
                }
            }

            $counts.total++

            # Classify the error path
            $classification = 'dangerous'
            if ($handlerActions -contains 'logged' -or $handlerActions -contains 'wrapped') {
                $classification = 'monitored'
            }
            elseif ($handlerActions -contains 'caught' -or $handlerActions -contains 'silent-catch' -or $handlerActions -contains 'returns-default') {
                $classification = 'silent'
            }
            if ($handlerActions -contains 'rethrown') { $classification = 'monitored' }

            switch ($classification) {
                'monitored' { $counts.monitored++ }
                'silent' { $counts.silent++ }
                'dangerous' { $counts.dangerous++ }
            }

            $errorPaths.Add([ordered]@{
                    origin  = [ordered]@{ file = $relPath; line = $originLine; type = 'throw/reject'; text = $originText }
                    handlers = [ordered]@{ actions = $handlerActions }
                    classification = $classification
                })
        }
    }

    # Find try/catch blocks specifically
    $tryMatches = [regex]::Matches($content, '(?i)\btry\b')
    foreach ($m in $tryMatches) {
        $tryLine = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?i)\btry\b') { $tryLine = $i + 1; break }
        }
        if ($tryLine -eq 0) { continue }

        # Check catch block content
        $catchStart = -1
        for ($j = 0; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '(?i)\bcatch\b|except\s|rescue') { $catchStart = $j; break }
        }

        $hasEmptyCatch = $false
        $hasErrorLogged = $false
        $hasRethrow = $false
        if ($catchStart -ge 0) {
            $catchEnd = [Math]::Min($lines.Count - 1, $catchStart + 5)
            for ($j = $catchStart; $j -le $catchEnd; $j++) {
                $cl = [string]$lines[$j]
                if ($cl -match '^\s*\}\s*$' -or ($cl -match '^\s*$' -and $j -eq $catchStart + 1)) { $hasEmptyCatch = $true }
                if ($cl -match '(?i)(log|logger|console\.(error|warn))') { $hasErrorLogged = $true }
                if ($cl -match '(?i)(throw|reject)') { $hasRethrow = $true }
            }
        }

        if ($hasEmptyCatch -and -not $hasErrorLogged -and -not $hasRethrow) {
            $counts.total++
            $counts.silent++
            $errorPaths.Add([ordered]@{
                    origin  = [ordered]@{ file = $relPath; line = $tryLine; type = 'try-block'; text = 'empty catch block' }
                    handlers = [ordered]@{ actions = @('silent-catch'); }
                    classification = 'silent'
                })
        }
    }
}

$result = [ordered]@{
    errorPaths = $errorPaths.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== ERROR-TRACE ==="
Write-Output "  Error paths: $($counts.total) (monitored=$($counts.monitored) silent=$($counts.silent) dangerous=$($counts.dangerous))"
