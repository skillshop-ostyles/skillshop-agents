[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",

    # How far back to compare for "identical at past ref". Default 100 commits.
    [int]$LookbackCommits = 100,
    [string]$PastRef = ""
)

# Use SilentlyContinue within loops; global Stop only for setup errors.
$ErrorActionPreference = 'Continue'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir '.git') -PathType Any)) {
    Write-Error "ProjectDir must be inside a git repo for drift tracking (needs git history)."
    Write-Output "ProjectDir: $ProjectDir"
    Write-Output "Joined: $(Join-Path $ProjectDir '.git')"
    exit 1
}

function Get-FunctionBlocks($content) {
    # Extract `function NAME(...) { ... }` and `export function NAME...` blocks.
    # Normalize line endings (CRLF vs LF) and whitespace before hashing so
    # the same content from `get-content` and `git show` produces the same hash.
    $content = $content -replace "`r`n", "`n"
    $blocks = @()
    $lines = $content -split "`n"
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -match '^\s*(export\s+)?(async\s+)?function\s+(\w+)\s*\(') {
            $name = $matches[3]
            $start = $i
            $depth = 0
            $end = $i
            $seenBrace = $false
            for ($j = $i; $j -lt $lines.Count; $j++) {
                foreach ($c in $lines[$j].ToCharArray()) {
                    if ($c -eq '{') { $depth++; $seenBrace = $true }
                    elseif ($c -eq '}') {
                        $depth--
                        if ($seenBrace -and $depth -eq 0) { $end = $j; break }
                    }
                }
            }
            $body = ($lines[$start..$end] -join ' ') -replace '\s+', ' '
            $hash = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($body.Trim())
            ) | ForEach-Object { $_.ToString('x2') }
            $blocks += @{ file = ''; name = $name; hash = ($hash -join ''); signature = $body.Substring(0, [Math]::Min(120, $body.Length)) }
            $i = $end + 1
        } else {
            $i++
        }
    }
    return ,$blocks
}

# Step 1: identify clone candidates in the CURRENT tree using a simple
# whitespace-normalized hash of function bodies. Cheap and stable.

# Step 2: collect current-tree blocks.
$currentBlocks = @{}
foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $blocks = Get-FunctionBlocks $content
        foreach ($b in $blocks) {
            $b.file = $rel
            $key = "$($b.name)|$($b.hash)"
            if (-not $currentBlocks.ContainsKey($key)) {
                $currentBlocks[$key] = @()
            }
            $currentBlocks[$key] += $b
        }
    }
}

# Step 3: resolve past ref.
$pastRefResolved = $PastRef
if (-not $pastRefResolved) {
    $pastRefResolved = "HEAD~$LookbackCommits"
}
$validRef = $true
$testRef = git -C $ProjectDir rev-parse --verify $pastRefResolved 2>&1
if ($LASTEXITCODE -ne 0) { $validRef = $false }

# Step 4: collect past-tree blocks (one-shot; if ref is invalid, skip).
# Each past entry is keyed by (file, name, hash) to preserve file-level identity.
$pastBlocks = @{}
if ($validRef) {
    # Collect distinct file list from currentBlocks.
    $pastFiles = @{}
    foreach ($key in $currentBlocks.Keys) {
        foreach ($b in $currentBlocks[$key]) {
            if (-not $pastFiles.ContainsKey($b.file)) { $pastFiles[$b.file] = $true }
        }
    }
    foreach ($file in $pastFiles.Keys) {
        $pastContent = git -C $ProjectDir show "$pastRefResolved`:$file" 2>&1 | Out-String
        if ($pastContent -match 'fatal:') { continue }
        $pBlocks = Get-FunctionBlocks $pastContent
        foreach ($pb in $pBlocks) {
            $pb.file = $file
            $pkey = "$file|$($pb.name)"
            if (-not $pastBlocks.ContainsKey($pkey)) {
                $pastBlocks[$pkey] = @()
            }
            $pastBlocks[$pkey] += $pb
        }
    }
}

# Step 5: find pairs that USED to share a hash but no longer do.
# Key insight: for each (file, name) PAIR (separately for current and past),
# compare the body hashes. Same name+file, different hash = drift.
$driftPairs = @()
$checked = @{}
foreach ($cKey in $currentBlocks.Keys) {
    $cParts = $cKey -split '\|'
    $cName = $cParts[0]
    $cHash = $cParts[1]
    foreach ($cb in $currentBlocks[$cKey]) {
        # Look up the past version of THIS file's name.
        $pKeyForFile = "$($cb.file)|$cName"
        if (-not $pastBlocks.ContainsKey($pKeyForFile)) { continue }
        foreach ($pb in $pastBlocks[$pKeyForFile]) {
            if ($pb.hash -eq $cHash) { continue }  # No drift
            $k = "$($cb.file)|$cName"
            if ($checked.ContainsKey($k)) { continue }
            $checked[$k] = $true
            $driftPairs += @{
                functionName = $cName
                currentFile = $cb.file
                pastFile = $pb.file
                currentHash = $cHash
                pastHash = $pb.hash
                pastRef = $pastRefResolved
                pastSnippet = $pb.signature
                currentSnippet = $cb.signature
            }
        }
    }
}

# Dedupe by (name, currentFile, pastFile).
$dedup = @{}
foreach ($d in $driftPairs) {
    $k = "$($d.functionName)|$($d.currentFile)|$($d.pastFile)"
    if (-not $dedup.ContainsKey($k)) { $dedup[$k] = $d }
}

$result = @{
    pairs = @($dedup.Values)
    counts = @{
        currentBlocks = ($currentBlocks.Keys | Measure-Object).Count
        pastBlocks = ($pastBlocks.Keys | Measure-Object).Count
        driftPairs = $dedup.Count
    }
    pastRef = $pastRefResolved
}

Write-Output "=== Clone Drift Scan Complete ==="
Write-Output "  Current blocks: $($result.counts.currentBlocks)"
Write-Output "  Past blocks at $($pastRefResolved): $($result.counts.pastBlocks)"
Write-Output "  Drift pairs: $($result.counts.driftPairs)"
foreach ($d in @($dedup.Values | Select-Object -First 10)) {
    Write-Output "  $($d.functionName): $($d.currentFile) vs $($d.pastFile)"
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
