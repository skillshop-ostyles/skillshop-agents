[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

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
$manifestFiles = @()

# Find manifest files
$manifestPatterns = @('package.json', 'requirements.txt', 'Cargo.toml', 'go.mod', 'Gemfile', 'pom.xml', '*.csproj', '*.fsproj')
foreach ($pat in $manifestPatterns) {
    $manifestFiles += Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-ExcludedPath $_.FullName) } |
        Where-Object { $_.Name -like $pat }
}

$counts = @{ totalDeps = 0; manifests = 0 }

foreach ($f in $manifestFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $counts.manifests++

    $manifestType = switch -Wildcard ($f.Name) {
        'package.json' { 'npm' }
        'requirements.txt' { 'pip' }
        'Cargo.toml' { 'cargo' }
        'go.mod' { 'go' }
        'Gemfile' { 'bundler' }
        'pom.xml' { 'maven' }
        '*.csproj' { 'nuget' }
        default { 'unknown' }
    }

    # Parse based on manifest type
    switch ($manifestType) {
        'npm' {
            try {
                $json = $content | ConvertFrom-Json -ErrorAction SilentlyContinue
                $deps = @{}
                if ($json.dependencies) { foreach ($k in $json.dependencies.PSObject.Properties) { $deps[$k.Name] = @{ version = $k.Value; type = 'runtime' } } }
                if ($json.devDependencies) { foreach ($k in $json.devDependencies.PSObject.Properties) { $deps[$k.Name] = @{ version = $k.Value; type = 'dev' } } }
                foreach ($dn in $deps.Keys) {
                    $counts.totalDeps++
                    $findings.Add([ordered]@{
                            name          = $dn
                            version       = $deps[$dn].version
                            depType       = $deps[$dn].type
                            manifestType  = $manifestType
                            manifestFile  = $relPath
                            latestVersion = $null
                            lastPublish   = $null
                            cveCount      = $null
                            deprecated    = $null
                        })
                }
            }
            catch { }
        }
        'pip' {
            foreach ($line in ($content -split "`n")) {
                $line = $line.Trim()
                if ($line -and -not $line.StartsWith('#') -and -not $line.StartsWith('-')) {
                    $parts = $line -split '==|>=|<=|~=|!='
                    if ($parts.Count -ge 1 -and $parts[0].Trim()) {
                        $counts.totalDeps++
                        $findings.Add([ordered]@{
                                name          = $parts[0].Trim()
                                version       = if ($parts.Count -ge 2) { $parts[1].Trim() } else { '*' }
                                depType       = 'runtime'
                                manifestType  = $manifestType
                                manifestFile  = $relPath
                                latestVersion = $null
                                lastPublish   = $null
                                cveCount      = $null
                                deprecated    = $null
                            })
                    }
                }
            }
        }
        'go' {
            foreach ($line in ($content -split "`n")) {
                if ($line -match '^\s+(\S+)\s+(v?\S+)') {
                    $counts.totalDeps++
                    $findings.Add([ordered]@{
                            name          = $matches[1]
                            version       = $matches[2]
                            depType       = 'runtime'
                            manifestType  = $manifestType
                            manifestFile  = $relPath
                            latestVersion = $null
                            lastPublish   = $null
                            cveCount      = $null
                            deprecated    = $null
                        })
                }
            }
        }
        default {
            if ($content -match '(?i)(\w[\w.-]*)\s*[=~>]+\s*([\w.*-]+)') {
                $counts.totalDeps++
                $findings.Add([ordered]@{
                        name          = $matches[1]
                        version       = $matches[2]
                        depType       = 'unknown'
                        manifestType  = $manifestType
                        manifestFile  = $relPath
                        latestVersion = $null
                        lastPublish   = $null
                        cveCount      = $null
                        deprecated    = $null
                    })
            }
        }
    }
}

$result = [ordered]@{
    dependencies = $findings.ToArray()
    counts       = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== DEP-INVENTORY ==="
Write-Output "  Manifests found: $($counts.manifests)"
Write-Output "  Total dependencies: $($counts.totalDeps)"
