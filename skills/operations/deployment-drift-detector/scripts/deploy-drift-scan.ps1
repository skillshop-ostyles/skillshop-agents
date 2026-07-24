[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('yaml', 'yml', 'tf', 'tf.json', 'docker-compose.yml', 'Dockerfile'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$findings = New-Object System.Collections.Generic.List[object]
$counts = @{ declared = 0; deployed = 0; drift = 0 }

# Find manifest files
$manifestFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object {
        $ext = $_.Extension.TrimStart('.').ToLower()
        $name = $_.Name.ToLower()
        ($ext -in @('yaml', 'yml') -and $name -match 'deployment|service|configmap|statefulset|ingress') -or
        ($ext -eq 'tf') -or
        ($name -eq 'docker-compose.yml') -or
        ($name -eq 'dockerfile')
    }

foreach ($f in $manifestFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # Detect Kubernetes resources
    if ($relPath -match '\.ya?ml$' -and $content -match 'apiVersion:') {
        $kind = if ($content -match 'kind:\s*(\S+)') { $matches[1] } else { 'unknown' }
        $name = if ($content -match 'name:\s*(\S+)') { $matches[1] } else { $relPath }

        $replicas = if ($content -match 'replicas:\s*(\d+)') { [int]$matches[1] } else { $null }
        $image = if ($content -match 'image:\s*(\S+)') { $matches[1] } else { $null }
        $limits = if ($content -match 'limits:') { $true } else { $false }

        $counts['declared']++
        $findings.Add([ordered]@{
                resource   = "$kind/$name"
                kind       = $kind.ToLower()
                source     = 'declared'
                file       = $relPath
                properties = [ordered]@{
                    replicas = $replicas
                    image    = $image
                    hasLimits = $limits
                }
            })
    }

    # Detect Terraform resources
    if ($relPath -match '\.tf$') {
        $resourceBlocks = [regex]::Matches($content, 'resource\s+"(\w+)"\s+"(\w+)"')
        foreach ($m in $resourceBlocks) {
            $counts['declared']++
            $findings.Add([ordered]@{
                    resource   = "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
                    kind       = $m.Groups[1].Value
                    source     = 'declared'
                    file       = $relPath
                    properties = [ordered]@{}
                })
        }
    }
}

# Check for deployed state snapshots (kubectl get, terraform show output)
$deployedFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object { $_.Name -match '(?i)(kubectl|deployed|terraform-show|docker-inspect)' }

foreach ($f in $deployedFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $kind = if ($content -match 'kind:\s*(\S+)') { $matches[1] } else { 'unknown' }
    $name = if ($content -match 'name:\s*(\S+)') { $matches[1] } else { $relPath }
    $replicasActual = if ($content -match 'replicas:\s*(\d+)') { [int]$matches[1] } else { $null }

    $counts['deployed']++
    $findings.Add([ordered]@{
            resource   = "$kind/$name"
            kind       = $kind.ToLower()
            source     = 'deployed'
            file       = $relPath
            properties = [ordered]@{
                replicas = $replicasActual
            }
        })
}

# Detect drifts: compare declared vs deployed by resource name
$declaredIndex = @{}
$deployedIndex = @{}
foreach ($f in $findings) {
    if ($f.source -eq 'declared') { $declaredIndex[$f.resource] = $f }
    if ($f.source -eq 'deployed') { $deployedIndex[$f.resource] = $f }
}

$drifts = New-Object System.Collections.Generic.List[object]
foreach ($res in $declaredIndex.Keys) {
    $decl = $declaredIndex[$res]
    $dep = $deployedIndex[$res]
    if (-not $dep) {
        $counts['drift']++
        $drifts.Add([ordered]@{
                resource    = $res
                field       = 'exists'
                declared    = 'present'
                deployed    = 'missing'
                severity    = 'major'
                description = "Resource declared but no deployed state found"
            })
    }
    else {
        $dRep = $decl.properties.replicas
        $depRep = $dep.properties.replicas
        if ($null -ne $dRep -and $null -ne $depRep -and $dRep -ne $depRep) {
            $counts['drift']++
            $drifts.Add([ordered]@{
                    resource    = $res
                    field       = 'replicas'
                    declared    = $dRep
                    deployed    = $depRep
                    severity    = 'critical'
                    description = "Replica count mismatch: declared $dRep, deployed $depRep"
                })
        }
    }
}

$result = [ordered]@{
    findings    = $findings.ToArray()
    drifts      = $drifts.ToArray()
    counts      = $counts
    scannedDirs = @('manifests', 'deployed-state')
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== DEPLOY-DRIFT-SCAN ==="
Write-Output "  Declared resources: $($counts.declared)"
Write-Output "  Deployed snapshots: $($counts.deployed)"
Write-Output "  Drifts found: $($counts.drift)"
