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

# Pattern registry. Group sites by what's being checked + what role-state is read.
$roleDefineSites = @(
    @{ regex='(?:const|let|var)\s+ROLE_(\w+)\s*=\s*["\x27](\w+)["\x27]'; kind='const-assign' },
    @{ regex='(?:const|let|var)\s+ROLES\s*=\s*\{([^}]+)\}'; kind='dict-assign' },
    @{ regex='role:\s*["\x27](\w+)["\x27]'; kind='role-literal' }
)
$roleCheckSites = @(
    @{ regex='user\.role\s*===\s*["\x27](\w+)["\x27]'; kind='user-role-eq' },
    @{ regex='user\.role\s*!==\s*["\x27](\w+)["\x27]'; kind='user-role-neq' },
    @{ regex='if\s*\(\s*user\.isGodMode\b'; kind='godmode' },
    @{ regex='req\.user\.role\s*===\s*["\x27](\w+)["\x27]'; kind='req-role-eq' },
    @{ regex='req\.user\.isGodMode\b'; kind='godmode' },
    @{ regex='req\.user\s*\?\.\s*role\s*===\s*["\x27](\w+)["\x27]'; kind='opt-role-eq' },
    @{ regex='hasRole\s*\(\s*["\x27]?(\w+)["\x27]?\s*\)'; kind='hasRole-call' },
    @{ regex='@PreAuthorize\(["\x27]?hasRole\s*\(\s*["\x27]?(?:["\x27]?)?(\w+)'; kind='spring-role' },
    @{ regex='@Roles\s*\{\s*["\x27]?(\w+)["\x27]?\s*\}'; kind='jakarta-roles' },
    @{ regex='c\.getRole\s*\(\)\s*===?\s*["\x27](\w+)["\x27]'; kind='java-role' },
    @{ regex='if\s*\(\s*role\s*===?\s*["\x27](\w+)["\x27]'; kind='role-param-eq' },
    @{ regex='session\.user\.role\s*===\s*["\x27](\w+)["\x27]'; kind='session-role-eq' }
)
# Routes/middleware that APPLY a role on the chain.
$middlewareSites = @(
    @{ regex='use\s*\(\s*requireAuth\s*\(\s*["\x27]?(\w+)["\x27]?\s*\)'; kind='require-auth' },
    @{ regex='router\.use\s*\([^)]*role\s*===\s*["\x27](\w+)["\x27]'; kind='router-mount-role' },
    @{ regex='@(?:Roles|RequireRoles)\s*\(\s*["\x27](\w+)["\x27]\s*\)'; kind='anno-role' },
    @{ regex='ensureRole\s*\(\s*["\x27](\w+)["\x27]'; kind='ensure-role' }
)
$mutatingRoutes = @(
    @{ regex='router\.(post|put|patch|delete)\s*\(\s*["\x27][^"\x27]+["\x27]'; kind='http-mutating' },
    @{ regex='app\.(post|put|patch|delete)\s*\(\s*["\x27][^"\x27]+["\x27]'; kind='http-mutating-app' },
    @{ regex='@(?:PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping\s*\([^)]*method\s*=\s*RequestMethod\.(POST|PUT|DELETE|PATCH))'; kind='spring-mutating' },
    @{ regex='@app\.route\s*\(\s*["\x27][^"\x27]+["\x27]\s*,\s*methods\s*=\s*\[["\x27](POST|PUT|DELETE|PATCH)'; kind='flask-mutating' }
)

$checks = @()      # role-check sites
$mw = @()          # middleware sites
$routes = @()      # mutating routes
$defs = @()        # role defines
$mounts = @()

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
        $lines = $content -split "`n"
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            foreach ($r in $roleDefineSites) {
                $m = [regex]::Match($ln, $r.regex)
                if ($m.Success) {
                    $groupVal = if ($m.Groups.Count -gt 2) { $m.Groups[2].Value } else { '' }
                    $defs += @{ file = $rel; line = $li + 1; kind = $r.kind; group = "$($m.Groups[1].Value)=$groupVal" }
                }
            }
            foreach ($r in $roleCheckSites) {
                $m = [regex]::Match($ln, $r.regex)
                if ($m.Success) {
                    $roleVal = if ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { '<implicit>' }
                    $checks += @{ file = $rel; line = $li + 1; kind = $r.kind; role = $roleVal }
                }
            }
            foreach ($r in $middlewareSites) {
                $m = [regex]::Match($ln, $r.regex)
                if ($m.Success) {
                    $roleVal = if ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { '<implicit>' }
                    $mw += @{ file = $rel; line = $li + 1; kind = $r.kind; role = $roleVal }
                }
            }
            foreach ($r in $mutatingRoutes) {
                $m = [regex]::Match($ln, $r.regex)
                if ($m.Success) {
                    $routes += @{ file = $rel; line = $li + 1; kind = $r.kind; path = ($m.Value) }
                }
            }
        }
    }
}

# Inventory every role mentioned anywhere.
$knownRoles = @{}
foreach ($s in ($defs + $checks + $mw)) {
    if ($s.role) { $knownRoles[$s.role] = $true }
    if ($s.group) {
        # group like 'USER=user' or 'ADMIN=admin'
        if ($s.group -match '^(\w+)=(\w+)$') {
            $knownRoles[$matches[2]] = $true
            $knownRoles[$matches[1].ToLower()] = $true
        }
    }
}

# Diff: which mutating routes have NO check site nearby?
# Heuristic: same-file check within ±30 lines.
$unprotected = @()
foreach ($r in $routes) {
    $hasCheck = $false
    foreach ($c in $checks) {
        if ($c.file -eq $r.file -and [Math]::Abs($c.line - $r.line) -lt 40) { $hasCheck = $true; break }
    }
    if (-not $hasCheck) {
        $unprotected += $r
    }
}

Write-Output "=== Permission-Chain Scan Complete ==="
$fileSet = @($checks + $mw + $routes) | ForEach-Object { $_.file } | Select-Object -Unique
Write-Output "  Files scanned: $($fileSet.Count)"
Write-Output "  Role defines: $($defs.Count)"
Write-Output "  Role checks: $($checks.Count)"
Write-Output "  Middleware sites: $($mw.Count)"
Write-Output "  Mutating routes: $($routes.Count)"
Write-Output "  Unprotected mutating routes (file-local check missing): $($unprotected.Count)"
Write-Output "  Distinct roles mentioned: $($knownRoles.Keys -join ', ')"

$result = @{
    roleDefines = $defs
    roleChecks = $checks
    middleware = $mw
    mutatingRoutes = $routes
    unprotectedRoutes = $unprotected
    knownRoles = $knownRoles.Keys
    counts = @{
        scannedFiles = $fileSet.Count
        roleDefines = $defs.Count
        roleChecks = $checks.Count
        middleware = $mw.Count
        mutatingRoutes = $routes.Count
        unprotectedRoutes = $unprotected.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
