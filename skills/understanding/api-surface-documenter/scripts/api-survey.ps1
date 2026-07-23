[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# --------------------------------------------------------------------
# Pattern registries for each API type.
# --------------------------------------------------------------------

# REST route patterns
$restPatterns = @(
    @{ regex='(?:app|router)\.(get|post|put|patch|delete|use)\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='express' }
    @{ regex='router\.(get|post|put|patch|delete|use)\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='express-router' }
    @{ regex='@(Get|Post|Put|Patch|Delete|RequestMapping)\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='nest' }
    @{ regex='@(?:app|blueprint)\.route\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='flask' }
    @{ regex='@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping)\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='spring' }
    @{ regex='@app\.(get|post|put|patch|delete)\s*\('; kind='fastapi' }
)

# Event handler patterns
$eventPatterns = @(
    @{ regex='\.on\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='node-on' }
    @{ regex='\.addListener\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='node-addlistener' }
    @{ regex='@(EventListener|KafkaListener|RabbitListener)\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='spring-event' }
    @{ regex='signal\.connect\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='python-signal' }
    @{ regex='event\.listen\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='python-event' }
    @{ regex='<-\s*(\w+Chan|ch\w*)\b'; kind='go-channel' }
)

# CLI command patterns
$cliPatterns = @(
    @{ regex='\.command\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='yargs' }
    @{ regex='\.demandCommand\b'; kind='yargs-demand' }
    @{ regex='\.command\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='commander' }
    @{ regex='\.option\s*\(\s*["\x27]-{1,2}(\w[\w-]*)["\x27]'; kind='commander-option' }
    @{ regex='add_argument\s*\(\s*["\x27]-{1,2}(\w[\w-]*)["\x27]'; kind='argparse' }
    @{ regex='add_subparsers\s*\('; kind='argparse-sub' }
    @{ regex='@click\.command\s*\(\s*["\x27]([^"\x27]+)["\x27]'; kind='click' }
    @{ regex='@click\.option\s*\(\s*["\x27]-{1,2}(\w[\w-]*)["\x27]'; kind='click-option' }
)

# Library export patterns
$libPatterns = @(
    @{ regex='export\s+\{\s*([^}]+)\s*\}\s*from\s*["\x27]'; kind='re-export' }
    @{ regex='from\s+\.\s*import\s+(.+)'; kind='py-init-import' }
    @{ regex='pub\s+fn\s+(\w+)'; kind='rust-pub-fn' }
    @{ regex='"(?:main|exports|module)"\s*:\s*["\x27]([^"\x27]+)["\x27]'; kind='package-export' }
)

# --------------------------------------------------------------------
# SCAN
# --------------------------------------------------------------------
$apis = @()
$linesScanned = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        $linesScanned += $lines.Count

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]

            # Skip comment-only lines.
            if ($ln -match '^\s*[/#*]') { continue }

            # --- REST routes ---
            foreach ($p in $restPatterns) {
                $m = [regex]::Match($ln, $p.regex)
                if ($m.Success) {
                    $method = if ($m.Groups.Count -gt 1) { $m.Groups[1].Value.ToUpper() } else { 'ANY' }
                    $route = if ($m.Groups.Count -gt 2) { $m.Groups[2].Value } else { $m.Groups[1].Value }
                    $name = "$method $route"
                    $params = @()
                    # Extract route params like :id, :userId
                    $route -replace ':(\w+)', {
                        $params += $matches[1]
                    }
                    $hasDocs = $false
                    if ($li -ge 1) {
                        for ($i = $li - 1; $i -ge 0 -and $i -ge $li - 5; $i--) {
                            if ($lines[$i] -match '^\s*[/#*]{2,}') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*"""') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*\w') { break }
                        }
                    }
                    $apis += @{
                        file = $rel
                        line = $li + 1
                        apiType = 'rest'
                        name = "$method $route"
                        method = $method
                        route = $route
                        params = $params
                        hasDocs = $hasDocs
                    }
                    break
                }
            }

            # --- Event handlers ---
            foreach ($p in $eventPatterns) {
                $m = [regex]::Match($ln, $p.regex)
                if ($m.Success) {
                    $eventName = $m.Groups[1].Value
                    $hasDocs = $false
                    if ($li -ge 1) {
                        for ($i = $li - 1; $i -ge 0 -and $i -ge $li - 5; $i--) {
                            if ($lines[$i] -match '^\s*[/#*]{2,}\s*@') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*[/#*]{2,}\s') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*"""') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*\w') { break }
                        }
                    }
                    $apis += @{
                        file = $rel
                        line = $li + 1
                        apiType = 'event'
                        name = $eventName
                        method = ''
                        route = ''
                        event = $eventName
                        params = @()
                        hasDocs = $hasDocs
                    }
                    break
                }
            }

            # --- CLI commands ---
            foreach ($p in $cliPatterns) {
                $m = [regex]::Match($ln, $p.regex)
                if ($m.Success) {
                    $cmdName = if ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { '<subcommand>' }
                    $hasDocs = $false
                    if ($li -ge 1) {
                        for ($i = $li - 1; $i -ge 0 -and $i -ge $li - 5; $i--) {
                            if ($lines[$i] -match '^\s*[/#*]{2,}') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*"""') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*\w') { break }
                        }
                    }
                    $apis += @{
                        file = $rel
                        line = $li + 1
                        apiType = 'cli'
                        name = $cmdName
                        method = ''
                        route = ''
                        command = $cmdName
                        params = @()
                        hasDocs = $hasDocs
                    }
                    break
                }
            }

            # --- Library exports ---
            foreach ($p in $libPatterns) {
                $m = [regex]::Match($ln, $p.regex)
                if ($m.Success) {
                    $exportName = $m.Groups[1].Value.Trim()
                    $hasDocs = $false
                    if ($li -ge 1) {
                        for ($i = $li - 1; $i -ge 0 -and $i -ge $li - 5; $i--) {
                            if ($lines[$i] -match '^\s*[/#*]{2,}') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*"""') { $hasDocs = $true; break }
                            if ($lines[$i] -match '^\s*\w') { break }
                        }
                    }
                    $apis += @{
                        file = $rel
                        line = $li + 1
                        apiType = 'lib'
                        name = $exportName
                        method = ''
                        route = ''
                        export = $exportName
                        params = @()
                        hasDocs = $hasDocs
                    }
                    break
                }
            }
        }
    }
}

# --------------------------------------------------------------------
# REPORT
# --------------------------------------------------------------------
$restCount = @($apis | Where-Object { $_.apiType -eq 'rest' }).Count
$eventCount = @($apis | Where-Object { $_.apiType -eq 'event' }).Count
$cliCount = @($apis | Where-Object { $_.apiType -eq 'cli' }).Count
$libCount = @($apis | Where-Object { $_.apiType -eq 'lib' }).Count

Write-Output "=== API Surface Survey Complete ==="
$fileSet = @($apis | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files with API surface: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total APIs: $($apis.Count)"
Write-Output "  REST routes: $restCount"
Write-Output "  Event handlers: $eventCount"
Write-Output "  CLI commands: $cliCount"
Write-Output "  Library exports: $libCount"

$result = @{
    apis = $apis
    counts = @{
        files = $fileSet.Count
        linesScanned = $linesScanned
        totalApis = $apis.Count
        rest = $restCount
        event = $eventCount
        cli = $cliCount
        lib = $libCount
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
