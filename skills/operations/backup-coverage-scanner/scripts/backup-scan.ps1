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

$resources = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; withBackup = 0; withoutBackup = 0 }

$files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $files) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # Detect docker-compose volumes
    if ($relPath -eq 'docker-compose.yml' -or $relPath -like 'docker-compose*.yml') {
        $volMatches = [regex]::Matches($content, '^\s+(\w[\w_-]*):\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($m in $volMatches) {
            $volName = $m.Groups[1].Value
            if ($volName -in @('services', 'networks', 'volumes', 'configs')) { continue }
            $hasBackup = $content -match [regex]::Escape($volName) -and ($content -match '(?i)dump|backup|snapshot|pg_dump|mysqldump')
            $counts.total++
            if ($hasBackup) { $counts.withBackup++ } else { $counts.withoutBackup++ }
            $resources.Add([ordered]@{
                    name        = $volName
                    type        = 'docker-volume'
                    declaredIn  = $relPath
                    hasBackup   = $hasBackup
                    criticality = 'medium'
                })
        }
    }

    # Detect terraform stateful resources
    if ($relPath -match '\.tf$') {
        $statefulTypes = @('aws_db_instance', 'aws_s3_bucket', 'aws_elasticache_cluster',
            'aws_dynamodb_table', 'aws_efs_file_system', 'aws_rds_cluster',
            'azurerm_storage_account', 'azurerm_mysql_server', 'azurerm_postgresql_server',
            'google_sql_database_instance', 'google_storage_bucket')
        foreach ($st in $statefulTypes) {
            $tmatch = [regex]::Matches($content, "resource\s+""$st""\s+""(\w+)""")
            foreach ($m in $tmatch) {
                $resName = "$st/$($m.Groups[1].Value)"
                $hasBackup = $content -match '(?i)(backup|snapshot|dump|replication|replica|read_replica|pitr|point_in_time)'
                $counts.total++
                if ($hasBackup) { $counts.withBackup++ } else { $counts.withoutBackup++ }
                $resources.Add([ordered]@{
                        name        = $resName
                        type        = $st
                        declaredIn  = $relPath
                        hasBackup   = $hasBackup
                        criticality = 'high'
                    })
            }
        }
    }

    # Detect k8s PVCs and StatefulSets
    if ($relPath -match '\.ya?ml$' -and $content -match '(?i)(apiVersion:|kind:)') {
        if ($content -match 'kind:\s*PersistentVolumeClaim') {
            $pvcName = if ($content -match 'name:\s*(\S+)') { $matches[1] } else { Split-Path $relPath -Leaf }
            $counts.total++
            $counts.withoutBackup++
            $resources.Add([ordered]@{
                    name        = $pvcName
                    type        = 'persistent-volume-claim'
                    declaredIn  = $relPath
                    hasBackup   = $false
                    criticality = 'high'
                })
        }
        if ($content -match 'kind:\s*StatefulSet') {
            $stsName = if ($content -match 'name:\s*(\S+)') { $matches[1] } else { Split-Path $relPath -Leaf }
            $counts.total++
            $counts.withoutBackup++
            $resources.Add([ordered]@{
                    name        = $stsName
                    type        = 'statefulset'
                    declaredIn  = $relPath
                    hasBackup   = $false
                    criticality = 'high'
                })
        }
    }

    # Detect DB connection strings
    if ($content -match '(?i)(postgres(ql)?|mysql|mongodb|redis)://\S+') {
        $dbName = if ($content -match '(?i)(db|database)\s*[=:]\s*[''"]?(\w+)') { $matches[2] } else { 'unknown-db' }
        $hasBackup = $content -match '(?i)(backup|dump|pg_dump|mysqldump|mongodump|snapshot)'
        $counts.total++
        if ($hasBackup) { $counts.withBackup++ } else { $counts.withoutBackup++ }
        $resources.Add([ordered]@{
                name        = $dbName
                type        = 'database-connection'
                declaredIn  = $relPath
                hasBackup   = $hasBackup
                criticality = 'high'
            })
    }
}

$result = [ordered]@{
    resources  = $resources.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== BACKUP-SCAN ==="
Write-Output "  Total stateful resources: $($counts.total)"
Write-Output "  With backup: $($counts.withBackup)"
Write-Output "  Without backup: $($counts.withoutBackup)"
