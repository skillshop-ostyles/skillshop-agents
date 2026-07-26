[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.ps1",
    [string]$Exclude = "",
    [int]$ContextLines = 30
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

$claimKeywords = @(
    'returns','return','throws','throw','yields','always','never','must','guarantees',
    'guarantee','thread-safe','side-effect','side-effect-free','expect','expects',
    'assumes','dependent','depends on','requires','invariant','not','callback',
    'deprecated','TODO','FIXME','XXX','HACK','BUG','waiver','unsafe','safe'
)

$comments = @()
$scannedFiles = 0

# Strip block comments token by token to handle multi-line and language variants.
# Languages covered: ts/js/jsx/tsx (//, /* */), py (#, docstring), cs (//, /* */), go (//, /* */),
# java (//, /* */, /** */), rb (#), php (//, #, /* */), ps1 (#, <# #>).

function Strip-Comments($text, $ext) {
    # Returns array of {line, text} where text is one comment.
    $items = @()
    $lines = $text -split "`r`n|`n"
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $trim = $line.TrimStart()

        # Hash comments (Python, Ruby, PHP, PS1): single-line # and block <# #>.
        if ($ext -in '.py','.rb','*.ps1' -or $ext -eq '.php') {
            if ($ext -eq '.ps1' -and $trim.StartsWith('<#')) {
                $concat = $trim.Substring(2)
                while ($i -lt $lines.Count -and -not $concat.Contains('#>')) {
                    $i++
                    if ($i -lt $lines.Count) { $concat += "`n" + $lines[$i] }
                }
                $block = $concat.Substring(0, $concat.IndexOf('#>')).Trim()
                if ($block) { $items += @{ line = ($i - (($concat -split "`n").Count) + 2); text = $block } }
                $i++; continue
            }
            $idx = $trim.IndexOf('#')
            if ($idx -ge 0) {
                $items += @{ line = ($i + 1); text = $trim.Substring($idx + 1).Trim() }
            }
        }

        # C/Java/JS/TS/Go family.
        if ($ext -in '.ts','.tsx','.js','.jsx','.cs','.go','.java','.php') {
            $trim2 = $trim.TrimStart()
            # Single-line //
            $idx = $trim2.IndexOf('//')
            if ($idx -ge 0 -and ($idx -eq 0 -or $trim2[($idx-1)] -ne ':')) {
                # locate the // outside any string literal (rough heuristic: no // inside quotes)
                if (-not ($trim2.Substring(0,$idx) -match "['`"]")) {
                    $items += @{ line = ($i + 1); text = $trim2.Substring($idx + 2).Trim() }
                }
            }
            # Block /* */
            $trim3 = $trim.TrimStart()
            if ($trim3.StartsWith('/*')) {
                $end = $trim3.IndexOf('*/')
                $blockText = ''
                if ($end -ge 0) {
                    $blockText = $trim3.Substring(2, $end - 2).Trim()
                } else {
                    $concat = $trim3.Substring(2)
                    $startIdx = $i
                    while ($i -lt $lines.Count -and -not $concat.Contains('*/')) {
                        $i++
                        if ($i -lt $lines.Count) { $concat += "`n" + $lines[$i] }
                    }
                    $blockText = $concat.Substring(0, $concat.IndexOf('*/')).Trim()
                    $end = $concat.IndexOf('*/')
                }
                if ($blockText) {
                    $items += @{ line = ($i + 1); text = ($blockText -replace "`n", ' ').Trim() }
                }
                if ($end -lt 0) { $i++ }
                continue
            }
        }
        $i++
    }
    return ,$items
}

function Classify-ClaimType($commentText) {
    $t = $commentText.ToLower()
    foreach ($k in $claimKeywords) {
        if ($t -match [regex]::Escape($k)) { return 'behavioral-claim' }
    }
    if ($t -match '^@') { return 'doc-tag' }
    if ($t -match '^\s*\*') { return 'doc-block' }
    return 'opinion'
}

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $ext2 = [System.IO.Path]::GetExtension($fp).ToLower()
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`r`n|`n"
        $exts = Strip-Comments $content $ext2
        foreach ($c in $exts) {
            $text = $c.text
            if (-not $text) { continue }
            $kind = Classify-ClaimType $text
            if ($kind -eq 'opinion') { continue }
            $startIdx = [Math]::Max(0, $c.line - 1)
            $endIdx = [Math]::Min($lines.Count - 1, $c.line - 1 + $ContextLines)
            $ctxLines = $lines[$startIdx..$endIdx]
            $comments += @{
                file = $rel
                line = $c.line
                text = $text
                kind = $kind
                codeContext = ($ctxLines -join "`n")
            }
        }
    }
}

$result = @{
    claims = $comments
    counts = @{
        scannedFiles = $scannedFiles
        totalClaims = $comments.Count
        byKind = @($comments | Group-Object kind | ForEach-Object { @{ kind = $_.Name; count = $_.Count } })
    }
}

Write-Output "=== Comment Harvest Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Behavioral claims: $($comments.Count)"
foreach ($b in $result.counts.byKind) { Write-Output "  $($b.kind): $($b.count)" }

Write-Output ($result | ConvertTo-Json -Depth 8)
exit 0
