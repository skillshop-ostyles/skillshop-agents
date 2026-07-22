[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Names,

    [ValidateSet('npm', 'pypi')]
    [string]$Ecosystem = 'npm',

    [int]$TimeoutSec = 10
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-NpmMeta($name) {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        try {
            $raw = & npm view $name time.modified maintainers license --json 2>$null
            if ($LASTEXITCODE -eq 0 -and $raw) {
                $json = ($raw -join "`n") | ConvertFrom-Json
                $maintainerCount = if ($json.maintainers) { @($json.maintainers).Count } else { 0 }
                return @{
                    meta      = [ordered]@{
                        lastRelease     = $json.'time.modified'
                        maintainerCount = $maintainerCount
                        license         = $json.license
                    }
                    metaError = $null
                }
            }
        } catch {
            # faellt durch zum REST-Fallback
        }
    }
    try {
        $resp = Invoke-RestMethod -Uri "https://registry.npmjs.org/$name" -TimeoutSec $TimeoutSec -ErrorAction Stop
        $latest = $resp.'dist-tags'.latest
        $lastRelease = if ($resp.time -and $latest -and $resp.time.$latest) { $resp.time.$latest } else { $null }
        $maintainerCount = if ($resp.maintainers) { @($resp.maintainers).Count } else { 0 }
        $license = if ($resp.versions -and $latest -and $resp.versions.$latest) { $resp.versions.$latest.license } else { $null }
        return @{
            meta      = [ordered]@{ lastRelease = $lastRelease; maintainerCount = $maintainerCount; license = $license }
            metaError = $null
        }
    } catch {
        return @{ meta = $null; metaError = "npm-Registry nicht erreichbar oder Paket unbekannt: $($_.Exception.Message)" }
    }
}

function Get-PypiMeta($name) {
    try {
        $resp = Invoke-RestMethod -Uri "https://pypi.org/pypi/$name/json" -TimeoutSec $TimeoutSec -ErrorAction Stop
        $info = $resp.info
        $lastRelease = $null
        if ($resp.releases -and $info.version -and $resp.releases.($info.version)) {
            $files = @($resp.releases.($info.version))
            if ($files.Count -gt 0) {
                $lastRelease = ($files | Sort-Object upload_time -Descending | Select-Object -First 1).upload_time
            }
        }
        return @{
            meta      = [ordered]@{ lastRelease = $lastRelease; maintainerCount = $null; license = $info.license }
            metaError = $null
        }
    } catch {
        return @{ meta = $null; metaError = "PyPI nicht erreichbar oder Paket unbekannt: $($_.Exception.Message)" }
    }
}

# JEDER Fehler (offline, 404, Timeout) -> meta: null + metaError, niemals Abbruch
# (Offline-Fallback ist Pflicht laut Sprint-File).
$results = @(
    foreach ($name in $Names) {
        $r = if ($Ecosystem -eq 'pypi') { Get-PypiMeta $name } else { Get-NpmMeta $name }
        [ordered]@{ name = $name; meta = $r.meta; metaError = $r.metaError }
    }
)

$output = [ordered]@{ ecosystem = $Ecosystem; results = $results }
Write-Output (ConvertTo-Json $output -Depth 6)

Write-Output "`n=== REGISTRY-META ==="
foreach ($r in $results) {
    if ($r.meta) {
        Write-Output "  $($r.name): letztes Release $($r.meta.lastRelease), Lizenz $($r.meta.license)"
    } else {
        Write-Output "  $($r.name): keine Metadaten ($($r.metaError))"
    }
}
