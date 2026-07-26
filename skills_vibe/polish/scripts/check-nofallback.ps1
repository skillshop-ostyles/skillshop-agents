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
$excludeDirs = @('node_modules', '.next', 'dist', '.git', 'coverage')
$totalChecks = @{ map_without_key = 0; no_error_boundary = 0; loading_missing = 0 }

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx', '*.js' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $fileText = $content
    $lineNum = 1

    # 1. .map() without key=
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '\.map\s*\(') {
            $hasKey = $false
            $blockDepth = 0
            $startedBlock = $false
            for ($j = $i; $j -lt [Math]::Min($i + 30, $lines.Count); $j++) {
                if ($lines[$j] -match 'key=') { $hasKey = $true; break }
                if ($lines[$j] -match '\{') { $startedBlock = $true }
                if ($startedBlock) {
                    foreach ($c in $lines[$j].ToCharArray()) {
                        if ($c -eq '{') { $blockDepth++ }
                        elseif ($c -eq '}') { $blockDepth-- }
                    }
                    if ($blockDepth -le 0 -and $startedBlock) { break }
                }
            }
            if (-not $hasKey) {
                $findings += @{
                    type = 'map_without_key'
                    file = $relative
                    line = $i + 1
                    snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                }
                $totalChecks.map_without_key++
            }
        }
    }

    # 2. No ErrorBoundary
    $hasErrorBoundary = $fileText -match '<ErrorBoundary'
    $hasComponentExport = $fileText -match 'export (default )?(function|const) \w+'
    if ($hasComponentExport -and -not $hasErrorBoundary -and $fileText -match 'useState|useEffect|fetch|axios') {
        foreach ($c in @('function |const |class ')) {
            if ($fileText -match "export (default )?$c(\w+)") {
                $compName = $Matches[2]
                if ($compName -notmatch '^_|\.|Context|Provider|Hook$|Utils?$|Helper') {
                    $matchLine = $lines | Select-String -Pattern "export (default )?$c$compName" | Select-Object -First 1
                    $lineFound = if ($matchLine) { $matchLine.LineNumber } else { 1 }
                    $findings += @{
                        type = 'no_error_boundary'
                        file = $relative
                        line = $lineFound
                        component = $compName
                        snippet = "export $c$compName found without ErrorBoundary wrapper"
                    }
                    $totalChecks.no_error_boundary++
                }
                break
            }
        }
    }

    # 3. fetch/axios without loading state
    if ($fileText -match 'fetch\(|axios\.get|axios\.post') {
        $hasLoading = $fileText -match '(loading|isLoading|is_loading|setLoading|LOADING|pending)'
        if (-not $hasLoading) {
            $fetchLine = $lines | Select-String -Pattern 'fetch\(|axios\.get|axios\.post' | Select-Object -First 1
            $lineFound = if ($fetchLine) { $fetchLine.LineNumber } else { 1 }
            $findings += @{
                type = 'loading_missing'
                file = $relative
                line = $lineFound
                snippet = 'Data fetch without loading state — consider adding a loading indicator'
            }
            $totalChecks.loading_missing++
        }
    }
}

$status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
$result = @{
    check = 'nofallback'
    status = $status
    findings = $findings
    summary = @{
        total = $findings.Count
        map_without_key = $totalChecks.map_without_key
        no_error_boundary = $totalChecks.no_error_boundary
        loading_missing = $totalChecks.loading_missing
        can_fix = $true
    }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
