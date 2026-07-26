[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
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

# Middleware-mount sites that APPLY authz. Pattern allows a path string
# or no path before the function call.
$middlewareMountRegex = 'app\.use\s*\(\s*(?:["\x27][^"\x27,]+["\x27]\s*,\s*)?(?:requireAuth|ensureRole|requireRole|authMiddleware|checkAuth)\s*\(\s*["\x27]?(\w+)["\x27]?\s*\)'

# Local check sites (explicit, file-local roles/permissions).
$localCheckRegex = '\b(?:req\.user\?|user)\b.{0,30}\brole\b|hasRole\s*\(|req\.user\.role\s*[!=]=|if\s*\(\s*.+\.role\b|isAdmin\s*\(|isGodMode\s*\('

# Mutating routes.
$mutatingRouteRegex = '(?:app|router|adminRouter)\.(?:post|put|patch|delete)\s*\(\s*["\x27][^"\x27,]+["\x27]'

$mounts = @()         # list of "file|line -> roleMounted"
$localChecks = @()    # list of "file|line"
$mutatingRoutes = @()
$count = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
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
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $count += 1
        $lines = $content -split "`n"
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li].Trim()
            if ($ln -match '^\s*(import|require|from|export\s+\{|//\s*|#)') { continue }

            if ($ln -match $middlewareMountRegex) {
                $mounts += @{ file = $rel; line = $li + 1; mountLine = $ln }
            }
            if ($ln -match $localCheckRegex) {
                $localChecks += @{ file = $rel; line = $li + 1; checkLine = $ln }
            }
            if ($ln -match $mutatingRouteRegex) {
                $mutatingRoutes += @{ file = $rel; line = $li + 1; routeLine = $ln }
            }
        }
    }
}

# Heuristic gap detection:
# Unprotected mutating endpoint: file matches a middleware-mount AFTER its
# registration, but no local check within -5..+25 lines.
$gappedMutating = @()
foreach ($m in $mutatingRoutes) {
    $hasLocal = $false
    foreach ($c in $localChecks) {
        if ($c.file -eq $m.file -and [Math]::Abs($c.line - $m.line) -le 25) { $hasLocal = $true; break }
    }
    if (-not $hasLocal) {
        $hasMountAfter = $false
        foreach ($mt in $mounts) {
            if ($mt.file -eq $m.file -and $mt.line -le $m.line) { $hasMountAfter = $true; break }
        }
        $gappedMutating += @{
            file = $m.file
            line = $m.line
            route = $m.routeLine
            onlyInheritsAuthz = $hasMountAfter
        }
    }
}

Write-Output "=== AuthZ-Coverage Scan Complete ==="
Write-Output "  Files scanned: $count"
Write-Output "  Middleware-mount authz: $($mounts.Count)"
Write-Output "  Local explicit authz checks: $($localChecks.Count)"
Write-Output "  Mutating routes: $($mutatingRoutes.Count)"
Write-Output "  Mutating routes without local explicit check: $($gappedMutating.Count)"
Write-Output "  ...of which only inherit middleware authz: $(@($gappedMutating | Where-Object { $_.onlyInheritsAuthz }).Count)"

$result = @{
    mounts = $mounts
    localChecks = $localChecks
    mutatingRoutes = $mutatingRoutes
    gapRoutes = $gappedMutating
    counts = @{
        scannedFiles = $count
        middlewareMounts = $mounts.Count
        localChecks = $localChecks.Count
        mutatingRoutes = $mutatingRoutes.Count
        gapRoutes = $gappedMutating.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
