[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.rs",
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

$conventions = @()

# Convention: Import style (named vs default)
$namedImport = 0; $defaultImport = 0; $namedFiles = @(); $defaultFiles = @()
# Convention: async/await vs .then()
$asyncAwait = 0; $thenCatch = 0; $asyncFiles = @(); $thenFiles = @()
# Convention: arrow vs function keyword
$arrowFn = 0; $functionKeyword = 0; $arrowFiles = @(); $functionFiles = @()
# Convention: nullish coalescing vs logical or
$nullish = 0; $logicalOr = 0; $nullishFiles = @(); $logicalOrFiles = @()
# Convention: template literals vs concat
$templateLit = 0; $concat = 0; $templateFiles = @(); $concatFiles = @()
# Convention: PascalCase interfaces vs Zod/type
$pascalInterface = 0; $otherType = 0; $pascalFiles = @(); $otherTypeFiles = @()

$count = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $count += 1
        $lines = $content -split "`n"

        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -match '^\s*(//|#|import\s|require\s)') { continue }

            # Import style: named vs default imports (TS/JS)
            if ($t -match '^import\s+\{\s*(\w|\s|,)+\}\s+from') { $namedImport += 1; if ($namedFiles[-1] -ne $rel) { $namedFiles += $rel } }
            if ($t -match '^import\s+\w+\s+from\s+[''"](?!/)') { $defaultImport += 1; if ($defaultFiles[-1] -ne $rel) { $defaultFiles += $rel } }

            # Async: async/await vs .then()
            if ($t -match 'await\s+\w+') { $asyncAwait += 1; if ($asyncFiles[-1] -ne $rel) { $asyncFiles += $rel } }
            if ($t -match '\.then\s*\(') { $thenCatch += 1; if ($thenFiles[-1] -ne $rel) { $thenFiles += $rel } }

            # Arrow vs function keyword (JS/TS)
            if ($t -match '^\s*(const|let|var)\s+\w+\s*=\s*\(.*\)\s*=>|^\s*(export\s+)?(const|let|var)\s+\w+\s*=\s*\(.*\)\s*=>') { $arrowFn += 1; if ($arrowFiles[-1] -ne $rel) { $arrowFiles += $rel } }
            if ($t -match '^\s*(export\s+)?(async\s+)?function\s') { $functionKeyword += 1; if ($functionFiles[-1] -ne $rel) { $functionFiles += $rel } }

            # Null handling: ?? vs ||
            if ($t -match '\?\?\s*[''"\w\d]') { $nullish += 1; if ($nullishFiles[-1] -ne $rel) { $nullishFiles += $rel } }
            if ($t -match '\|\|\s*[''"\w\d]' -and $t -notmatch '\?\?') { $logicalOr += 1; if ($logicalOrFiles[-1] -ne $rel) { $logicalOrFiles += $rel } }

            # Template literals vs concat (JS/TS)
            if ($t -match '\${\w+}') { $templateLit += 1; if ($templateFiles[-1] -ne $rel) { $templateFiles += $rel } }
            if ($t -match '''\s*\+\s*\w+|\w+\s*\+\s*''|"\s*\+\s*\w+|\w+\s*\+\s*"') { $concat += 1; if ($concatFiles[-1] -ne $rel) { $concatFiles += $rel } }

            # PascalCase interfaces vs types/Zod
            if ($t -match '^interface\s+[A-Z]') { $pascalInterface += 1; if ($pascalFiles[-1] -ne $rel) { $pascalFiles += $rel } }
            if ($t -match '^type\s+\w+\s*=') { $otherType += 1; if ($otherTypeFiles[-1] -ne $rel) { $otherTypeFiles += $rel } }
        }
    }
}

function Get-Score($a, $b) {
    $total = $a + $b
    if ($total -eq 0) { return $null }
    return [math]::Round($a / $total, 2)
}

$conventions = @(
    @{ name = "named-imports"; dominant = "named"; matches = $namedImport; nonMatches = $defaultImport; score = (Get-Score $namedImport ($namedImport + $defaultImport)); examples = $namedFiles; counterExamples = $defaultFiles }
    @{ name = "default-imports"; dominant = "default"; matches = $defaultImport; nonMatches = $namedImport; score = (Get-Score $defaultImport ($namedImport + $defaultImport)); examples = $defaultFiles; counterExamples = $namedFiles }
    @{ name = "async-await"; dominant = "async/await"; matches = $asyncAwait; nonMatches = $thenCatch; score = (Get-Score $asyncAwait ($asyncAwait + $thenCatch)); examples = $asyncFiles; counterExamples = $thenFiles }
    @{ name = "arrow-functions"; dominant = "arrow"; matches = $arrowFn; nonMatches = $functionKeyword; score = (Get-Score $arrowFn ($arrowFn + $functionKeyword)); examples = $arrowFiles; counterExamples = $functionFiles }
    @{ name = "nullish-coalescing"; dominant = "??"; matches = $nullish; nonMatches = $logicalOr; score = (Get-Score $nullish ($nullish + $logicalOr)); examples = $nullishFiles; counterExamples = $logicalOrFiles }
    @{ name = "template-literals"; dominant = "template"; matches = $templateLit; nonMatches = $concat; score = (Get-Score $templateLit ($templateLit + $concat)); examples = $templateFiles; counterExamples = $concatFiles }
    @{ name = "pascalcase-interfaces"; dominant = "PascalCase"; matches = $pascalInterface; nonMatches = $otherType; score = (Get-Score $pascalInterface ($pascalInterface + $otherType)); examples = $pascalFiles; counterExamples = $otherTypeFiles }
)

Write-Output "=== Convention Scan Complete ==="
Write-Output "  Files scanned: $count"
foreach ($c in $conventions) {
    $s = if ($c.score -ne $null) { "$($c.score)" } else { "N/A" }
    Write-Output "  $($c.name): $($c.matches) vs $($c.nonMatches) (score=$s)"
}

$result = @{
    scannedFiles = $count
    conventions = $conventions
}
Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
