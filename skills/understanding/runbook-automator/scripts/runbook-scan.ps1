[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*",
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

$services = @()
$scripts = @{}
$ci = @()
$dockerInfo = @{ baseImage = ""; ports = @(); envs = @() }
$endpoints = @()
$healthcheckPaths = @()
$readmeCommands = @()
$allFiles = @()

# ---------------------------------------------------------------------------
# Helper: get all project files (skip node_modules, .git, venv, etc.)
# ---------------------------------------------------------------------------
function Get-ProjectFiles {
    param([string]$Pattern)
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $Pattern -File -ErrorAction SilentlyContinue
    $result = New-Object System.Collections.ArrayList
    foreach ($i in $items) {
        $fn = $i.FullName
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/].next[\\/]') { continue }
        $null = $result.Add(@{ path = $fn; rel = $rel })
    }
    return @($result.ToArray())
}

# ---------------------------------------------------------------------------
# 1. DOCKER-COMPOSE
# ---------------------------------------------------------------------------
$composeFiles = @(Get-ProjectFiles -Pattern "docker-compose.yml")
$composeFiles += @(Get-ProjectFiles -Pattern "docker-compose.yaml")
$composeFiles += @(Get-ProjectFiles -Pattern "compose.yml")
$composeFiles += @(Get-ProjectFiles -Pattern "compose.yaml")

foreach ($cf in $composeFiles) {
    $allFiles += $cf.rel
    $content = Get-Content -LiteralPath $cf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = $content -split "`n"
    $inServices = $false
    $serviceIndent = 0
    $currentService = $null
    $inPorts = $false; $inEnv = $false; $inVolumes = $false; $inDepends = $false
    $servicePorts = @(); $serviceEnvs = @(); $serviceVolumes = @(); $serviceDepends = @()

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        $trimmed = $ln.Trim()
        if ($trimmed -eq '' -or $trimmed -match '^#') { continue }

        # Calculate leading whitespace indent
        $indent = 0
        if ($ln -match '^(\s+)\S') { $indent = $matches[1].Length }

        # Detect "services:" top-level key
        if ($trimmed -eq 'services:') { $inServices = $true; $serviceIndent = 0; $currentService = $null; continue }

        # Exit services section when we hit a top-level key (indent 0)
        if ($inServices -and $indent -eq 0 -and $trimmed -match '^\w') {
            # Flush current service
            if ($currentService) {
                $services += @{ service = $currentService; ports = $servicePorts; envs = $serviceEnvs; volumes = $serviceVolumes; dependsOn = $serviceDepends }
            }
            $inServices = $false; $currentService = $null
            continue
        }

        if (-not $inServices) { continue }

        # Establish service indent from first indented key under services:
        if ($serviceIndent -eq 0 -and $indent -gt 0) {
            $serviceIndent = $indent
        }

        # Match lines that are just "key:" with no value
        if ($trimmed -match '^(\w[\w-]*):\s*$') {
            $key = $matches[1]

            if ($indent -eq $serviceIndent) {
                # Same indent as first service = service name
                if ($currentService) {
                    $services += @{ service = $currentService; ports = $servicePorts; envs = $serviceEnvs; volumes = $serviceVolumes; dependsOn = $serviceDepends }
                }
                $currentService = $key
                $servicePorts = @(); $serviceEnvs = @(); $serviceVolumes = @(); $serviceDepends = @()
                $inPorts = $false; $inEnv = $false; $inVolumes = $false; $inDepends = $false
                continue
            }

            if ($indent -gt $serviceIndent -and $currentService) {
                # Deeper indent = property subsection header
                $inPorts = $false; $inEnv = $false; $inVolumes = $false; $inDepends = $false
                switch ($key) {
                    'ports' { $inPorts = $true }
                    'environment' { $inEnv = $true }
                    'volumes' { $inVolumes = $true }
                    'depends_on' { $inDepends = $true }
                }
                continue
            }
        }

        if (-not $currentService) { continue }

        # Lines with values (key: value) reset subsection parsers
        if ($trimmed -match '^\w[\w-]*:\s+\S') {
            $inPorts = $false; $inEnv = $false; $inVolumes = $false; $inDepends = $false
            continue
        }

        # Port list items
        if ($inPorts -and $trimmed -match '^-\s*["'']?(\d+):(\d+)["'']?\s*$') {
            $servicePorts += "$($matches[1]):$($matches[2])"
            continue
        }
        if ($inPorts -and $trimmed -match '^-\s*["'']?(\d+)["'']?\s*$') {
            $servicePorts += $matches[1]
            continue
        }

        # Env list items (- KEY=VALUE or KEY=VALUE)
        if ($inEnv -and $trimmed -match '^-\s*(\w[\w_]*)\s*[=:]\s*(.+)\s*$') {
            $serviceEnvs += "$($matches[1])=$($matches[2])"
            continue
        }
        if ($inEnv -and $trimmed -match '^(\w[\w_]*)\s*[=:]\s*(.+)\s*$') {
            $serviceEnvs += "$($matches[1])=$($matches[2])"
            continue
        }

        # Volume list items
        if ($inVolumes -and $trimmed -match '^-\s*(.+)\s*$') {
            $serviceVolumes += $matches[1]
            continue
        }

        # Depends_on list items
        if ($inDepends -and $trimmed -match '^-\s*(\w[\w-]*)\s*$') {
            $serviceDepends += $matches[1]
            continue
        }
    }

    # Flush last service
    if ($currentService) {
        $services += @{ service = $currentService; ports = $servicePorts; envs = $serviceEnvs; volumes = $serviceVolumes; dependsOn = $serviceDepends }
    }
}

# ---------------------------------------------------------------------------
# 2. PACKAGE.JSON
# ---------------------------------------------------------------------------
$pkgFiles = @(Get-ProjectFiles -Pattern "package.json")
foreach ($pf in $pkgFiles) {
    $allFiles += $pf.rel
    try {
        $pkg = Get-Content -LiteralPath $pf.path -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($pkg.scripts) {
            $pkg.scripts.PSObject.Properties | ForEach-Object {
                $scripts[$_.Name] = $_.Value
            }
        }
    } catch {
        # skip malformed package.json
    }
}

# ---------------------------------------------------------------------------
# 3. CI CONFIG
# ---------------------------------------------------------------------------
# GitHub Actions
$ghFiles = @(Get-ProjectFiles -Pattern "*.yml") | Where-Object { $_.rel -match '\.github[\\/]workflows[\\/]' }
foreach ($gf in $ghFiles) {
    $allFiles += $gf.rel
    $content = Get-Content -LiteralPath $gf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = $content -split "`n"
    $triggers = @(); $jobs = @()
    $foundJobs = $false; $jobIndent = 0
    $currentJobName = $null; $currentJobSteps = @(); $currentJobNeeds = @()
    $parsingSteps = $false; $parsingNeeds = $false

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        $trimmed = $ln.Trim()
        $indent = if ($ln -match '^(\s+)\S') { $matches[1].Length } else { 0 }

        # Extract triggers (outside jobs:)
        if (-not $foundJobs -and $trimmed -match '^(push|pull_request|workflow_dispatch|schedule):') {
            $triggers += $matches[1]
            continue
        }

        # Find "jobs:" header
        if ($trimmed -eq 'jobs:' -and $indent -eq 0) {
            $foundJobs = $true; $jobIndent = 0
            continue
        }
        if (-not $foundJobs) { continue }

        # Detect end of jobs section (top-level key)
        if ($indent -eq 0 -and $trimmed -match '^\w') { break }

        # Set job indent from first indented key under jobs:
        if ($jobIndent -eq 0 -and $indent -gt 0) { $jobIndent = $indent }

        # Only keys at job indent level are job names
        if ($trimmed -match '^(\w[\w-]*):\s*$' -and $indent -eq $jobIndent) {
            if ($currentJobName) {
                $jobs += @{ name = $currentJobName; needs = $currentJobNeeds; steps = $currentJobSteps }
            }
            $currentJobName = $matches[1]; $currentJobSteps = @(); $currentJobNeeds = @()
            $parsingSteps = $false; $parsingNeeds = $false
            continue
        }

        if (-not $currentJobName) { continue }

        # Job-level properties (deeper indent than job name)
        if ($trimmed -match '^(\w[\w-]*):.*$') {
            $key = $matches[1]
            $parsingSteps = $false; $parsingNeeds = $false
            switch ($key) {
                'steps' { $parsingSteps = $true }
                'needs' { $parsingNeeds = $true; if ($trimmed -match 'needs:\s*\[(.+)\]') { $currentJobNeeds = $matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"''') }; $parsingNeeds = $false } }
            }
            continue
        }

        if ($parsingNeeds -and $trimmed -match '^-\s*(\w[\w-]*)') { $currentJobNeeds += $matches[1] }
        if ($parsingSteps -and $trimmed -match '^-\s+name:\s*(.+)\s*$') { $currentJobSteps += $matches[1] }
    }
    if ($currentJobName) {
        $jobs += @{ name = $currentJobName; needs = $currentJobNeeds; steps = $currentJobSteps }
    }

    $ci += @{
        type = "github-actions"
        file = $gf.rel
        triggers = $triggers
        jobs = $jobs
    }
}

# .gitlab-ci.yml
$glFiles = @(Get-ProjectFiles -Pattern ".gitlab-ci.yml")
$glFiles += @(Get-ProjectFiles -Pattern ".gitlab-ci.yaml")
foreach ($gf in $glFiles) {
    $allFiles += $gf.rel
    $content = Get-Content -LiteralPath $gf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $stages = @()
    $lines = $content -split "`n"
    $inStages = $false
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        if ($ln -match '^\s+stages:\s*$') { $inStages = $true; continue }
        if ($inStages -and $ln -match '^\s+-\s+(\w[\w-]*)') { $stages += $matches[1]; continue }
        if ($inStages -and $ln -match '^\s+\w') { $inStages = $false }
    }
    $ci += @{
        type = "gitlab-ci"
        file = $gf.rel
        stages = $stages
    }
}

# Jenkinsfile
$jkFiles = @(Get-ProjectFiles -Pattern "Jenkinsfile")
foreach ($jf in $jkFiles) {
    $allFiles += $jf.rel
    $content = Get-Content -LiteralPath $jf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $stages = @()
    $lines = $content -split "`n"
    for ($li = 0; $li -lt $lines.Count; $li++) {
        if ($lines[$li] -match "stage\s*\(\s*['""]([\w\s-]+)['""]") {
            $stages += $matches[1]
        }
    }
    $ci += @{
        type = "jenkins"
        file = $jf.rel
        stages = $stages
    }
}

# .circleci/config.yml
$ccFiles = @(Get-ProjectFiles -Pattern "config.yml") | Where-Object { $_.rel -match '\.circleci[\\/]' }
foreach ($cf in $ccFiles) {
    $allFiles += $cf.rel
    $content = Get-Content -LiteralPath $cf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $jobs = @()
    $lines = $content -split "`n"
    $inJobs = $false
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        if ($ln -match '^\s+jobs:\s*$') { $inJobs = $true; continue }
        if ($inJobs -and $ln -match '^\s+(\w[\w-]*):\s*$') { $jobs += $matches[1] }
        if ($inJobs -and $ln -match '^\s+workflows:') { break }
    }
    $ci += @{
        type = "circleci"
        file = $cf.rel
        jobs = $jobs
    }
}

# ---------------------------------------------------------------------------
# 4. DOCKERFILE
# ---------------------------------------------------------------------------
$dfFiles = @(Get-ProjectFiles -Pattern "Dockerfile")
$dfFiles += @(Get-ProjectFiles -Pattern "Dockerfile.*")
foreach ($df in $dfFiles) {
    $allFiles += $df.rel
    $content = Get-Content -LiteralPath $df.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = $content -split "`n"
    $baseImage = ""
    $exposePorts = @()
    $entrypoint = ""
    $cmd = ""
    $envVars = @{}
    $workdir = ""

    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li].Trim()
        if ($ln -match '^FROM\s+(\S+)') { $baseImage = $matches[1] }
        elseif ($ln -match '^EXPOSE\s+(\d+)') { $exposePorts += $matches[1] }
        elseif ($ln -match '^ENTRYPOINT\s+(\[.*\]|\S+)') { $entrypoint = $matches[1] }
        elseif ($ln -match '^CMD\s+(\[.*\]|\S+)') { $cmd = $matches[1] }
        elseif ($ln -match '^ENV\s+(\w[\w_]*)\s*=\s*(.+)') { $envVars[$matches[1]] = $matches[2] }
        elseif ($ln -match '^ENV\s+(\w[\w_]*)\s+(.+)') { $envVars[$matches[1]] = $matches[2] }
        elseif ($ln -match '^WORKDIR\s+(\S+)') { $workdir = $matches[1] }
    }

    $dockerInfo.baseImage = $baseImage
    $dockerInfo.ports = $exposePorts
    $dockerInfo.envs = @()
    $envVars.Keys | ForEach-Object { $dockerInfo.envs += "$_=$($envVars[$_])" }
    $dockerInfo.entrypoint = $entrypoint
    $dockerInfo.cmd = $cmd
    $dockerInfo.workdir = $workdir
}

# ---------------------------------------------------------------------------
# 5. HEALTHCHECK ENDPOINTS
# ---------------------------------------------------------------------------
$hcExtensions = @("*.ts", "*.tsx", "*.js", "*.jsx", "*.py", "*.go", "*.java", "*.rb", "*.cs")
foreach ($ext in $hcExtensions) {
    $srcFiles = @(Get-ProjectFiles -Pattern $ext)
    foreach ($sf in $srcFiles) {
        $content = Get-Content -LiteralPath $sf.path -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            # Express/Node: app.get('/health', ...) or router.get('/ready', ...)
            if ($ln -match '(?:app|router)\.(?:get|post|put|delete|all)\s*\(\s*["'']/(health|ready|ping|status)(?:["'']|/)') {
                $path = "/$($matches[1])"
                if ($healthcheckPaths -notcontains $path) { $healthcheckPaths += $path }
                $endpoints += @{ file = $sf.rel; line = $li + 1; path = $path }
            }
            # Flask: @app.route('/health')
            if ($ln -match '@app\.route\s*\(\s*["'']/(health|ready|ping|status)') {
                $path = "/$($matches[1])"
                if ($healthcheckPaths -notcontains $path) { $healthcheckPaths += $path }
                $endpoints += @{ file = $sf.rel; line = $li + 1; path = $path }
            }
            # FastAPI: @router.get('/health') or @app.get('/ready')
            if ($ln -match '@(?:app|router)\.(?:get|post|put|delete)\(["'']/(health|ready|ping|status)') {
                $path = "/$($matches[1])"
                if ($healthcheckPaths -notcontains $path) { $healthcheckPaths += $path }
                $endpoints += @{ file = $sf.rel; line = $li + 1; path = $path }
            }
            # Go: mux.HandleFunc("/health", ...)
            if ($ln -match 'Handle(?:Func)?\s*\(\s*["'']/(health|ready|ping|status)') {
                $path = "/$($matches[1])"
                if ($healthcheckPaths -notcontains $path) { $healthcheckPaths += $path }
                $endpoints += @{ file = $sf.rel; line = $li + 1; path = $path }
            }
            # Java Spring: @GetMapping("/health")
            if ($ln -match '@(GetMapping|RequestMapping)\s*\(\s*["'']/(health|ready|ping|status)') {
                $path = "/$($matches[2])"
                if ($healthcheckPaths -notcontains $path) { $healthcheckPaths += $path }
                $endpoints += @{ file = $sf.rel; line = $li + 1; path = $path }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 6. README COMMANDS
# ---------------------------------------------------------------------------
$readmeFiles = @(Get-ProjectFiles -Pattern "README*")
foreach ($rf in $readmeFiles) {
    $allFiles += $rf.rel
    $content = Get-Content -LiteralPath $rf.path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    # Extract shell code blocks (```bash, ```sh, ```shell, or ``` with shell cmd)
    $blocks = [regex]::Matches($content, '(?s)```(?:bash|sh|shell|powershell|ps1|cmd)?\s*\n(.+?)```')
    foreach ($b in $blocks) {
        $cmdText = $b.Groups[1].Value.Trim()
        if ($cmdText) {
            $readmeCommands += @{ file = $rf.rel; command = $cmdText }
        }
    }
    # Also extract single-line commands starting with $ or >
    $lines = $content -split "`n"
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $ln = $lines[$li]
        if ($ln -match '^\s*[\$>]\s*(.+)$') {
            $cmdText = $matches[1].Trim()
            if ($cmdText) {
                $readmeCommands += @{ file = $rf.rel; command = $cmdText }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
$uniqueFiles = $allFiles | Select-Object -Unique | Sort-Object

Write-Output "=== Runbook Scan Complete ==="
Write-Output "  Files scanned: $($uniqueFiles.Count)"
Write-Output "  Docker-compose services: $($services.Count)"
Write-Output "  NPM scripts: $($scripts.Count)"
Write-Output "  CI configs: $($ci.Count)"
Write-Output "  Dockerfile base image: $($dockerInfo.baseImage)"
Write-Output "  Healthcheck endpoints: $($healthcheckPaths.Count)"
Write-Output "  README commands extracted: $($readmeCommands.Count)"

$result = @{
    services = $services
    scripts = $scripts
    ci = $ci
    docker = $dockerInfo
    endpoints = $endpoints
    healthcheckPaths = $healthcheckPaths
    readmeCommands = $readmeCommands
    counts = @{
        scannedFiles = $uniqueFiles.Count
        services = $services.Count
        scripts = $scripts.Count
        ciConfigs = $ci.Count
        healthchecks = $healthcheckPaths.Count
        commands = $readmeCommands.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
