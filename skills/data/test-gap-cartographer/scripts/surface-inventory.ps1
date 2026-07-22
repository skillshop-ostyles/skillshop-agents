[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Focus = "",

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs",

    [string]$Exclude = ""
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

$symbols = @()
$routes = @()
$scannedFiles = 0

function Get-RelativePath($base, $target) {
    $base = $base.TrimEnd('\').TrimEnd('/')
    $targetPath = $target.TrimEnd('\').TrimEnd('/')
    if ($targetPath -eq $base) { return '.' }
    if ($targetPath.StartsWith($base + '\') -or $targetPath.StartsWith($base + '/')) {
        return $targetPath.Substring($base.Length + 1)
    }
    return $targetPath
}

function Count-Branches($line) {
    $count = 0
    $count += [regex]::Matches($line, '\bif\b|\belse\b|\bswitch\b|\bcase\b|\bcatch\b|\bfor\b|\bwhile\b|\b\?\s').Count
    return $count
}

$testPatterns = @('\.test\.', '\.spec\.', 'test_', '_test\.', '\.tests\.', '\btests\b')
function Is-TestFile($relPath) {
    foreach ($p in $testPatterns) {
        if ($relPath -match $p) { return $true }
    }
    return $false
}

$searchRoot = $ProjectDir
if ($Focus) {
    $focused = Join-Path $ProjectDir $Focus
    $resolvedFocus = Resolve-Path -LiteralPath $focused -ErrorAction SilentlyContinue
    if ($resolvedFocus) { $searchRoot = $resolvedFocus.Path }
}

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $path = $_.FullName
        $skip = $false
        foreach ($exc in $excludeList) { if ($exc -and $path -match $exc) { $skip = $true } }
        if ($path -match 'node_modules|\.git|venv|bin|obj|__pycache__') { $skip = $true }
        -not $skip
    } | ForEach-Object {
        $relPath = Get-RelativePath $ProjectDir $_.FullName
        if (Is-TestFile $relPath) { return }
        $scannedFiles++
        $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { return }
        $content = $lines -join "`n"
        $ext = $_.Extension.ToLower()

        # Routes (API endpoints) - generic patterns
        if ($ext -in '.js','.ts','.jsx','.tsx') {
            # Express/Hono/Next.js route patterns
            if ($content -match '(?:app|router|server|route)\.(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1].ToUpper()
                $path = $matches[2]
                $lineNo = 0
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match '(get|post|put|delete|patch)\s*\(\s*["\x27]' + [regex]::Escape($path) + '["\x27]') {
                        $lineNo = $i + 1
                        break
                    }
                }
                $routes += @{ file = $relPath; line = $lineNo; method = $meth; path = $path }
            }
        }
        if ($ext -eq '.py') {
            # Flask/FastAPI route decorator pattern
            if ($content -match '@\w+\.route\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $routePath = $matches[1]
                $lineNo = 0
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match '@\w+\.route\s*\(\s*["\x27][^"\x27]+["\x27]') {
                        if ($lines[$i] -match [regex]::Escape($routePath)) {
                            $lineNo = $i + 1
                            break
                        }
                    }
                }
                $routes += @{ file = $relPath; line = $lineNo; method = "ANY"; path = $routePath }
            }
        }

        # Exports / public functions
        # JS/TS exports
        if ($ext -in '.js','.ts','.jsx','.tsx') {
            # export function
            $match = [regex]::Match($content, 'export\s+(?:default\s+)?(?:function|const|let|var|class)\s+(\w+)')
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $blockStart = $match.Index
                $braceOpen = $content.IndexOf('{', $blockStart)
                if ($braceOpen -ge 0) {
                    $depth = 0
                    $blockEnd = $braceOpen
                    for ($j = $braceOpen; $j -lt $content.Length; $j++) {
                        if ($content[$j] -eq '{') { $depth++ }
                        elseif ($content[$j] -eq '}') { $depth-- }
                        if ($depth -eq 0) { $blockEnd = $j; break }
                    }
                    $blockText = $content.Substring($blockStart, $blockEnd - $blockStart + 1)
                    $blockLines = ($blockText -split "`n").Count
                    $branchCount = 0
                    $branchMatch = [regex]::Matches($blockText, '\bif\b|\belse\b|\bswitch\b|\bcase\b|\bcatch\b|\bfor\b|\bwhile\b|\?\s')
                    $branchCount = $branchMatch.Count
                } else {
                    $blockLines = 1
                    $branchCount = 0
                }
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'function'; blockLines = $blockLines; branchCount = $branchCount }
                $match = $match.NextMatch()
            }
        }

        # Python functions and classes
        if ($ext -eq '.py') {
            $match = [regex]::Match($content, '^def\s+(\w+)|^class\s+(\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($match.Success) {
                $symName = if ($match.Groups[1].Value) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                $kind = if ($match.Groups[1].Value) { 'function' } else { 'class' }
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                # Skip private
                if ($symName -notmatch '^_') {
                    $blockMatch = [regex]::Match($content.Substring($match.Index), '^(\s*)(?:def|class)\s')
                    $branchCount = 0
                    $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = $kind; blockLines = 0; branchCount = 0 }
                }
                $match = $match.NextMatch()
            }
        }

        # Go functions
        if ($ext -eq '.go') {
            $match = [regex]::Match($content, '^func\s+(\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'function'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }

        # C# methods
        if ($ext -eq '.cs') {
            $match = [regex]::Match($content, '(?:public|internal)\s+(?:static\s+)?\w+\s+(\w+)\s*\(')
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'method'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }

        # Java methods
        if ($ext -eq '.java') {
            $match = [regex]::Match($content, '(?:public|protected)\s+(?:static\s+)?\w+\s+(\w+)\s*\(')
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'method'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }

        # PHP functions
        if ($ext -eq '.php') {
            $match = [regex]::Match($content, '^function\s+(\w+)|^public\s+function\s+(\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($match.Success) {
                $symName = if ($match.Groups[1].Value) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'function'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }

        # Ruby methods
        if ($ext -eq '.rb') {
            $match = [regex]::Match($content, '^def\s+(\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'method'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }

        # PS1 functions
        if ($ext -eq '.ps1') {
            $match = [regex]::Match($content, '^function\s+(\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($match.Success) {
                $symName = $match.Groups[1].Value
                $lineNo = $content.Substring(0, $match.Index).Split("`n").Length
                $symbols += @{ file = $relPath; line = $lineNo; symbol = $symName; kind = 'function'; blockLines = 0; branchCount = 0 }
                $match = $match.NextMatch()
            }
        }
    }
}

$result = @{
    symbols = $symbols
    routes = $routes
    scannedFiles = $scannedFiles
    counts = @{ symbols = $symbols.Count; routes = $routes.Count }
}

$json = $result | ConvertTo-Json -Depth 10
Write-Output $json
exit 0
