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
$excludeDirs = @('node_modules', '.next', 'dist', '.git')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -match 'useEffect\s*\(') {
            $blockStart = $i
            $effectText = ""
            $depth = 0
            $foundFn = $false

            for ($j = $i; $j -lt $lines.Count; $j++) {
                $effectText += $lines[$j] + " "
                if ($lines[$j] -match '=>|function\s*\(') { $foundFn = $true }
                foreach ($c in $lines[$j].ToCharArray()) {
                    if ($c -eq '(' -or $c -eq '{') { $depth++ }
                    elseif ($c -eq ')' -or $c -eq '}') { $depth-- }
                }
                if ($foundFn -and $depth -le 0) {
                    $i = $j
                    break
                }
            }

            # Check for dep array
            $depPattern = ',\s*\[([^\]]*)\]'
            if ($effectText -match $depPattern) {
                $depArray = $Matches[1]
                if ($depArray -match '\{\s*\}' -or $depArray -match '\bnew\b') {
                    $findings += @{
                        impact = 'high'
                        type = 'useeffect'
                        file = $relative
                        line = $blockStart + 1
                        message = 'useEffect dependency array contains object literal or new expression - breaks referential equality'
                        snippet = $effectText.Trim().Substring(0, [Math]::Min(80, $effectText.Trim().Length))
                    }
                }
            } else {
                $findings += @{
                    impact = 'high'
                    type = 'useeffect'
                    file = $relative
                    line = $blockStart + 1
                    message = 'useEffect without dependency array - runs on every render (infinite loop risk)'
                    snippet = $effectText.Trim().Substring(0, [Math]::Min(80, $effectText.Trim().Length))
                }
            }
        }
        $i++
    }
}

$result = @{
    check = 'useeffect'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
