[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$FromRef = "HEAD~10",

    [string]$ToRef = "HEAD",

    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# --- Helper: run git command, return output lines ---
function Invoke-Git {
    param([string[]]$Arguments)
    $out = & git -C "$ProjectDir" @Arguments 2>&1
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        return $null
    }
    if ($out -is [string]) { return @($out) }
    return $out
}

# --- 1. Git log ---
$logLines = Invoke-Git @('log', '--oneline', "$FromRef..$ToRef")
if ($null -eq $logLines) {
    Write-Warning "git log failed (no commits or invalid refs). Check -FromRef / -ToRef."
    $logLines = @()
}
$commits = @()
foreach ($line in $logLines) {
    $line = $line.Trim()
    if ($line -match '^([a-f0-9]+)\s+(.*)') {
        $commits += @{ hash = $matches[1]; message = $matches[2] }
    }
}

# --- 2. Git diff --stat ---
$statLines = Invoke-Git @('diff', '--stat', "$FromRef..$ToRef")
if ($null -eq $statLines) {
    Write-Warning "git diff --stat failed."
    $statLines = @()
}
$totalInsertions = 0
$totalDeletions = 0
$filesChanged = 0
$parsedFiles = @()

foreach ($line in $statLines) {
    $line = $line.Trim()
    if ($line -match '^(.+?)\s+\|\s+(\d+)\s+([+-]+)') {
        $filePath = $matches[1].Trim()
        $fileChanges = [int]$matches[2]
        $changes = $matches[3]
        $ins = 0; $del = 0
        foreach ($ch in $changes.ToCharArray()) {
            if ($ch -eq '+') { $ins++ }
            elseif ($ch -eq '-') { $del++ }
        }
        if ($ins -eq 0 -and $del -eq 0) { $ins = $fileChanges; $del = 0 }
        $filesChanged++
        $totalInsertions += $ins
        $totalDeletions += $del
        $parsedFiles += @{ file = $filePath; insertions = $ins; deletions = $del }
    }
}

# --- 3. Full diff ---
$diffLines = Invoke-Git @('diff', "$FromRef..$ToRef")
if ($null -eq $diffLines) {
    Write-Warning "git diff failed."
    $diffLines = @()
}

$perFileDiff = @{}
$currentFile = $null
$currentLines = @()
foreach ($line in $diffLines) {
    if ($line -match '^diff --git a/(.+)\s+b/(.+)$') {
        if ($currentFile) {
            $perFileDiff[$currentFile] = $currentLines -join "`n"
        }
        $currentFile = $matches[1]
        $currentLines = @($line)
    } elseif ($currentFile) {
        $currentLines += $line
    }
}
if ($currentFile) {
    $perFileDiff[$currentFile] = $currentLines -join "`n"
}

# --- 4. Parse per-file: import changes, signature changes ---
$fileDetails = @()
foreach ($entry in $parsedFiles) {
    $fp = $entry.file
    $diffContent = $perFileDiff[$fp]
    $newImports = @()
    $removedImports = @()
    $signatureChanges = @()

    if ($diffContent) {
        $lines = $diffContent -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            # New import/require
            if ($l -match '^\+import\s+') {
                $newImports += $l.Substring(1).Trim()
            }
            if ($l -match '^\+.*require\s*\(') {
                $newImports += $l.Substring(1).Trim()
            }
            # Removed import/require
            if ($l -match '^-import\s+') {
                $removedImports += $l.Substring(1).Trim()
            }
            if ($l -match '^-.*require\s*\(') {
                $removedImports += $l.Substring(1).Trim()
            }
            # Signature changes: added function/method
            if ($l -match '^\+export\s+(?:function|class|interface|type|const)\s+(\w+)') {
                $signatureChanges += @{ kind = 'added'; name = $matches[1] }
            }
            if ($l -match '^\+.*(?:function|method)\s+(\w+)\s*\(') {
                $signatureChanges += @{ kind = 'added'; name = $matches[1] }
            }
            # Removed function/method
            if ($l -match '^-export\s+(?:function|class|interface|type|const)\s+(\w+)') {
                $signatureChanges += @{ kind = 'removed'; name = $matches[1] }
            }
            if ($l -match '^-.*(?:function|method)\s+(\w+)\s*\(') {
                $signatureChanges += @{ kind = 'removed'; name = $matches[1] }
            }
            # Parameter changes (look for parameter list additions in function signatures)
            if ($l -match '^\+.*\)\s*:\s*\w+') {
                # new or modified return type
            }
        }
    }

    $fileDetails += @{
        file = $fp
        insertions = $entry.insertions
        deletions = $entry.deletions
        newImports = $newImports
        removedImports = $removedImports
        signatureChanges = $signatureChanges
    }
}

# --- 5. Cluster by top-level directory/module ---
$modules = @{}
foreach ($fd in $fileDetails) {
    $parts = $fd.file -split '[\\/]'
    $moduleName = if ($parts.Count -gt 1) { $parts[0] } else { '(root)' }
    if (-not $modules.ContainsKey($moduleName)) {
        $modules[$moduleName] = @{
            name = $moduleName
            files = @()
            insertions = 0
            deletions = 0
        }
    }
    $modules[$moduleName].files += $fd.file
    $modules[$moduleName].insertions += $fd.insertions
    $modules[$moduleName].deletions += $fd.deletions
}

$moduleList = @()
foreach ($k in $modules.Keys) {
    $moduleList += $modules[$k]
}

# --- 6. Change summary ---
$insertionBuckets = @{ feature = 0; bugfix = 0; refactor = 0; chore = 0; breaking = 0 }
$deletionBuckets = @{ feature = 0; bugfix = 0; refactor = 0; chore = 0; breaking = 0 }

$changeSummary = @{
    commitCount = $commits.Count
    fileCount = $filesChanged
    insertions = $totalInsertions
    deletions = $totalDeletions
    moduleCount = $moduleList.Count
}

# --- 7. Console summary ---
Write-Output "=== Changelog Diff Complete ==="
Write-Output "  From: $FromRef  To: $ToRef"
Write-Output "  Commits: $($commits.Count)"
Write-Output "  Files changed: $filesChanged"
Write-Output "  Insertions: $totalInsertions"
Write-Output "  Deletions: $totalDeletions"
Write-Output "  Modules: $($moduleList.Count)"
foreach ($m in $moduleList) {
    Write-Output "    $($m.name): $($m.files.Count) files, +$($m.insertions)/-$($m.deletions)"
}

# --- 8. JSON output ---
$result = @{
    fromRef = $FromRef
    toRef = $ToRef
    commits = $commits
    files = $fileDetails
    modules = $moduleList
    stats = @{
        insertions = $totalInsertions
        deletions = $totalDeletions
        filesChanged = $filesChanged
    }
    changeSummary = $changeSummary
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
