[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$excludeDirs = @('node_modules', '.next', 'dist', '.git', 'coverage', '.vercel')
$fileData = @()

Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    $skip = $false
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { $skip = $true; break }
    }
    if ($skip) { return }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $imports = @()
    $exports = @()
    $hasAsync = $false
    $hasEffect = $false
    $symbolUsage = @{}

    $currentLine = 0
    foreach ($line in $lines) {
        $currentLine++
        if ($line -match 'import\s+.+\s+from\s+[''"](.+)[''"]') {
            $imports += @{ source = $Matches[1]; line = $currentLine; text = $line.Trim() }
        }
        if ($line -match 'export\s+(default\s+)?(function|const|class|interface|type)\s+(\w+)') {
            $exports += @{ name = $Matches[3]; type = $Matches[2]; line = $currentLine }
        }
        if ($line -match 'async|await') { $hasAsync = $true }
        if ($line -match 'useEffect|useLayoutEffect') { $hasEffect = $true }
        $line -split '\W+' | Where-Object { $_ -match '^[a-z_]\w*$' -and $_.Length -gt 2 } | ForEach-Object {
            if (-not $symbolUsage.ContainsKey($_)) { $symbolUsage[$_] = 0 }
            $symbolUsage[$_]++
        }
    }

    $fileData += @{
        path = $relative
        lines = $lines.Count
        imports = $imports
        exports = $exports
        has_async = $hasAsync
        has_effect = $hasEffect
        symbol_usage = $symbolUsage
    }
}

# Collect package.json dependencies
$pkgDeps = @{}
$pkgPath = Join-Path $resolvedDir "package.json"
if (Test-Path $pkgPath) {
    try {
        $pkgJson = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pkgJson.dependencies) {
            $pkgJson.dependencies.PSObject.Properties | ForEach-Object { $pkgDeps[$_.Name] = $_.Value }
        }
        if ($pkgJson.devDependencies) {
            $pkgJson.devDependencies.PSObject.Properties | ForEach-Object { $pkgDeps[$_.Name] = $_.Value }
        }
    } catch {
        $pkgDeps = @{}
    }
}

$allImports = @{}
$allExports = @()

foreach ($fd in $fileData) {
    foreach ($imp in $fd.imports) {
        $src = $imp.source
        if (-not $allImports.ContainsKey($src)) { $allImports[$src] = 0 }
        $allImports[$src]++
    }
    foreach ($exp in $fd.exports) {
        $allExports += $exp
    }
}

$smells = @()

# Unused dependencies
foreach ($dep in $pkgDeps.Keys) {
    $imported = 0
    foreach ($fd in $fileData) {
        foreach ($imp in $fd.imports) {
            if ($imp.source -eq $dep -or $imp.source -match "^$dep/") { $imported++ }
        }
    }
    if ($imported -eq 0 -and $dep -notmatch '^@types/|^eslint|^prettier|^@biomejs|^typescript$') {
        $smells += @{
            type = 'unused_dependency'
            package = $dep
            version = $pkgDeps[$dep]
            message = "$dep is in package.json but never imported in any source file"
        }
    }
}

# Hallucinated imports
foreach ($imp in $allImports.Keys) {
    $isRelative = $imp -match '^\.\.?/'
    $isAlias = $imp -match '^@/|^~/'
    $isInPackageJson = $pkgDeps.ContainsKey($imp) -or $pkgDeps.ContainsKey(($imp -split '/')[0])
    if (-not $isRelative -and -not $isAlias -and -not $isInPackageJson) {
        $smells += @{
            type = 'possible_hallucinated_import'
            package = $imp
            occurrences = $allImports[$imp]
            message = "$imp imported but not found in package.json - possible AI hallucination"
        }
    }
}

# Long files
foreach ($fd in $fileData) {
    if ($fd.lines -gt 200) {
        $smells += @{
            type = 'long_file'
            file = $fd.path
            lines = $fd.lines
            message = "$($fd.path) has $($fd.lines) lines - consider splitting into smaller modules"
        }
    }
}

# Files with async but no return type detection
foreach ($fd in $fileData) {
    if ($fd.has_async) {
        $missingReturnType = $false
        foreach ($exp in $fd.exports) {
            $exportLine = ""
            for ($i = 0; $i -lt $fileData.Count; $i++) {
                if ($fileData[$i].path -eq $fd.path) { break }
            }
        }
    }
}

$result = @{
    check = 'aismell'
    status = if ($smells.Count -gt 0) { 'fail' } else { 'pass' }
    raw = @{
        files_scanned = $fileData.Count
        total_imports = $allImports.Count
        total_exports = $allExports.Count
        dependencies_in_package_json = $pkgDeps.Count
    }
    smells = $smells
    summary = @{ total = $smells.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 4)
