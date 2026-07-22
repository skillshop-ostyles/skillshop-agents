[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Only,
    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'rs', 'go'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$manifestsFound = @()

# -- 1. Manifest-Parsing --
# name -> [ordered]@{ name; declared; scope }
$deps = [ordered]@{}

$pkgJsonPath = Join-Path $root 'package.json'
if (Test-Path -LiteralPath $pkgJsonPath) {
    $manifestsFound += 'package.json'
    $pkg = Get-Content -LiteralPath $pkgJsonPath -Raw | ConvertFrom-Json
    if ($pkg.dependencies) {
        foreach ($p in $pkg.dependencies.PSObject.Properties) {
            $deps[$p.Name] = [ordered]@{ name = $p.Name; declared = $p.Value; scope = 'prod' }
        }
    }
    if ($pkg.devDependencies) {
        foreach ($p in $pkg.devDependencies.PSObject.Properties) {
            $deps[$p.Name] = [ordered]@{ name = $p.Name; declared = $p.Value; scope = 'dev' }
        }
    }
}

$reqTxtPath = Join-Path $root 'requirements.txt'
if (Test-Path -LiteralPath $reqTxtPath) {
    $manifestsFound += 'requirements.txt'
    foreach ($line in (Get-Content -LiteralPath $reqTxtPath -ErrorAction SilentlyContinue)) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('#') -or $l.StartsWith('-')) { continue }
        $m = [regex]::Match($l, '^([A-Za-z0-9_.\-]+)\s*([=<>!~]{1,2}=?\s*[\w.\-\*]*)?')
        if ($m.Success) {
            $name = $m.Groups[1].Value
            $declared = if ($m.Groups[2].Value) { $m.Groups[2].Value.Trim() } else { '*' }
            $deps[$name] = [ordered]@{ name = $name; declared = $declared; scope = 'prod' }
        }
    }
}

$pyprojectPath = Join-Path $root 'pyproject.toml'
if (Test-Path -LiteralPath $pyprojectPath) {
    $manifestsFound += 'pyproject.toml'
    # Best-effort TOML line scan (simplicity first, no full TOML parser): lines
    # of the form  name = "version"  within [...dependencies] sections.
    $inDeps = $false
    foreach ($line in (Get-Content -LiteralPath $pyprojectPath -ErrorAction SilentlyContinue)) {
        $l = $line.Trim()
        if ($l -match '^\[.*[Dd]ependencies.*\]$') { $inDeps = $true; continue }
        if ($l -match '^\[') { $inDeps = $false; continue }
        if ($inDeps -and $l -match '^([A-Za-z0-9_.\-]+)\s*=\s*"?([^"\r\n]*)"?') {
            $name = $matches[1]
            if ($name -eq 'python') { continue }
            $deps[$name] = [ordered]@{ name = $name; declared = $matches[2]; scope = 'prod' }
        }
    }
}

$cargoPath = Join-Path $root 'Cargo.toml'
if (Test-Path -LiteralPath $cargoPath) {
    $manifestsFound += 'Cargo.toml'
    $inDeps = $false
    foreach ($line in (Get-Content -LiteralPath $cargoPath -ErrorAction SilentlyContinue)) {
        $l = $line.Trim()
        if ($l -match '^\[dependencies\]$') { $inDeps = $true; continue }
        if ($l -match '^\[') { $inDeps = $false; continue }
        if ($inDeps -and $l -match '^([A-Za-z0-9_.\-]+)\s*=') {
            $name = $matches[1]
            $deps[$name] = [ordered]@{ name = $name; declared = ($l -replace '^[A-Za-z0-9_.\-]+\s*=\s*', ''); scope = 'prod' }
        }
    }
}

$goModPath = Join-Path $root 'go.mod'
if (Test-Path -LiteralPath $goModPath) {
    $manifestsFound += 'go.mod'
    foreach ($line in (Get-Content -LiteralPath $goModPath -ErrorAction SilentlyContinue)) {
        $m = [regex]::Match($line.Trim(), '^([\w\.\-/]+)\s+(v[\d\.\w\-+]+)')
        if ($m.Success) {
            $name = $m.Groups[1].Value
            $deps[$name] = [ordered]@{ name = $name; declared = $m.Groups[2].Value; scope = 'prod' }
        }
    }
}

if ($manifestsFound.Count -eq 0) {
    Write-Error "No supported manifest found (package.json, requirements.txt, pyproject.toml, Cargo.toml, go.mod) in: $root"
    exit 1
}

if ($Only -and $Only.Count -gt 0) {
    $keep = [ordered]@{}
    foreach ($name in $Only) { if ($deps.Contains($name)) { $keep[$name] = $deps[$name] } }
    $deps = $keep
}

# -- 2. Lockfile counting (count only, no depth analysis) --
$transitiveCount = 0
$lockNpm = Join-Path $root 'package-lock.json'
$lockYarn = Join-Path $root 'yarn.lock'
$lockPnpm = Join-Path $root 'pnpm-lock.yaml'
$lockPoetry = Join-Path $root 'poetry.lock'
$lockCargo = Join-Path $root 'Cargo.lock'
$lockGoSum = Join-Path $root 'go.sum'

if (Test-Path -LiteralPath $lockNpm) {
    # ConvertFrom-Json fails under PowerShell 5.1 on npm lockfile v3: the
    # root package entry in "packages" has the empty string "" as key, and
    # PSCustomObject does not allow empty property names. JavaScriptSerializer
    # returns a hashtable/dictionary instead, which handles it.
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    $lock = $serializer.DeserializeObject((Get-Content -LiteralPath $lockNpm -Raw))
    if ($lock.ContainsKey('packages')) {
        $transitiveCount = @($lock['packages'].Keys | Where-Object { $_ -ne '' }).Count
    } elseif ($lock.ContainsKey('dependencies')) {
        $transitiveCount = @($lock['dependencies'].Keys).Count
    }
} elseif (Test-Path -LiteralPath $lockYarn) {
    $transitiveCount = @(Select-String -LiteralPath $lockYarn -Pattern '^\S.*:$').Count
} elseif (Test-Path -LiteralPath $lockPnpm) {
    $transitiveCount = @(Select-String -LiteralPath $lockPnpm -Pattern "^\s{2}[^\s:]+@[\d]").Count
} elseif (Test-Path -LiteralPath $lockPoetry) {
    $transitiveCount = @(Select-String -LiteralPath $lockPoetry -Pattern '^\[\[package\]\]$').Count
} elseif (Test-Path -LiteralPath $lockCargo) {
    $transitiveCount = @(Select-String -LiteralPath $lockCargo -Pattern '^\[\[package\]\]$').Count
} elseif (Test-Path -LiteralPath $lockGoSum) {
    $transitiveCount = @(Get-Content -LiteralPath $lockGoSum -ErrorAction SilentlyContinue | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -Unique).Count
}

# -- 3. Nutzungsstellen-Scan im eigenen Code --
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)

$dependencyResults = @(
    foreach ($d in $deps.Values) {
        # Import/require/use-Zeilen inkl. Subpfade (<dep>/...), Scoped Packages (@scope/paket).
        $escaped = [regex]::Escape($d.name)
        $pattern = "(from\s+['""]$escaped(?:/[^'""]*)?['""]|require\(\s*['""]$escaped(?:/[^'""]*)?['""]\s*\)|import\s+['""]$escaped(?:/[^'""]*)?['""]|\buse\s+$escaped\b)"
        $usage = @(
            foreach ($f in $sourceFiles) {
                $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
                $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $line = [string]$lines[$i]
                    if ($line -match $pattern) {
                        [ordered]@{ file = $relPath; line = ($i + 1); text = $line.Trim() }
                    }
                }
            }
        )
        [ordered]@{
            name       = $d.name
            declared   = $d.declared
            scope      = $d.scope
            usage      = $usage
            usageCount = $usage.Count
        }
    }
)

$unusedDeclared = @($dependencyResults | Where-Object { $_.usageCount -eq 0 } | ForEach-Object { $_.name })

$result = [ordered]@{
    manifests        = $manifestsFound
    dependencies     = $dependencyResults
    transitiveCount  = $transitiveCount
    unusedDeclared   = $unusedDeclared
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== DEPS-INVENTORY ==="
Write-Output "  Manifeste: $($manifestsFound -join ', ')"
Write-Output "  Direkte Dependencies: $($dependencyResults.Count)"
Write-Output "  Transitive Pakete (Lockfile): $transitiveCount"
Write-Output "  Unused (0 Fundstellen): $($unusedDeclared.Count)$(if ($unusedDeclared.Count -gt 0) { ' -> ' + ($unusedDeclared -join ', ') })"
