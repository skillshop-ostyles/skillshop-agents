[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Exclude = "node_modules,.git,dist,build,vendor"
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

$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

# -- Check registry --
$checks = @(
    @{ id = 'tag-pinning'; severity = 'high'; description = 'FROM without pinned version tag' }
    @{ id = 'root-user'; severity = 'high'; description = 'No USER directive (runs as root)' }
    @{ id = 'apt-update-without-install'; severity = 'high'; description = 'apt-get update without apt-get install in same RUN' }
    @{ id = 'apt-no-recommends'; severity = 'medium'; description = 'apt-get install without --no-install-recommends' }
    @{ id = 'apt-cache-cleanup'; severity = 'medium'; description = 'apt cache not cleaned after install (no rm -rf /var/lib/apt/lists/*)' }
    @{ id = 'pip-no-cache'; severity = 'medium'; description = 'pip install without --no-cache-dir' }
    @{ id = 'npm-no-production'; severity = 'medium'; description = 'npm install without --production or --omit=dev' }
    @{ id = 'cmd-shell-form'; severity = 'medium'; description = 'CMD/ENTRYPOINT in shell form (should be exec form)' }
    @{ id = 'healthcheck-missing'; severity = 'low'; description = 'No HEALTHCHECK instruction' }
    @{ id = 'expose-missing'; severity = 'low'; description = 'No EXPOSE instruction' }
    @{ id = 'workdir-before-copy'; severity = 'low'; description = 'COPY without preceding WORKDIR' }
    @{ id = 'copy-entire-context'; severity = 'medium'; description = 'COPY . to image (whole context without .dockerignore)' }
    @{ id = 'add-vs-copy'; severity = 'low'; description = 'ADD used where COPY suffices (non-remote ADD)' }
    @{ id = 'high-layer-count'; severity = 'low'; description = 'More than 15 RUN/COPY/ADD instructions' }
    @{ id = 'labels-missing'; severity = 'low'; description = 'No LABEL metadata (maintainer/version/description)' }
    @{ id = 'hardcoded-secret'; severity = 'high'; description = 'ENV or ARG with potential secret value' }
    @{ id = 'multi-stage-potential'; severity = 'low'; description = 'Single FROM for compiled language suggests multi-stage' }
    @{ id = 'shell-form-run'; severity = 'low'; description = 'RUN in shell form without --exec flag' }
)

function Get-Dockerfiles {
    param([string]$Dir)
    $files = @()
    $found = Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -eq 'Dockerfile' -or $_.Name -like 'Dockerfile.*'
    }
    foreach ($f in $found) {
        $skip = $false
        $rel = $f.FullName.Substring($Dir.Length).TrimStart('\')
        foreach ($ex in $excludeList) {
            if ($rel -like "*\$ex\*" -or $rel -like "*\$ex") { $skip = $true; break }
        }
        if (-not $skip) { $files += $f }
    }
    return $files
}

function Get-InstructionLines {
    param([string[]]$Lines)
    $result = @()
    $current = $null
    $currentNum = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $trimmed = $Lines[$i]
        if ($trimmed -match '^\s*#') { continue }
        if ($trimmed -match '^\s*$') { continue }
        if ($trimmed -match '^\s+') {
            if ($current) { $current += "`n" + $trimmed.Trim() }
        } else {
            if ($current) { $result += @{ line = $currentNum; text = $current; index = $i - 1 } }
            $current = $trimmed.Trim()
            $currentNum = $i + 1
        }
    }
    if ($current) { $result += @{ line = $currentNum; text = $current; index = $Lines.Count - 1 } }
    return $result
}

function Test-InSameRun {
    param([string]$Text, [string]$Pattern1, [string]$Pattern2)
    $runBlocks = $Text -split '(?i)\bRUN\b'
    foreach ($block in $runBlocks) {
        if ($block -match $Pattern1 -and $block -notmatch $Pattern2) { return $true }
    }
    return $false
}

$allFindings = @()
$fileResults = @()
$findingId = 0

$dockerfiles = Get-Dockerfiles -Dir $ProjectDir

foreach ($df in $dockerfiles) {
    $rel = $df.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $df.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }
    $lines = $content -split "`n"
    $instructions = Get-InstructionLines -Lines $lines
    $fileFindings = @()
    $hasUser = $false
    $hasHealthcheck = $false
    $hasExpose = $false
    $hasLabels = $false
    $hasWorkdir = $false
    $aptCacheChecked = $false
    $fromCount = 0
    $fromList = @()
    $layerCount = 0
    $compiledLang = $false

    foreach ($inst in $instructions) {
        $t = $inst.text

        # Check 1: Tag pinning
        if ($t -match '(?i)^FROM\s+(\S+)') {
            $fromCount++
            $fromImg = $matches[1]
            $fromList += $fromImg
            if ($fromImg -notmatch ':' -and $fromImg -notmatch '@') {
                $fileFindings += @{
                    id = $findingId; check = 'tag-pinning'; severity = 'high'
                    line = $inst.line; detail = "FROM $fromImg without pinned version tag"
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = "Use FROM $fromImg:tag@sha256:... to pin version and digest"
                }
                $findingId++
            } elseif ($fromImg -match ':latest') {
                $fileFindings += @{
                    id = $findingId; check = 'tag-pinning'; severity = 'high'
                    line = $inst.line; detail = "FROM $fromImg uses ':latest' tag"
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = "Replace 'latest' with a specific version tag and digest"
                }
                $findingId++
            }
            # Detect compiled language base images for multi-stage check
            if ($fromImg -match '(?i)golang|rust|openjdk|maven|gradle|dotnet|mono') { $compiledLang = $true }
        }

        # Check 2: Root user
        if ($t -match '(?i)^USER\s+(\S+)') { $hasUser = $true }

        # Check 3: apt-get update without install in same RUN
        if ($t -match '(?i)RUN.*apt-get update') {
            $runText = $t
            if ($runText -match '(?i)apt-get update' -and $runText -notmatch '(?i)apt-get install') {
                $fileFindings += @{
                    id = $findingId; check = 'apt-update-without-install'; severity = 'high'
                    line = $inst.line; detail = 'apt-get update without apt-get install in same RUN (layers cache stale)'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Combine apt-get update && apt-get install in the same RUN layer'
                }
                $findingId++
            }
        }

        # Check 4: apt-get install without --no-install-recommends
        if ($t -match '(?i)RUN.*apt-get install') {
            if ($t -notmatch '(?i)--no-install-recommends') {
                $fileFindings += @{
                    id = $findingId; check = 'apt-no-recommends'; severity = 'medium'
                    line = $inst.line; detail = 'apt-get install without --no-install-recommends (unnecessary packages)'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Add --no-install-recommends flag to apt-get install'
                }
                $findingId++
            }
        }

        # Check 5: apt cache cleanup (only once per Dockerfile)
        if ($t -match '(?i)RUN.*apt-get' -and -not $aptCacheChecked) {
            if ($t -notmatch '(?i)rm\s+-rf\s+/var/lib/apt/lists') {
                $fileFindings += @{
                    id = $findingId; check = 'apt-cache-cleanup'; severity = 'medium'
                    line = $inst.line; detail = 'apt cache not cleaned after install'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Add && rm -rf /var/lib/apt/lists/* to the same RUN layer'
                }
                $findingId++
            }
            $aptCacheChecked = $true
        }

        # Check 6: pip install without --no-cache-dir
        if ($t -match '(?i)pip install') {
            if ($t -notmatch '(?i)--no-cache-dir') {
                $fileFindings += @{
                    id = $findingId; check = 'pip-no-cache'; severity = 'medium'
                    line = $inst.line; detail = 'pip install without --no-cache-dir (unnecessary cache layers)'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Add --no-cache-dir flag to pip install'
                }
                $findingId++
            }
        }

        # Check 7: npm install without --production
        if ($t -match '(?i)RUN.*npm install') {
            if ($t -notmatch '(?i)--production|--omit=dev') {
                $fileFindings += @{
                    id = $findingId; check = 'npm-no-production'; severity = 'medium'
                    line = $inst.line; detail = 'npm install without --production or --omit=dev (devDependencies in image)'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Add --omit=dev flag (npm 8+) or use npm ci --production'
                }
                $findingId++
            }
        }

        # Check 8: CMD or ENTRYPOINT in shell form
        if ($t -match '(?i)^(CMD|ENTRYPOINT)\s+(\S)') {
            $delim = $matches[2]
            if ($delim -ne '[') {
                $cmdType = $matches[1]
                $fileFindings += @{
                    id = $findingId; check = 'cmd-shell-form'; severity = 'medium'
                    line = $inst.line; detail = "$cmdType in shell form (use exec form with JSON array)"
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Use exec form: ' + $cmdType + ' ["exec","arg1"]'
                }
                $findingId++
            }
        }

        # Check 9: HEALTHCHECK
        if ($t -match '(?i)^HEALTHCHECK') { $hasHealthcheck = $true }

        # Check 10: EXPOSE
        if ($t -match '(?i)^EXPOSE') { $hasExpose = $true }

        # Check 11: WORKDIR before COPY
        if ($t -match '(?i)^WORKDIR\s+(\S+)') { $hasWorkdir = $true }
        if ($t -match '(?i)^COPY') {
            if (-not $hasWorkdir -and $t -notmatch '\s--from=') {
                $fileFindings += @{
                    id = $findingId; check = 'workdir-before-copy'; severity = 'low'
                    line = $inst.line; detail = 'COPY without preceding WORKDIR (absolute path assumed)'
                    lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                    remediation = 'Add WORKDIR before COPY to use relative paths'
                }
                $findingId++
            }
        }

        # Check 12: COPY entire context
        if ($t -match '(?i)^COPY\s+\.\s') {
            $fileFindings += @{
                id = $findingId; check = 'copy-entire-context'; severity = 'medium'
                line = $inst.line; detail = 'COPY . copies entire build context (consider .dockerignore)'
                lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                remediation = 'Ensure .dockerignore exists and only copy what is needed'
            }
            $findingId++
        }

        # Check 13: ADD vs COPY (ADD used for non-remote)
        if ($t -match '(?i)^ADD\s+\S+\s+\S+' -and $t -notmatch 'https?://|http://') {
            $fileFindings += @{
                id = $findingId; check = 'add-vs-copy'; severity = 'low'
                line = $inst.line; detail = 'ADD used where COPY suffices (ADD has extra features like tar extraction)'
                lineContent = $t.Substring(0, [Math]::Min(120, $t.Length))
                remediation = 'Replace ADD with COPY for local file copying'
            }
            $findingId++
        }

        # Check 16: hardcoded secret
        if ($t -match '(?i)^(ENV|ARG)\s+(\w+)\s*=\s*["'']?(.+?)["'']?\s*$') {
            $varName = $matches[2]
            $varValue = $matches[3]
            if ($varName -match '(?i)(password|secret|token|key|credential|apikey|api_key|auth|jwt|private)') {
                $fileFindings += @{
                    id = $findingId; check = 'hardcoded-secret'; severity = 'high'
                    line = $inst.line; detail = "ENV/ARG $varName may contain secret value"
                    lineContent = $t.Substring(0, [Math]::Min(80, $t.Length))
                    remediation = "Use build --secret or Docker Compose secrets instead of ENV/ARG for secrets"
                }
                $findingId++
            }
        }

        # Track layer count
        if ($t -match '(?i)^(RUN|COPY|ADD)') { $layerCount++ }
    }

    # Check 9 (post-loop): HEALTHCHECK missing
    if (-not $hasHealthcheck -and $fromCount -gt 0) {
        $fileFindings += @{
            id = $findingId; check = 'healthcheck-missing'; severity = 'low'
            line = 0; detail = 'No HEALTHCHECK instruction found'
            lineContent = ''; remediation = 'Add HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost/ || exit 1'
        }
        $findingId++
    }

    # Check 10 (post-loop): EXPOSE missing (only if it looks like a server image)
    if (-not $hasExpose -and $fromCount -gt 0) {
        $fileFindings += @{
            id = $findingId; check = 'expose-missing'; severity = 'low'
            line = 0; detail = 'No EXPOSE instruction found'
            lineContent = ''; remediation = 'Add EXPOSE <port> to document the container port'
        }
        $findingId++
    }

    # Check 15: LABELs missing
    if (-not (($instructions | ForEach-Object { $_.text }) -match '(?i)^LABEL')) {
        if ($fromCount -gt 0) {
            $fileFindings += @{
                id = $findingId; check = 'labels-missing'; severity = 'low'
                line = 0; detail = 'No LABEL metadata found (maintainer, version, description)'
                lineContent = ''; remediation = 'Add LABEL maintainer="..." version="..." description="..."'
            }
            $findingId++
        }
    }

    # Check 2 (post-loop): root user
    if (-not $hasUser -and $fromCount -gt 0) {
        $fileFindings += @{
            id = $findingId; check = 'root-user'; severity = 'high'
            line = 0; detail = 'No USER directive found (container runs as root)'
            lineContent = ''; remediation = 'Add USER 1000 or create a non-root user with adduser'
        }
        $findingId++
    }

    # Check 14: high layer count
    if ($layerCount -gt 15) {
        $fileFindings += @{
            id = $findingId; check = 'high-layer-count'; severity = 'low'
            line = 0; detail = "$layerCount RUN/COPY/ADD instructions (excessive layers)"
            lineContent = ''; remediation = 'Combine related RUN commands with && and use multi-stage builds'
        }
        $findingId++
    }

    # Check 17: multi-stage potential
    if ($fromCount -eq 1 -and $compiledLang) {
        $fileFindings += @{
            id = $findingId; check = 'multi-stage-potential'; severity = 'low'
            line = 0; detail = 'Single FROM for compiled language (multi-stage could reduce image size)'
            lineContent = ''; remediation = 'Use multi-stage build: build stage + runtime stage'
        }
        $findingId++
    }

    # Check 18: RUN shell form
    foreach ($inst in $instructions) {
        if ($inst.text -match '(?i)^RUN\s+' -and $inst.text -notmatch '\s\[\s*"') {
            # Skip - mostly covered by other checks
        }
    }

    # Attach file field to all findings
    for ($i = 0; $i -lt $fileFindings.Count; $i++) {
        $ff = $fileFindings[$i]
        $fileFindings[$i] = @{} + $ff + @{ file = $rel }
    }

    $allFindings += $fileFindings
    $fileResults += @{
        file = $rel
        fromImages = $fromList
        layerCount = $layerCount
        findingCount = $fileFindings.Count
    }
}

# -- Stats --
$bySeverity = @{ high = 0; medium = 0; low = 0 }
$byCheck = @{}
foreach ($f in $allFindings) {
    $bySeverity[$f.severity]++
    if (-not $byCheck.ContainsKey($f.check)) { $byCheck[$f.check] = 0 }
    $byCheck[$f.check]++
}

$stats = @{
    totalDockerfiles = $dockerfiles.Count
    totalFindings = $allFindings.Count
    high = $bySeverity.high
    medium = $bySeverity.medium
    low = $bySeverity.low
    byCheck = $byCheck
}

$output = @{
    findings = $allFindings
    files = $fileResults
    stats = $stats
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

# Console summary
Write-Output "=== Dockerfile Best Practices Scan Complete ==="
Write-Output "  Dockerfiles found: $($dockerfiles.Count)"
foreach ($f in $fileResults) {
    Write-Output "  - $($f.file) ($($f.findingCount) findings, $($f.layerCount) layers)"
}
Write-Output "  Total findings: $($allFindings.Count)"
Write-Output "    high: $($bySeverity.high) | medium: $($bySeverity.medium) | low: $($bySeverity.low)"
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps"
