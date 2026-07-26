[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('*.py', '*.ipynb'),

    [string[]]$Exclude = @()
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$SplitPatterns = @(
    'train_test_split',
    'TimeSeriesSplit',
    'GroupKFold',
    'GroupShuffleSplit',
    'StratifiedKFold'
)

$PreprocessPatterns = @(
    'StandardScaler',
    'MinMaxScaler',
    'OneHotEncoder',
    'PCA',
    'fit_transform',
    '\.fit\(',
    '\.transform\('
)

$DataLoadPatterns = @(
    'pd\.read_csv',
    'load_dataset',
    'pd\.DataFrame',
    'pd\.read_excel',
    'pd\.read_parquet'
)

$FeatureEnginePatterns = @(
    'np\.log',
    'np\.square',
    'np\.sqrt',
    'np\.exp',
    'np\.clip'
)

$GroupPatterns = @(
    'groupby',
    'group_id',
    'user_id',
    'customer_id',
    'session_id'
)

$TemporalPatterns = @(
    'TimeSeriesSplit',
    'date',
    'timestamp',
    'datetime',
    'shift\('
)

function Get-Files {
    param([string]$Dir)

    $files = Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue
    $result = @()
    foreach ($f in $files) {
        $include = $false
        foreach ($ext in $Extensions) {
            if ($f.Name -like $ext) { $include = $true; break }
        }
        if (-not $include) { continue }

        $excluded = $false
        foreach ($exc in $Exclude) {
            if ($f.FullName -like "*$exc*") { $excluded = $true; break }
        }
        if ($excluded) { continue }

        if ((Get-Content -LiteralPath $f.FullName -TotalCount 1 -ErrorAction SilentlyContinue) -match 'python|sklearn|pandas|numpy|#!') {
            $result += $f
        } elseif ((Get-Content -LiteralPath $f.FullName -TotalCount 20 -ErrorAction SilentlyContinue) -match 'import (pandas|numpy|sklearn|torch|tensorflow)') {
            $result += $f
        } else {
            $result += $f
        }
    }
    return $result
}

function Analyze-Pipeline {
    param([string]$FilePath)

    $content = Get-Content -LiteralPath $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $lines = $content -split "`r?`n"
    $pipelines = @()

    $pendingOps = @()
    $blockHasGroups = $false  # does the current block reference group/user/customer identifiers?

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $lineNum = $i + 1

        $trimmed = $line.Trim()
        $isComment = $trimmed -match '^#'
        $isImport = $trimmed -match '^(import |from )'
        $isEmpty = $trimmed -eq ''

        # blank line resets block context
        if ($isEmpty) {
            $pendingOps = @()
            $blockHasGroups = $false
            $i++
            continue
        }

        # skip comment-only lines (they don't add ops or split)
        if ($isComment) { $i++; continue }

        # track group identifiers in the block
        foreach ($gp in $GroupPatterns) {
            if ($line -match $gp) { $blockHasGroups = $true; break }
        }

        # skip import lines for split/ops detection
        if ($isImport) { $i++; continue }

        $matchedSplit = $null
        foreach ($sp in $SplitPatterns) {
            if ($line -match $sp) {
                $matchedSplit = $sp
                break
            }
        }

        if ($matchedSplit) {
            $hasPreprocessingBeforeSplit = $false
            $hasGroupLeakageRisk = $false
            $hasTemporalLeakageRisk = $false
            $usesGroupId = $false

            foreach ($op in $pendingOps) {
                if ($op.pattern -eq 'fit_transform' -or $op.pattern -eq '\.fit\(') {
                    $hasPreprocessingBeforeSplit = $true
                }
            }

            # group leakage: train_test_split without group param BUT only if block has group identifiers
            if ($blockHasGroups -and $matchedSplit -eq 'train_test_split' -and $line -notmatch '\bgroup\s*=') {
                $hasGroupLeakageRisk = $true
            }
            if ($line -match '\bgroup\s*=') {
                $usesGroupId = $true
                $hasGroupLeakageRisk = $false
            }

            if ($line -match 'GroupKFold|GroupShuffleSplit') {
                if ($line -notmatch '\.split\s*\(.*\b(group|groups)\s*=') {
                    $usesGroupId = $false
                } else {
                    $usesGroupId = $true
                }
            }

            if ($matchedSplit -eq 'TimeSeriesSplit') {
                $hasTemporalLeakageRisk = $true
            }

            if ($matchedSplit -eq 'train_test_split' -and $line -match 'shuffle\s*=\s*True') {
                if ($blockHasGroups -or $pendingOps | Where-Object { $_.pattern -match 'date|timestamp|datetime|time' }) {
                    $hasTemporalLeakageRisk = $true
                }
            }

            $classification = 'clean'
            if ($hasPreprocessingBeforeSplit) {
                $classification = 'leakage-risk'
            } elseif ($hasGroupLeakageRisk -and -not $usesGroupId) {
                $classification = 'group-leak'
            } elseif ($hasTemporalLeakageRisk -and -not $usesGroupId) {
                $classification = 'temporal-leak'
            }

            $pipelines += @{
                file = $FilePath
                line = $lineNum
                splitType = $matchedSplit
                operationsBeforeSplit = @($pendingOps)
                hasPreprocessingBeforeSplit = $hasPreprocessingBeforeSplit
                hasGroupLeakageRisk = $hasGroupLeakageRisk
                hasTemporalLeakageRisk = $hasTemporalLeakageRisk
                classification = $classification
                usesGroupId = $usesGroupId
            }

            $pendingOps = @()
            $blockHasGroups = $false
        } else {
            $found = $false
            foreach ($pp in $PreprocessPatterns) {
                if ($line -match $pp) {
                    $pendingOps += @{ type = 'preprocessing'; line = $lineNum; pattern = $pp }
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                foreach ($fe in $FeatureEnginePatterns) {
                    if ($line -match $fe) {
                        $pendingOps += @{ type = 'feature_engineering'; line = $lineNum; pattern = $fe }
                        $found = $true
                        break
                    }
                }
            }
            if (-not $found) {
                foreach ($dl in $DataLoadPatterns) {
                    if ($line -match $dl) {
                        $pendingOps += @{ type = 'data_loading'; line = $lineNum; pattern = $dl }
                        break
                    }
                }
            }
        }

        $i++
    }

    return $pipelines
}

$allFiles = Get-Files -Dir $ProjectDir
[System.Collections.ArrayList]$allPipelines = @()

foreach ($file in $allFiles) {
    $pipelines = Analyze-Pipeline -FilePath $file.FullName
    foreach ($p in $pipelines) {
        [void]$allPipelines.Add($p)
    }
}

$result = [ordered]@{ pipelines = $allPipelines }

$counts = @{ total = $allPipelines.Count; clean = 0; 'leakage-risk' = 0; 'group-leak' = 0; 'temporal-leak' = 0 }
foreach ($p in $allPipelines) {
    $class = $p.classification
    if ($counts.ContainsKey($class)) { $counts[$class]++ }
}

$result.counts = $counts

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== LEAK-SCAN ==="
Write-Output "  Pipelines found: $($allPipelines.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
