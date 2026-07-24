[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', 'venv', '.venv')
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

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$embeddings = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; consistent = 0; suboptimal = 0; mismatched = 0; broken = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Detect chunking
    $chunkSize = $null
    $overlap = $null
    $hasChunking = $false
    $chunkLine = $null
    if ($content -match '(?i)chunk_size\s*[=:]\s*(\d+)') {
        $chunkSize = [int]$matches[1]
        $chunkLine = $relPath
        $hasChunking = $true
    }
    if ($content -match '(?i)chunk_overlap\s*[=:]\s*(\d+)') {
        $overlap = [int]$matches[1]
    }

    # Detect embedding models
    $models = @()
    $modelLine = $null
    $modelMatches = [regex]::Matches($content, '(?i)(text-embedding-\w+|sentence-transformers/\S+|OpenAIEmbeddings|CohereEmbeddings|HuggingFaceEmbeddings|SentenceTransformer)\s*(?:\(|\.)')
    foreach ($m in $modelMatches) {
        if ($m.Groups[1].Value -notin $models) {
            $models += $m.Groups[1].Value
        }
    }

    # Detect embed_query vs embed_documents (model parity)
    $hasEmbedQuery = $content -match '(?i)embed_query'
    $hasEmbedDocs = $content -match '(?i)embed_documents'
    $hasQueryDocParity = $true
    if ($hasEmbedQuery -xor $hasEmbedDocs) {
        $hasQueryDocParity = $false
    } elseif ($hasEmbedQuery -and $hasEmbedDocs -and $models.Count -gt 1) {
        $hasQueryDocParity = $false
    }

    # Detect vector store without chunking
    $hasVectorStore = $content -match '(?i)(from_documents|from_texts|similarity_search|Chroma|Pinecone|Weaviate|Qdrant|FAISS)'
    $hasOrderedChunking = $content -match '(?i)(TextSplitter|split_text|split_documents)'

    if ($models.Count -gt 0 -or $hasChunking -or $hasVectorStore) {
        $counts.total++

        $classification = 'consistent'
        if (-not $hasOrderedChunking -and $hasVectorStore) {
            $classification = 'broken'
            $counts.broken++
        } elseif (-not $hasQueryDocParity -and $hasEmbedQuery) {
            $classification = 'mismatched'
            $counts.mismatched++
        } elseif ($null -ne $chunkSize -and $chunkSize -lt 100 -and (-not $overlap -or $overlap -eq 0)) {
            $classification = 'broken'
            $counts.broken++
        } elseif ($null -eq $overlap -and $null -ne $chunkSize) {
            $classification = 'suboptimal'
            $counts.suboptimal++
        } else {
            $counts.consistent++
        }

        $embeddings.Add([ordered]@{
                file = $relPath
                line = if ($chunkLine) { 1 } else { 0 }
                model = if ($models.Count -gt 0) { $models -join ', ' } else { 'unknown' }
                chunkSize = $chunkSize
                overlap = $overlap
                hasOverlap = ($null -ne $overlap)
                embeddingType = if ($hasEmbedQuery -and $hasEmbedDocs) { 'both' } elseif ($hasEmbedQuery) { 'query' } elseif ($hasEmbedDocs) { 'document' } else { 'unknown' }
                hasQueryDocParity = $hasQueryDocParity
                hasChunking = $hasOrderedChunking
                classification = $classification
            })
    }
}

$result = [ordered]@{
    embeddings = $embeddings.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== EMBED-SCAN ==="
Write-Output "  Total embedding configs: $($counts.total)"
Write-Output "  Consistent: $($counts.consistent)"
Write-Output "  Suboptimal: $($counts.suboptimal)"
Write-Output "  Mismatched: $($counts.mismatched)"
Write-Output "  Broken: $($counts.broken)"
