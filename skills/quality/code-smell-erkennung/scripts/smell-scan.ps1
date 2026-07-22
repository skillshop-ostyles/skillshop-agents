[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs,*.swift,*.kt,*.cpp,*.h,*.hpp,*.rs",

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
            if (-not $skip -and $f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*" -and $f.FullName -notlike "*\.next\*") {
                $files += $f
            }
        }
    }
    return $files
}

function Get-Context {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 3)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $ctx = @()
    for ($i = $start; $i -le $end; $i++) {
        $ctx += $Lines[$i]
    }
    return ($ctx -join "`n")
}

function Get-FunctionExtent {
    param([string[]]$Lines, [int]$StartIndex)
    $braces = 0
    $end = $Lines.Length - 1
    $found = $false
    for ($i = $StartIndex; $i -le $end; $i++) {
        $line = $Lines[$i]
        $oc = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $cc = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        $braces += $oc - $cc
        if ($braces -gt 0) { $found = $true }
        if ($found -and $braces -le 0) { return $i }
    }
    return -1
}

function Get-IndentLevel {
    param([string]$Line)
    if ($Line -match '^(\s+)\S') {
        $spaces = $matches[1].Length
        return [Math]::Floor($spaces / 2)
    }
    return 0
}

function Test-FunctionHead {
    param([string]$Line)
    $tl = $Line.TrimStart()
    if ($tl -match '^(public|private|protected|internal)\s') { return $true }
    if ($tl -match '^(static|async|abstract|virtual|override)\s') { return $true }
    if ($tl -match '^(function|def |fn |func |sub |constructor)\s') { return $true }
    if ($tl -match '^(if|for|while|switch|catch|foreach|else)\s') { return $false }
    if ($tl -match '^(\w+\s*\(.*\)\s*{)') { return $true }
    if ($tl -match '^(\w+\s*=\s*(function|async|\(.*\)\s*=>))') { return $true }
    return $false
}

$files = Get-SourceFiles -Dir $ProjectDir
$findings = @()
$findingId = 0

# Pre-analysis: collect all class/function definitions per file
$fileClassInfo = @{}
$fileFuncInfo = @{}
$fileSymbolUsage = @{}

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch {
        continue
    }

    # --- 1. Long method detection ---
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if (Test-FunctionHead -Line $line) {
            # Find function body start
            $bodyStart = $i
            $endIdx = Get-FunctionExtent -Lines $lines -StartIndex $bodyStart
            if ($endIdx -gt $bodyStart) {
                $execLines = 0
                for ($j = $bodyStart; $j -le $endIdx; $j++) {
                    $tl = $lines[$j].Trim()
                    if ($tl -and -not $tl.StartsWith('//') -and -not $tl.StartsWith('#') -and -not $tl.StartsWith('/*') -and -not $tl.StartsWith('*') -and -not $tl.StartsWith("'''") -and -not $tl.StartsWith('"""')) {
                        $execLines++
                    }
                }
                if ($execLines -gt 30) {
                    $findingId++
                    $ctx = Get-Context -Lines $lines -LineIndex $bodyStart
                    $sig = $lines[$bodyStart].Trim()
                    $findings += @{
                        id = $findingId
                        smell = "long-method"
                        severity = "medium"
                        file = $relativePath
                        line = $bodyStart + 1
                        metric = @{ executableLines = $execLines; threshold = 30 }
                        evidence = $sig.Substring(0, [Math]::Min(200, $sig.Length))
                        context = $ctx.Substring(0, [Math]::Min(500, $ctx.Length))
                    }
                }
            }
        }
    }

    # --- 2. Deep nesting detection ---
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $tl = $line.Trim()
        if (-not $tl -or $tl.StartsWith('//') -or $tl.StartsWith('#') -or $tl.StartsWith('/*') -or $tl.StartsWith('*')) { continue }
        $level = Get-IndentLevel -Line $line
        if ($level -gt 4) {
            $findingId++
            $ctx = Get-Context -Lines $lines -LineIndex $i
            $findings += @{
                id = $findingId
                smell = "deep-nesting"
                severity = "medium"
                file = $relativePath
                line = $i + 1
                metric = @{ indentLevel = $level; threshold = 4 }
                evidence = $tl.Substring(0, [Math]::Min(200, $tl.Length))
                context = $ctx.Substring(0, [Math]::Min(500, $ctx.Length))
            }
        }
    }

    # --- 3. Message chain detection ---
    $chainMatches = [regex]::Matches($content, '(?i)\b\w+(\.\w+){3,}')
    foreach ($m in $chainMatches) {
        if ($m.Value -match '\.(length|toString|valueOf|toUpperCase|toLowerCase|trim|charAt|charCodeAt)') { continue }
        $findingId++
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        $ctx = Get-Context -Lines $lines -LineIndex $lineIndex
        $findings += @{
            id = $findingId
            smell = "message-chain"
            severity = "low"
            file = $relativePath
            line = $lineNum
            metric = @{ chainDepth = ($m.Value -split '\.').Length - 1; threshold = 3 }
            evidence = $m.Value.Substring(0, [Math]::Min(200, $m.Value.Length))
            context = $ctx.Substring(0, [Math]::Min(500, $ctx.Length))
        }
    }

    # --- 4. Primitive obsession ---
    $typeMatches = [regex]::Matches($content, '(?i)\b(int|string|bool|float|double|decimal|byte|char)\s+\w+\b')
    $typeCounts = @{}
    foreach ($m in $typeMatches) {
        $t = $m.Groups[1].Value.ToLower()
        if (-not $typeCounts.ContainsKey($t)) { $typeCounts[$t] = 0 }
        $typeCounts[$t]++
    }
    foreach ($kv in $typeCounts.GetEnumerator()) {
        if ($kv.Value -gt 15) {
            $findingId++
            $findings += @{
                id = $findingId
                smell = "primitive-obsession"
                severity = "low"
                file = $relativePath
                line = 1
                metric = @{ type = $kv.Key; occurrences = $kv.Value; threshold = 15 }
                evidence = "Type '$($kv.Key)' used $($kv.Value) times in this file"
                context = "File: $relativePath - consider wrapping $($kv.Key) in a domain type."
            }
        }
    }
}

# --- 5. God class (multi-file aggregated) ---
$fileSizeInfo = @{}
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch { continue }

    $classMatches = [regex]::Matches($content, '(?i)(class |interface |abstract class )\s+(\w+)')
    $methodCount = 0
    $methodMatches = [regex]::Matches($content, '(?i)(public |private |protected )?(static |abstract |virtual |override )?(async )?(function |def |sub |void |int |string |bool |var |let |const )?\w+\s*\(')
    $methodCount = $methodMatches.Count

    if ($lines.Length -gt 300 -and $methodCount -gt 10 -and $classMatches.Count -gt 0) {
        $findingId++
        $className = $classMatches[0].Groups[2].Value
        $findings += @{
            id = $findingId
            smell = "god-class"
            severity = "high"
            file = $relativePath
            line = 1
            metric = @{ lines = $lines.Length; methods = $methodCount; classes = $classMatches.Count; thresholdLines = 300 }
            evidence = "Class '$className': $($lines.Length) lines, $methodCount methods"
            context = "File: $relativePath - consider splitting into smaller classes."
        }
    }

    # Track for data clump and feature envy
    $fileFuncInfo[$relativePath] = @{
        methods = $methodMatches | ForEach-Object { $_.Value }
        classes = $classMatches | ForEach-Object { $_.Groups[2].Value }
        lines = $lines
    }

    $fileSymbolUsage[$relativePath] = @{
        ownSymbols = @()
        externalSymbols = @()
    }
}

# --- 6. Data clump ---
$allParamSets = @{}
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }

    # Extract parameter lists from function/constructor definitions
    $funcMatches = [regex]::Matches($content, '(?i)(function|def|constructor|__init__)\s*[\(]?[\w]*\s*[\(]([^)]*)\)')
    foreach ($fm in $funcMatches) {
        $params = $fm.Groups[2].Value -split ',' | ForEach-Object {
            $_.Trim() -replace '=.*$', '' -replace '^\w+\s+', ''
        } | Where-Object { $_ -and $_ -notmatch '^\s*$' -and $_.Length -lt 40 }
        $pset = $params | Sort-Object | ForEach-Object { $_.ToLower().Trim() }
        $key = $pset -join ','
        if ($pset.Count -ge 3) {
            if (-not $allParamSets.ContainsKey($key)) { $allParamSets[$key] = @() }
            $allParamSets[$key] += @{ file = $relativePath; line = ($content.Substring(0, $fm.Index) -split "`n").Length }
        }
    }
}
# Flag parameter sets appearing 3+ times across the codebase
foreach ($kv in $allParamSets.GetEnumerator()) {
    if ($kv.Value.Count -ge 3) {
        $params = ($kv.Key -split ',' | ForEach-Object { $_.Trim() }) -join ', '
        foreach ($loc in $kv.Value) {
            $findingId++
            $findings += @{
                id = $findingId
                smell = "data-clump"
                severity = "medium"
                file = $loc.file
                line = $loc.line
                metric = @{ occurrences = $kv.Value.Count; threshold = 3 }
                evidence = "Parameter set ($params) appears $($kv.Value.Count) times"
                context = "File: $($loc.file):$($loc.line) - consider creating a parameter object for ($params)."
            }
        }
    }
}

# --- 7. Shotgun surgery ---
# Detect concepts (class/function/interface names) referenced in 5+ files
$conceptFiles = @{}
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }

    $concepts = [regex]::Matches($content, '(?i)(class |interface |type |enum |trait )\s+(\w+)')
    foreach ($c in $concepts) {
        $name = $c.Groups[2].Value
        if ($name -and $name.Length -gt 2) {
            if (-not $conceptFiles.ContainsKey($name)) { $conceptFiles[$name] = @{} }
            $conceptFiles[$name][$relativePath] = $true
        }
    }
}
foreach ($kv in $conceptFiles.GetEnumerator()) {
    $spread = $kv.Value.Keys.Count
    if ($spread -ge 5) {
        # The concept is scattered -- find the definition file
        $defFile = $kv.Value.Keys | Select-Object -First 1
        foreach ($pf in $kv.Value.Keys) {
            try {
                $pc = Get-Content -LiteralPath (Join-Path $ProjectDir $pf) -Raw -ErrorAction SilentlyContinue
                if ($pc -match "(?i)(class |interface )$($kv.Key)\b") {
                    $defFile = $pf
                    break
                }
            } catch {}
        }
        $findingId++
        $findings += @{
            id = $findingId
            smell = "shotgun-surgery"
            severity = "high"
            file = $defFile
            line = 1
            metric = @{ filesAffected = $spread; threshold = 5 }
            evidence = "Concept '$($kv.Key)' referenced across $spread files"
            context = "Affected files: $(($kv.Value.Keys | Select-Object -First 5) -join ', ')... - consider consolidating related logic."
        }
    }
}

# --- 8. Feature envy ---
# Heuristic: method that references more external types than its own class
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch { continue }

    $classMatch = [regex]::Match($content, '(?i)(class |interface )\s+(\w+)')
    if (-not $classMatch.Success) { continue }
    $className = $classMatch.Groups[2].Value

    $funcBodies = [regex]::Matches($content, '(?i)(function |def |sub )\s+(\w+)\s*\([^)]*\)\s*{?')
    foreach ($fb in $funcBodies) {
        $funcName = $fb.Groups[2].Value
        $funcStart = ($content.Substring(0, $fb.Index) -split "`n").Length - 1
        $funcEnd = Get-FunctionExtent -Lines $lines -StartIndex $funcStart
        if ($funcEnd -le $funcStart) { continue }

        $funcBody = ""
        for ($j = $funcStart; $j -le $funcEnd -and $j -lt $lines.Length; $j++) {
            $funcBody += $lines[$j] + " "
        }

        # Count references to own class (use [regex]::escape for variable-like patterns)
        $selfRefs = [regex]::Matches($funcBody, "(?i)\b(this)\b|\b(self)\b|\b(me)\b|$className").Count
        # Count references to external .something
        $extRefs = [regex]::Matches($funcBody, '(?i)\b\w+\.\w+\s*\(').Count

        if ($extRefs -gt $selfRefs -and $extRefs -gt 5) {
            $findingId++
            $ctx = Get-Context -Lines $lines -LineIndex $funcStart
            $findings += @{
                id = $findingId
                smell = "feature-envy"
                severity = "medium"
                file = $relativePath
                line = $funcStart + 1
                metric = @{ selfRefs = $selfRefs; externalRefs = $extRefs }
                evidence = "Method '$funcName': $selfRefs self-references vs $extRefs external references"
                context = $ctx.Substring(0, [Math]::Min(500, $ctx.Length))
            }
        }
    }
}

# --- 9. Refused bequest ---
# Heuristic: subclass that extends a base class, checks if it overrides <20% of base class methods
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch { continue }

    # Match class definitions that extend another class
    $extendMatches = [regex]::Matches($content, '(?i)(class |interface )\s+(\w+)\s+(extends|implements|inherits|<:|:)\s+(\w+)')
    foreach ($em in $extendMatches) {
        $subClass = $em.Groups[2].Value
        $baseClass = $em.Groups[4].Value
        if ($baseClass -eq 'Object' -or $baseClass -eq 'object') { continue }

        # Find the base class definition
        $baseContent = $null
        foreach ($sf2 in $files) {
            $cn = Get-Content -LiteralPath $sf2.FullName -Raw -ErrorAction SilentlyContinue
            if ($cn -match "(?i)(class |interface )\s+$baseClass\b") {
                $baseContent = $cn
                break
            }
        }
        if (-not $baseContent) { continue }

        $baseMethods = [regex]::Matches($baseContent, '(?i)(public |private |protected )?(function |def |sub |void |int |string |bool )?\s*\w+\s*\(')
        $subMethods = [regex]::Matches($content, '(?i)(public |private |protected )?(function |def |sub |void |int |string |bool )?\s*\w+\s*\(')

        if ($baseMethods.Count -gt 0 -and $subMethods.Count -gt 0) {
            $overrideRatio = [Math]::Min(1.0, [Math]::Round($subMethods.Count / $baseMethods.Count, 2))
            if ($overrideRatio -lt 0.2) {
                $findingId++
                $lineNum = ($content.Substring(0, $em.Index) -split "`n").Length
                $ctx = Get-Context -Lines $lines -LineIndex $lineNum - 1
                $findings += @{
                    id = $findingId
                    smell = "refused-bequest"
                    severity = "medium"
                    file = $relativePath
                    line = $lineNum
                    metric = @{ baseMethods = $baseMethods.Count; subclassMethods = $subMethods.Count; overrideRatio = $overrideRatio; threshold = 0.2 }
                    evidence = "'$subClass' extends '$baseClass' - override ratio $overrideRatio ($($subMethods.Count)/$($baseMethods.Count))"
                    context = $ctx.Substring(0, [Math]::Min(500, $ctx.Length))
                }
            }
        }
    }
}

# --- 10. Speculative generality ---
# Detect abstract classes / interfaces that are defined but never referenced
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }

    $abstractMatches = [regex]::Matches($content, '(?i)(abstract class |interface |trait )\s+(\w+)')
    foreach ($am in $abstractMatches) {
        $name = $am.Groups[2].Value
        $type = $am.Groups[1].Value.Trim()

        # Check if any file in the project references this name
        $refCount = 0
        foreach ($sf in $files) {
            $sc = Get-Content -LiteralPath $sf.FullName -Raw -ErrorAction SilentlyContinue
            if ($sc -and $sc -match "\b$name\b") { $refCount++ }
        }

        # RefCount=1 means only the definition file references it
        if ($refCount -le 1) {
            $findingId++
            $lineNum = ($content.Substring(0, $am.Index) -split "`n").Length
            $findings += @{
                id = $findingId
                smell = "speculative-generality"
                severity = "low"
                file = $relativePath
                line = $lineNum
                metric = @{ referenceCount = $refCount; threshold = 1 }
                evidence = "$type '$name' defined here but referenced nowhere else ($refCount references)"
                context = "File: $relativePath - if this abstraction has no consumers, remove it (YAGNI)."
            }
        }
    }
}

# Deduplicate deep nesting findings: keep only the deepest per file
$nestingFindings = $findings | Where-Object { $_.smell -eq 'deep-nesting' } | Group-Object file
$keepNestingIds = @{}
foreach ($nf in $nestingFindings) {
    $maxLevel = ($nf.Group | Sort-Object -Property { $_.metric.indentLevel } -Descending | Select-Object -First 1)
    $keepNestingIds[$maxLevel.id] = $true
}
$findings = $findings | Where-Object {
    if ($_.smell -eq 'deep-nesting' -and -not $keepNestingIds.ContainsKey($_.id)) { $false } else { $true }
}

# Deduplicate message chain: keep one per file
$chainFindings = $findings | Where-Object { $_.smell -eq 'message-chain' } | Group-Object file
$keepChainIds = @{}
foreach ($cf in $chainFindings) {
    $maxDepth = ($cf.Group | Sort-Object -Property { $_.metric.chainDepth } -Descending | Select-Object -First 1)
    $keepChainIds[$maxDepth.id] = $true
}
$findings = $findings | Where-Object {
    if ($_.smell -eq 'message-chain' -and -not $keepChainIds.ContainsKey($_.id)) { $false } else { $true }
}

# Deduplicate data clump: keep one set per unique parameter group
$clumpFindings = $findings | Where-Object { $_.smell -eq 'data-clump' } | Group-Object { $_.metric.occurrences }
$keepClumpIds = @{}
foreach ($cf in $clumpFindings) {
    $first = $cf.Group | Select-Object -First 1
    $keepClumpIds[$first.id] = $true
}
$findings = $findings | Where-Object {
    if ($_.smell -eq 'data-clump' -and -not $keepClumpIds.ContainsKey($_.id)) { $false } else { $true }
}

# Count stats - use Group-Object for reliable counting
$sevCounts = @{ high = 0; medium = 0; low = 0 }
foreach ($f in $findings) {
    $s = $f.severity
    if ($sevCounts.ContainsKey($s)) { $sevCounts[$s]++ }
}
$smellCounts = @{}
foreach ($f in $findings) {
    $s = $f.smell
    if (-not $smellCounts.ContainsKey($s)) { $smellCounts[$s] = 0 }
    $smellCounts[$s]++
}
$total = $findings.Count

$output = @{
    findings = $findings
    counts = @{
        total = $total
        bySeverity = $sevCounts
        bySmell = $smellCounts
    }
    summary = "Found $total code smell(s): $($sevCounts.high) high, $($sevCounts.medium) medium, $($sevCounts.low) low severity."
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

Write-Output "=== Code Smell Scan Complete ==="
Write-Output "  Scanned: $($files.Count) files in $ProjectDir"
Write-Output "  Findings: $total (high: $($sevCounts.high), medium: $($sevCounts.medium), low: $($sevCounts.low))"
Write-Output "  By smell:"
foreach ($s in $smellCounts.GetEnumerator() | Sort-Object Name) {
    Write-Output "    $($s.Key): $($s.Value)"
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps 4-5"
