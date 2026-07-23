[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.rs",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Extension list
$extList = ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# Public symbol detection patterns per language
$exportPatterns = @(
    # JS/TS exports
    @{ regex='export\s+(?:function|class|const|let|var|interface|type|enum)\s+(\w+)'; lang='ts' }
    @{ regex='export\s+default\s+(?:function|class)\s+(\w+)'; lang='ts' }
    @{ regex='module\.exports\s*=\s*(\w+)'; lang='js' }
    @{ regex='module\.exports\s*=\s*\{([^}]+)\}'; lang='js' }
    @{ regex='exports\.(\w+)\s*='; lang='js' }
    # Python
    @{ regex='^def\s+(\w+)\s*\('; lang='py' }
    @{ regex='^class\s+(\w+)'; lang='py' }
    @{ regex='^async\s+def\s+(\w+)\s*\('; lang='py' }
    # C# / Java
    @{ regex='public\s+(?:static\s+)?(?:class|interface|record)\s+(\w+)'; lang='cs' }
    @{ regex='public\s+(?:static\s+)?\w+\s+(\w+)\s*\('; lang='cs' }
    @{ regex='public\s+(?:static\s+)?(?:class|interface|enum)\s+(\w+)'; lang='java' }
    @{ regex='public\s+(?:static\s+)?\w+\s+(\w+)\s*\('; lang='java' }
    # Go
    @{ regex='^func\s+[A-Z]\w+\s*\('; lang='go' }
    @{ regex='^func\s+\([^)]+\)\s+[A-Z]\w+\s*\('; lang='go' }
    # Rust
    @{ regex='^pub\s+(?:fn|struct|trait|enum)\s+(\w+)'; lang='rs' }
    @{ regex='^pub\s+fn\s+(\w+)'; lang='rs' }
    @{ regex='^pub\s+struct\s+(\w+)'; lang='rs' }
    @{ regex='^pub\s+trait\s+(\w+)'; lang='rs' }
)

# Call detection: function/method calls within project
$callPatterns = @(
    @{ regex='(\w+)\s*\(' }       # generic function call
    @{ regex='(\w+)\.(\w+)\s*\(' } # method call
)

# Module-level function extraction for call-graph building
$functionPatterns = @(
    @{ regex='(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*\('; lang='ts' }
    @{ regex='(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*\('; lang='js' }
    @{ regex='^def\s+(\w+)\s*\('; lang='py' }
    @{ regex='(?:let|const|var)\s+(\w+)\s*=\s*(?:async\s*)?\('; lang='ts' }
)

# Collect files
$files = @()
foreach ($ext in $extList) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $files += @{ fullPath = $fn; relPath = $rel; ext = $ext }
    }
}

# Phase 1: Extract public symbols per file
$moduleNames = @{}
$modules = @{}  # relPath -> { publicSymbols[], functions[] }

foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.fullPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $module = @{
        file = $f.relPath
        publicSymbols = @()
        functions = @()
    }
    $lines = $content -split "`n"

    # Detect public symbols
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        foreach ($p in $exportPatterns) {
            $m = [regex]::Match($ln, $p.regex)
            if ($m.Success) {
                $symbol = $m.Groups[1].Value
                if ($symbol) {
                    $module.publicSymbols += @{ name = $symbol; line = $li + 1 }
                }
            }
        }
    }

    # Detect function names for call graph
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        foreach ($p in $functionPatterns) {
            $m = [regex]::Match($ln, $p.regex)
            if ($m.Success) {
                $fnName = $m.Groups[1].Value
                if ($fnName) {
                    $module.functions += @{ name = $fnName; line = $li + 1 }
                }
            }
        }
    }

    $modules[$f.relPath] = $module
}

# Phase 2: Build call graph — which function calls which (within project)
# Map function names to their owning module
$fnToModule = @{}
foreach ($rel in $modules.Keys) {
    $mod = $modules[$rel]
    foreach ($fn in $mod.functions) {
        $fnToModule[$fn.name] = $rel
    }
}

# Extract all function-like calls from each file and cross-reference with known functions
$edges = @()  # { fromFile, toFile, count }
$edgeMap = @{}  # key "fromFile|toFile" -> count

foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.fullPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $fromFile = $f.relPath
    $lines = $content -split "`n"

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        # Find all call-like patterns
        foreach ($cp in $callPatterns) {
            $matches = [regex]::Matches($ln, $cp.regex)
            foreach ($match in $matches) {
                $calledFn = $match.Groups[1].Value
                # Check if this is a known function in the project
                if ($fnToModule.ContainsKey($calledFn)) {
                    $toFile = $fnToModule[$calledFn]
                    if ($toFile -ne $fromFile) {
                        $key = "$fromFile|$toFile"
                        $edgeMap[$key] = ($edgeMap[$key] -or 0) + 1
                    }
                }
            }
        }
    }
}

foreach ($key in $edgeMap.Keys) {
    $parts = $key -split '\|'
    $edges += @{ fromFile = $parts[0]; toFile = $parts[1]; count = $edgeMap[$key] }
}

# Phase 3: Build adjacency matrix and cluster by call density
$modList = @($modules.Keys)
$adj = @{}  # "from|to" -> count

foreach ($edge in $edges) {
    $adj["$($edge.fromFile)|$($edge.toFile)"] = $edge.count
}

# For each pair of modules, calculate inter-call density
# Density = calls_between / (calls_in_from + calls_in_to) — simplified
# Simple clustering: modules with >30% inter-call density form a cluster
$modulePairs = @()
for ($i = 0; $i -lt $modList.Count; $i++) {
    for ($j = $i + 1; $j -lt $modList.Count; $j++) {
        $mA = $modList[$i]
        $mB = $modList[$j]
        $fwd = if ($adj.ContainsKey("$mA|$mB")) { $adj["$mA|$mB"] } else { 0 }
        $bwd = if ($adj.ContainsKey("$mB|$mA")) { $adj["$mB|$mA"] } else { 0 }
        $totalBetween = $fwd + $bwd
        # Count intra-module calls
        $intraA = 0; $intraB = 0
        foreach ($k in $adj.Keys) {
            $parts = $k -split '\|'
            if ($parts[0] -eq $mA -and $parts[1] -eq $mA) { $intraA += $adj[$k] }
            if ($parts[0] -eq $mB -and $parts[1] -eq $mB) { $intraB += $adj[$k] }
        }
        $totalIntra = $intraA + $intraB
        $totalCalls = $totalBetween + $totalIntra
        $density = if ($totalCalls -gt 0) { $totalBetween / $totalCalls } else { 0 }
        $modulePairs += @{ a = $mA; b = $mB; between = $totalBetween; density = $density }
    }
}

# Greedy clustering: start with each module solo, merge pairs with density > 0.3
$clusterOf = @{}  # module -> clusterId
$nextClusterId = 0
foreach ($m in $modList) {
    $clusterOf[$m] = $nextClusterId
    $nextClusterId++
}

$merged = $true
while ($merged) {
    $merged = $false
    foreach ($pair in ($modulePairs | Sort-Object density -Descending)) {
        if ($pair.density -gt 0.3) {
            $cA = $clusterOf[$pair.a]
            $cB = $clusterOf[$pair.b]
            if ($cA -ne $cB) {
                # Merge — reassign all modules from cB to cA
                foreach ($m in $modList) {
                    if ($clusterOf[$m] -eq $cB) { $clusterOf[$m] = $cA }
                }
                $merged = $true
            }
        }
    }
}

# Re-index clusters to be contiguous
$clusterIds = @($clusterOf.Values | Sort-Object -Unique)
$clusterIndex = @{}
for ($ci = 0; $ci -lt $clusterIds.Count; $ci++) {
    $clusterIndex[$clusterIds[$ci]] = $ci
}

# Build output structures
$modulesOutput = @()
$clusterModules = @{}  # clusterId -> list of modules
foreach ($m in $modList) {
    $cid = $clusterIndex[$clusterOf[$m]]
    $mod = $modules[$m]
    # Count intra-cluster and inter-cluster calls for this module
    $intraClusterCalls = 0
    $interClusterCalls = 0
    foreach ($edge in $edges) {
        if ($edge.fromFile -eq $m) {
            $targetCluster = $clusterIndex[$clusterOf[$edge.toFile]]
            if ($targetCluster -eq $cid) {
                $intraClusterCalls += $edge.count
            } else {
                $interClusterCalls += $edge.count
            }
        }
    }
    $modulesOutput += @{
        file = $m
        clusterId = $cid
        publicSymbols = $mod.publicSymbols
        functions = $mod.functions
        intraClusterCalls = $intraClusterCalls
        interClusterCalls = $interClusterCalls
    }
    if (-not $clusterModules.ContainsKey($cid)) { $clusterModules[$cid] = @() }
    $clusterModules[$cid] += $m
}

$clustersOutput = @()
foreach ($cid in ($clusterModules.Keys | Sort-Object)) {
    $modsInCluster = $clusterModules[$cid]
    # Calculate call density for this cluster
    $totalInter = 0
    $totalIntra = 0
    foreach ($edge in $edges) {
        $fromCid = $clusterIndex[$clusterOf[$edge.fromFile]]
        $toCid = $clusterIndex[$clusterOf[$edge.toFile]]
        if ($fromCid -eq $cid -and $toCid -eq $cid) {
            $totalIntra += $edge.count
        } elseif ($fromCid -eq $cid -or $toCid -eq $cid) {
            $totalInter += $edge.count
        }
    }
    $totalCalls = $totalIntra + $totalInter
    $density = if ($totalCalls -gt 0) { [math]::Round($totalIntra / $totalCalls, 3) } else { 0 }
    $clustersOutput += @{
        clusterId = $cid
        modules = $modsInCluster
        totalModules = $modsInCluster.Count
        intraClusterCalls = $totalIntra
        interClusterCalls = $totalInter
        density = $density
    }
}

# Console summary
Write-Output "=== Domain Map Complete ==="
Write-Output "  Modules scanned: $($modList.Count)"
Write-Output "  Clusters found: $($clustersOutput.Count)"
foreach ($cl in ($clustersOutput | Sort-Object clusterId)) {
    Write-Output "  Cluster $($cl.clusterId): $($cl.totalModules) modules, density=$($cl.density)"
}
Write-Output "  Call edges: $($edges.Count)"

# Overall call graph density
$allCalls = ($edges | Measure-Object count -Sum).Sum
$graphDensity = if ($modList.Count -gt 1) { [math]::Round($edges.Count / ($modList.Count * ($modList.Count - 1) / 2), 3) } else { 1 }

$result = @{
    modules = $modulesOutput
    clusters = $clustersOutput
    callGraph = @{
        edges = $edges
        density = $graphDensity
    }
    counts = @{
        scannedFiles = $modList.Count
        clusters = $clustersOutput.Count
        callEdges = $edges.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
