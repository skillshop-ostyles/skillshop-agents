[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs,*.swift,*.kt,*.rs",

    [string]$Exclude = "",

    [string]$LayersJson = ""
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

function Normalize($p) {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
    return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
}
$claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
$targetPath = Normalize $ProjectDir
if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\")) {
    Write-Error "PROTECTION: ProjectDir is inside $claudeRoot. Aborting."
    exit 1
}

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

# Default layer map
if ($LayersJson) {
    try { $layerMap = $LayersJson | ConvertFrom-Json } catch { $layerMap = $null }
}
if (-not $layerMap) {
    $layerMap = @{
        ui = @('ui', 'view', 'views', 'pages', 'components', 'web', 'client')
        domain = @('domain', 'core', 'model', 'logic', 'services')
        data = @('data', 'dal', 'repo', 'repository', 'infrastructure', 'db', 'persistence')
    }
}

$generatedMarkers = @('@generated', 'auto-generated', 'DO NOT EDIT', 'This file is generated')
$binaryExts = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.pdf', '.zip', '.lock')

function Get-SourceFiles {
    param([string]$Dir)
    $files = @()
    foreach ($ext in $extList) {
        $found = Get-ChildItem -Path $Dir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($f in $found) {
            $skip = $false
            foreach ($ex in $excludeList) {
                if ($f.FullName -like "*$ex*") { $skip = $true; break }
            }
            if ($skip) { continue }
            $fp = $f.FullName
            if ($fp -match '\\node_modules\\' -or $fp -match '\\.git\\' -or $fp -match '\\venv\\' -or $fp -match '\\__pycache__\\' -or $fp -match '\\.next\\' -or $fp -match '\\coverage\\' -or $fp -match '\\dist\\' -or $fp -match '\\build\\') { continue }
            foreach ($be in $binaryExts) { if ($f.Extension -eq $be) { continue } }
            $files += $f
        }
    }
    return $files
}

function Get-RelativePath {
    param([string]$FullPath)
    return $FullPath.Substring($ProjectDir.Length).TrimStart('\')
}

function Get-Layer {
    param([string]$RelPath)
    $parts = $relPath -split '[\\/]'
    foreach ($part in $parts) {
        foreach ($layer in $layerMap.Keys) {
            foreach ($pattern in $layerMap[$layer]) {
                if ($part -eq $pattern -or $part -like "$pattern*") {
                    return $layer
                }
            }
        }
    }
    return '_unknown'
}

function Resolve-Import {
    param([string]$ImportPath, [string]$FromFile)
    if ($ImportPath.StartsWith('.', 'CurrentCultureIgnoreCase') -or $ImportPath.StartsWith('..')) {
        $fromDir = Split-Path -Parent $FromFile
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $fromDir $ImportPath))
        # Try common extensions
        $candidates = @("$resolved.js", "$resolved.ts", "$resolved.jsx", "$resolved.tsx", "$resolved/index.js", "$resolved/index.ts", "$resolved/index.jsx", "$resolved/index.tsx", "$resolved.py", "$resolved.rb", "$resolved.php", "$resolved.go", "$resolved.java", "$resolved.cs", "$resolved.ps1", "$resolved.kt", "$resolved.rs")
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c -PathType Leaf) {
                return (Get-RelativePath -FullPath $c)
            }
        }
        # Try without extension
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            return (Get-RelativePath -FullPath $resolved)
        }
        return $null
    }
    return $null
}

function Detect-Cycles {
    param([hashtable]$Graph)
    $cycles = @()
    $visited = @{}
    $recStack = @{}

    function DFS($node, [System.Collections.ArrayList]$path) {
        if ($recStack.ContainsKey($node)) {
            $startIdx = $path.IndexOf($node)
            if ($startIdx -ge 0) {
                $cycle = $path[$startIdx..($path.Count - 1)] + $node
                $cycles += @{ nodes = @($cycle); length = $cycle.Count - 1 }
            }
            return
        }
        if ($visited.ContainsKey($node)) { return }
        $visited[$node] = $true
        $recStack[$node] = $true
        [void]$path.Add($node)
        if ($Graph.ContainsKey($node)) {
            foreach ($neighbor in $Graph[$node]) {
                DFS $neighbor $path
            }
        }
        [void]$path.RemoveAt($path.Count - 1)
        $recStack.Remove($node)
    }

    foreach ($node in $Graph.Keys) {
        DFS $node (New-Object System.Collections.ArrayList)
    }

    # Deduplicate cycles (same set of nodes, different rotation)
    $seen = @{}
    $unique = @()
    foreach ($c in $cycles) {
        $sorted = ($c.nodes | Sort-Object) -join '->'
        if (-not $seen.ContainsKey($sorted)) {
            $seen[$sorted] = $true
            $unique += $c
        }
    }
    return $unique
}

$files = Get-SourceFiles -Dir $ProjectDir
$modules = @{}
$importGraph = @{}
$allRelPaths = @{}

foreach ($f in $files) {
    $rel = Get-RelativePath -FullPath $f.FullName
    $allRelPaths[$rel] = $true
    $ext = $f.Extension.ToLower()
    try {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }

    $imports = @()
    $exports = @()

    switch -Regex ($ext) {
        '\.ps1' {
            # dot-source and using module
            $ms = [regex]::Matches($content, '\.\s*''([^'']+)''|\.\s*"([^"]+)"|using\s+module\s+''([^'']+)''')
            foreach ($m in $ms) {
                $ip = ($m.Groups | Where-Object { $_.Value -and $_.Index -ne $m.Index } | Select-Object -First 1).Value
                if ($ip) { $imports += @{ path = $ip; kind = 'dot-source' } }
            }
            # functions defined
            $funcs = [regex]::Matches($content, '(?i)function\s+(\w+)')
            foreach ($fn in $funcs) { $exports += $fn.Groups[1].Value }
        }
        '\.py' {
            $ms = [regex]::Matches($content, '(?m)^import\s+(\S+)|^from\s+(\S+)\s+import')
            foreach ($m in $ms) {
                $ip = $m.Groups[1].Value
                if (-not $ip) { $ip = $m.Groups[2].Value }
                if ($ip -and $ip -notmatch '^\s*#') { $imports += @{ path = ($ip -split '\s+as\s+')[0]; kind = 'import' } }
            }
            # class/def exports
            $defs = [regex]::Matches($content, '(?m)^(class|def)\s+(\w+)')
            foreach ($d in $defs) { $exports += $d.Groups[2].Value }
        }
        { '.js','.ts','.jsx','.tsx' -contains $_ } {
            # Extract all string literals after import/require keywords
            # Pattern 1: import x from 'y', import {x} from 'y', import 'y'
            $ms1 = [regex]::Matches($content, '(?i)import\s+(?:\{[^}]*\}|\w+(?:\s*,\s*(?:\{[^}]*\}|\w+))?)?\s*from\s+["'']([^"''\\]*)["'']')
            foreach ($m in $ms1) { $ip = $m.Groups[1].Value.Trim(); if ($ip) { $imports += @{ path = $ip; kind = 'import' } } }
            # Pattern 2: namespace import: import * as x from 'y'
            $ms2 = [regex]::Matches($content, '(?i)import\s+\*\s+as\s+\w+\s+from\s+["'']([^"''\\]*)["'']')
            foreach ($m in $ms2) { $ip = $m.Groups[1].Value.Trim(); if ($ip) { $imports += @{ path = $ip; kind = 'import' } } }
            # Pattern 3: require('y')
            $ms3 = [regex]::Matches($content, '(?i)require\s*\(\s*["'']([^"''\\]*)["'']\s*\)')
            foreach ($m in $ms3) { $ip = $m.Groups[1].Value.Trim(); if ($ip) { $imports += @{ path = $ip; kind = 'import' } } }
            # Pattern 4: dynamic import('y')
            $ms4 = [regex]::Matches($content, '(?i)import\s*\(\s*["'']([^"''\\]*)["'']\s*\)')
            foreach ($m in $ms4) { $ip = $m.Groups[1].Value.Trim(); if ($ip) { $imports += @{ path = $ip; kind = 'import' } } }
            # Pattern 5: export ... from 'y'
            $ms5 = [regex]::Matches($content, '(?i)export\s+(?:\{[^}]*\}|\*\s+from)\s+from\s+["'']([^"''\\]*)["'']')
            foreach ($m in $ms5) { $ip = $m.Groups[1].Value.Trim(); if ($ip) { $imports += @{ path = $ip; kind = 'import' } } }
            # exports: function/class/const names with export keyword
            $exp = [regex]::Matches($content, '(?i)(?:^|export\s+)(?:default\s+)?(?:function|class)\s+(\w+)')
            foreach ($e in $exp) { $n = $e.Groups[1].Value; if ($n) { $exports += $n } }
        }
        '\.rb' {
            $ms = [regex]::Matches($content, '(?i)^\s*require\s+[''"]([^''"]+)[''"]|^require_relative\s+[''"]([^''"]+)[''"]')
            foreach ($m in $ms) {
                $ip = $m.Groups[1].Value; if (-not $ip) { $ip = $m.Groups[2].Value }
                if ($ip) { $imports += @{ path = $ip; kind = 'require' } }
            }
        }
        '\.php' {
            $ms = [regex]::Matches($content, '(?i)(?:require|include|require_once|include_once)\s*\(?\s*[''"]([^''"]+)[''"]\s*\)?')
            foreach ($m in $ms) { if ($m.Groups[1].Value) { $imports += @{ path = $m.Groups[1].Value; kind = 'include' } } }
        }
        '\.go' {
            $ms = [regex]::Matches($content, '(?m)^\s*import\s+\(?([^)]*)\)?')
            foreach ($m in $ms) {
                $pkgs = [regex]::Matches($m.Groups[1].Value, '[''"]([^''"]+)[''"]')
                foreach ($p in $pkgs) {
                    $ip = $p.Groups[1].Value
                    if ($ip -match '\.') { $imports += @{ path = $ip; kind = 'external' } }
                    else { $imports += @{ path = $ip; kind = 'import' } }
                }
            }
        }
        '\.java' {
            $ms = [regex]::Matches($content, '(?m)^import\s+([\w.]+);')
            foreach ($m in $ms) { if ($m.Groups[1].Value) { $imports += @{ path = $m.Groups[1].Value; kind = 'import' } } }
        }
        '\.cs' {
            $ms = [regex]::Matches($content, '(?m)^using\s+([\w.]+);')
            foreach ($m in $ms) { if ($m.Groups[1].Value) { $imports += @{ path = $m.Groups[1].Value; kind = 'import' } } }
        }
    }

    $modules[$rel] = @{ file = $rel; imports = @(); exports = @($exports | Select-Object -Unique) }
    foreach ($imp in $imports) {
        $resolved = Resolve-Import -ImportPath $imp.path -FromFile $f.FullName
        $modules[$rel].imports += @{ path = $imp.path; resolved = $resolved; kind = if ($resolved) { $imp.kind } else { 'external' } }
    }
}

# Deduplicate imports per module
foreach ($rel in $modules.Keys) {
    $seen = @{}
    $modules[$rel].imports = $modules[$rel].imports | Where-Object {
        $key = "$($_.path)|$($_.resolved)"
        if ($seen.ContainsKey($key)) { $false } else { $seen[$key] = $true; $true }
    }
}

# Build graph for cycle detection
$graph = @{}
foreach ($rel in $modules.Keys) {
    $graph[$rel] = @()
    foreach ($imp in $modules[$rel].imports) {
        if ($imp.resolved -and $allRelPaths.ContainsKey($imp.resolved)) {
            $graph[$rel] += $imp.resolved
        }
    }
}

$cycles = Detect-Cycles -Graph $graph

# Compute fan-in/fan-out
$fanIn = @{}
foreach ($rel in $modules.Keys) { $fanIn[$rel] = 0 }
foreach ($rel in $modules.Keys) {
    foreach ($imp in $modules[$rel].imports) {
        if ($imp.resolved -and $allRelPaths.ContainsKey($imp.resolved)) {
            $fanIn[$imp.resolved]++
        }
    }
}

$fanOut = @{}
foreach ($rel in $modules.Keys) {
    $fo = ($modules[$rel].imports | Where-Object { $_.resolved -and $allRelPaths.ContainsKey($_.resolved) }).Count
    $fanOut[$rel] = $fo
}

# Layer assignments
$layerAssignments = @{}
foreach ($rel in $modules.Keys) {
    $layerAssignments[$rel] = Get-Layer -RelPath $rel
}

# Layer violations
$violations = @()
foreach ($rel in $modules.Keys) {
    $fromLayer = $layerAssignments[$rel]
    foreach ($imp in $modules[$rel].imports) {
        if ($imp.resolved -and $allRelPaths.ContainsKey($imp.resolved)) {
            $toLayer = $layerAssignments[$imp.resolved]
            if ($fromLayer -ne '_unknown' -and $toLayer -ne '_unknown' -and $fromLayer -ne $toLayer) {
                $layerKeys = @($layerMap.Keys)
                $fromIdx = [array]::IndexOf($layerKeys, $fromLayer)
                $toIdx = [array]::IndexOf($layerKeys, $toLayer)
                if ($fromIdx -ge 0 -and $toIdx -ge 0 -and $toIdx -gt $fromIdx) {
                    $violations += @{
                        fromFile = $rel
                        toFile = $imp.resolved
                        fromLayer = $fromLayer
                        toLayer = $toLayer
                        description = "Layer violation: $fromLayer layer ($rel) imports from $toLayer layer ($($imp.resolved))"
                    }
                }
            }
        }
    }
}

# Entry points: files not imported by any other project file
$importedFiles = @{}
foreach ($rel in $modules.Keys) {
    foreach ($imp in $modules[$rel].imports) {
        if ($imp.resolved -and $allRelPaths.ContainsKey($imp.resolved)) {
            $importedFiles[$imp.resolved] = $true
        }
    }
}
$entryPoints = @($modules.Keys | Where-Object { -not $importedFiles.ContainsKey($_) } | Sort-Object)

# Health metrics
$totalModules = $modules.Count
$avgFanOut = if ($totalModules -gt 0) { [Math]::Round(($fanOut.Values | Measure-Object -Sum).Sum / $totalModules, 2) } else { 0 }
$avgFanIn = if ($totalModules -gt 0) { [Math]::Round(($fanIn.Values | Measure-Object -Sum).Sum / $totalModules, 2) } else { 0 }
$cycleCount = $cycles.Count
$violationCount = $violations.Count
$healthScore = [Math]::Max(0, [Math]::Min(1.0, [Math]::Round(1.0 - ($cycleCount * 0.05) - ($violationCount * 0.05), 2)))

# Build module output
$moduleOutput = @()
foreach ($rel in $modules.Keys) {
    $m = $modules[$rel]
    $fo = $fanOut[$rel]
    $fi = $fanIn[$rel]
    $instability = if (($fi + $fo) -gt 0) { [Math]::Round($fo / ($fi + $fo), 2) } else { 0 }
    $moduleOutput += @{
        file = $rel
        layer = $layerAssignments[$rel]
        imports = $m.imports
        exports = $m.exports
        fanIn = $fi
        fanOut = $fo
        instability = $instability
    }
}

$output = @{
    modules = $moduleOutput
    layerMap = $layerMap
    violations = $violations
    cycles = $cycles
    entryPoints = $entryPoints
    health = @{
        totalModules = $totalModules
        averageFanOut = $avgFanOut
        averageFanIn = $avgFanIn
        cycleCount = $cycleCount
        violationCount = $violationCount
        healthScore = $healthScore
    }
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

Write-Output "=== Architecture Scan Complete ==="
Write-Output "  Files scanned: $($files.Count)"
Write-Output "  Modules parsed: $totalModules"
Write-Output "  Layers: $(($layerAssignments.Values | Select-Object -Unique) -join ', ')"
Write-Output "  Entry points: $($entryPoints.Count)"
Write-Output "  Cycles: $cycleCount"
Write-Output "  Layer violations: $violationCount"
Write-Output "  Health score: $healthScore"
Write-Output "  Avg fan-in: $avgFanIn, Avg fan-out: $avgFanOut"
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps"
