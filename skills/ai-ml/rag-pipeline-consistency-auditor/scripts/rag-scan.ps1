[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__')
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
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-Excluded($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

# Known embedding dimensions
$embeddingDims = @{
    'text-embedding-3-small' = 1536; 'text-embedding-3-large' = 3072; 'text-embedding-ada-002' = 1536
    'all-MiniLM-L6-v2' = 384; 'all-mpnet-base-v2' = 768; 'cohere-embed-english-v3' = 1024
    'cohere-embed-multilingual-v3' = 1024; 'BAAI/bge-small-en' = 384; 'BAAI/bge-base-en' = 768
    'BAAI/bge-large-en' = 1024; 'intfloat/e5-small' = 384; 'intfloat/e5-base' = 768
    'intfloat/e5-large' = 1024; 'sentence-transformers/all-MiniLM-L6-v2' = 384
    'sentence-transformers/all-mpnet-base-v2' = 768
}

$knownContextWindows = @{
    'gpt-4o' = 128000; 'gpt-4' = 8192; 'gpt-4-turbo' = 128000; 'gpt-3.5-turbo' = 16385
    'claude-3' = 200000; 'claude-3.5' = 200000; 'gemini-pro' = 32768; 'gemini-1.5' = 1048576
    'llama-3' = 8192; 'mistral' = 32768; 'mixtral' = 32768
}

$ragConfigs = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Detect embedding model
    $embedModel = $null
    foreach ($kv in $embeddingDims.GetEnumerator()) {
        if ($content -match [regex]::Escape($kv.Key)) { $embedModel = $kv.Key; break }
    }
    if (-not $embedModel) {
        if ($content -match '(?i)embedding_model\s*[:=]\s*["]([^"]+)["]') {
            $embedModel = $matches[1]
        } elseif ($content -match "(?i)embedding_model\s*[:=]\s*'([^']+)'") {
            $embedModel = $matches[1]
        }
    }

    # Detect LLM model
    $llmModel = $null
    foreach ($kv in $knownContextWindows.GetEnumerator()) {
        if ($content -match [regex]::Escape($kv.Key)) { $llmModel = $kv.Key; break }
    }
    if (-not $llmModel) {
        if ($content -match '(?i)(llm|model|chat_model)\s*[:=].*?["]([^"]+)["]') {
            $llmModel = $matches[2]
        } elseif ($content -match "(?i)(llm|model|chat_model)\s*[:=].*?'([^']+)'") {
            $llmModel = $matches[2]
        }
    }

    # Detect chunking config
    $chunkSize = $null
    $csMatch = [regex]::Match($content, '(?i)chunk_size\s*[=:]\s*(\d+)')
    if ($csMatch.Success) { $chunkSize = [int]$csMatch.Groups[1].Value }

    $chunkOverlap = $null
    $coMatch = [regex]::Match($content, '(?i)chunk_overlap\s*[=:]\s*(\d+)')
    if ($coMatch.Success) { $chunkOverlap = [int]$coMatch.Groups[1].Value }

    # Detect top K
    $topK = $null
    $tkMatch = [regex]::Match($content, '(?i)(?:top_k|similarity_top_k|k)\s*["'']?\s*[=:]\s*["'']?(\d+)')
    if ($tkMatch.Success) { $topK = [int]$tkMatch.Groups[1].Value }

    # Detect vector store dimensions
    $vectorDim = $null
    $vdMatch = [regex]::Match($content, '(?i)(dimension|dim|vector_size)\s*[=:]\s*(\d+)')
    if ($vdMatch.Success) { $vectorDim = [int]$vdMatch.Groups[2].Value }

    # Compute RAG config if we have enough signals
    if ($embedModel -or $chunkSize -or $topK -or $vectorDim) {
        $embedDim = if ($embedModel -and $embeddingDims.ContainsKey($embedModel)) { $embeddingDims[$embedModel] } else { $null }
        $contextWindow = $null
        if ($llmModel) {
            foreach ($kv in $knownContextWindows.GetEnumerator()) {
                if ($llmModel -match [regex]::Escape($kv.Key)) { $contextWindow = $kv.Value; break }
            }
        }

        # Compute overflow risk
        $retrievedTokens = if ($chunkSize -and $topK) { $chunkSize * $topK } else { $null }
        $hasWindowOverflow = $null -ne $retrievedTokens -and $null -ne $contextWindow -and $retrievedTokens -gt $contextWindow
        $hasDimensionMismatch = $null -ne $embedDim -and $null -ne $vectorDim -and $embedDim -ne $vectorDim

        $classification = 'consistent'
        if ($hasWindowOverflow -or $hasDimensionMismatch) { $classification = 'overflow-risk' }
        if ($hasDimensionMismatch) { $classification = 'mismatch' }

        $ragConfigs.Add([ordered]@{
                file = $relPath
                line = 1
                embeddingModel = $embedModel
                llmModel = $llmModel
                chunkSize = $chunkSize
                chunkOverlap = $chunkOverlap
                topK = $topK
                embeddingDimension = $embedDim
                vectorDimension = $vectorDim
                estimatedRetrievedTokens = $retrievedTokens
                contextWindow = $contextWindow
                hasWindowOverflow = $hasWindowOverflow
                hasDimensionMismatch = $hasDimensionMismatch
                classification = $classification
            })
    }
}

$counts = @{ total = $ragConfigs.Count; consistent = 0; 'overflow-risk' = 0; mismatch = 0 }
foreach ($c in $ragConfigs) {
    if ($counts.ContainsKey($c.classification)) { $counts[$c.classification]++ }
}

$result = [ordered]@{
    ragConfigs = $ragConfigs.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== RAG-SCAN ==="
Write-Output "  RAG configs found: $($ragConfigs.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
