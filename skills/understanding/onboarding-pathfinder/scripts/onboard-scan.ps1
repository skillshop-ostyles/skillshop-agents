[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$pdir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $pdir) { Write-Error "Path not found: $ProjectDir"; exit 1 }
$pdir = $pdir.Path

$files = @()
$scannedFiles = 0

$exts = @('*.js','*.ts','*.tsx','*.jsx','*.py','*.cs','*.go','*.java','*.rb','*.php',
           '*.json','*.yaml','*.yml','*.toml','*.env*','*.cfg','*.ini',
           'Dockerfile','*docker-compose*','*.ps1','*.sh','*.sql','*.prisma',
           '*.css','*.html','*.scss','*.xml','*.proto','*.graphql')

foreach ($ext in $exts) {
    Get-ChildItem -LiteralPath $pdir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { $content = '' }
        $lines = $content -split "`r`n|`n"
        $rel = $fp.Substring($pdir.Length).TrimStart('\')
        $ext = $_.Extension.ToLower()
        $fname = $_.Name.ToLower()
        $dirPath = (Split-Path -LiteralPath $fp).Substring($pdir.Length).TrimStart('\')
        $lineCount = $lines.Count

        # Classify
        $category = 'other'
        if ($fname -match '(config|settings|env|dockerfile|docker-compose)') { $category = 'config' }
        elseif ($fname -match '^(main|index|server|cli|program)\b') { $category = 'entry' }
        elseif ($fname -match '^app\.') { $category = 'entry' }
        elseif ($fname -match '(model|entity|schema|dto|type|interface)') { $category = 'model' }
        elseif ($fname -match '(controller|handler|route|view|page|component)') { $category = 'controller' }
        elseif ($fname -match '(test|spec|e2e|integration)') { $category = 'test' }
        elseif ($fname -match '(service|helper|util|lib|logic|provider)') { $category = 'service' }
        elseif ($fname -match '(middleware|auth|guard|filter|interceptor)') { $category = 'middleware' }
        elseif ($fname -match '(repo|store|dao|dal|data|database|migration|query)') { $category = 'data' }
        elseif ($fname -match '(decorator|directive|pipe)') { $category = 'decorator' }

        # Imports/exports
        $imports = @()
        $exports = @()
        foreach ($ln in $lines) {
            $t = $ln.Trim()
            if ($t -match '(?:import|require)\s+[\w{*}\s,]+\s+from\s+["\x27](.+)["\x27]') { $imports += $matches[1] }
            elseif ($t -match '(?:import|require)\s*\(?\s*["\x27](.+)["\x27]') { $imports += $matches[1] }
            elseif ($t -match '(?:using|include|#include)\s+(.+)') { $imports += $matches[1] }
            if ($t -match '(?:export|module\.exports)\s*=\s*|^def\s+\w+|^func\s+\w+|^public\s+\w+|export\s+(?:function|class|const|let|var|default|interface|type)\s') { $exports += $t }
        }
        $imports = $imports | Select-Object -Unique
        $exports = $exports | Select-Object -Unique

        $files += @{
            file = $rel
            category = $category
            lines = $lineCount
            ext = $ext
            dir = $dirPath
            name = $fname
            importCount = $imports.Count
            exportCount = $exports.Count
        }
    }
}

# Generate reading tour: ordered by category
$categoryOrder = @{ 'config' = 0; 'entry' = 1; 'model' = 2; 'middleware' = 3; 'data' = 4; 'service' = 5; 'controller' = 6; 'decorator' = 7; 'test' = 8; 'other' = 9 }
$tourRationale = @{
    'config' = 'Start with configuration to understand project dependencies and environment.'
    'entry' = 'Entry point shows how the application boots and wires components together.'
    'model' = 'Models define the core data structures and domain types.'
    'middleware' = 'Middleware handles cross-cutting concerns like auth and logging.'
    'data' = 'Data layer reveals persistence strategy and database schema.'
    'service' = 'Services contain business logic and orchestrate operations.'
    'controller' = 'Controllers expose functionality through API endpoints.'
    'decorator' = 'Decorators add cross-cutting behavior declaratively.'
    'test' = 'Tests demonstrate expected behaviour and serve as runnable documentation.'
    'other' = ''
}
$questionMap = @{
    'config' = 'What configuration values does this file set up?'
    'entry' = 'How does this file bootstrap the application?'
    'model' = 'What domain entities does this file define?'
    'controller' = 'What API endpoints does this file define?'
    'service' = 'What business operations does this file implement?'
    'test' = 'What scenarios does this file test?'
    'middleware' = 'What cross-cutting concerns does this file handle?'
    'data' = 'What persistence logic does this file contain?'
}
$sortedFiles = $files | Sort-Object @{e={$categoryOrder[$_.category]}; a=$true}, @{e={$_.lines}; a=$true}

$readingTour = @()
$stepNum = 0
foreach ($f in $sortedFiles) {
    $stepNum++
    $rationale = $tourRationale[$f.category]
    $readingTour += @{ step = $stepNum; file = $f.file; category = $f.category; lines = $f.lines; rationale = $rationale }
}

$comprehension = @()
foreach ($f in $files) {
    $q = @()
    if ($f.exportCount -gt 0) { $q += "What does this file export or expose?" }
    if ($f.importCount -gt 0) { $q += "Which dependencies does this file import?" }
    $catQ = $questionMap[$f.category]
    if ($catQ) { $q += $catQ }
    if ($q.Count -eq 0) { $q += "What is the purpose of this file in the codebase?" }
    $comprehension += @{ file = $f.file; questions = $q }
}

# First safe tasks: small (<30 lines), no imports, utility/service category
$firstTasks = @()
foreach ($f in $files) {
    $score = 0
    if ($f.lines -le 20) { $score += 3 }
    elseif ($f.lines -le 50) { $score += 2 }
    elseif ($f.lines -le 100) { $score += 1 }
    if ($f.importCount -eq 0) { $score += 2 }
    if ($f.category -in 'service','test','config') { $score += 1 }
    if ($f.category -eq 'other') { $score += 1 }
    $firstTasks += @{ file = $f.file; category = $f.category; lines = $f.lines; imports = $f.importCount; score = $score }
}
$firstTasks = $firstTasks | Sort-Object score -Descending | Select-Object -First 5

$cats = $files | Group-Object { $_.category } | ForEach-Object { @{ category = $_.Name; count = $_.Count } }

$result = @{
    counts = @{
        scannedFiles = $scannedFiles
        categories = $cats
        tourSteps = $readingTour.Count
        questions = $comprehension.Count
        firstTasks = $firstTasks.Count
    }
    topology = $cats
    readingTour = $readingTour
    comprehension = $comprehension
    firstSafeTasks = $firstTasks
}

Write-Output "=== Onboarding Pathfinder Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Tour steps: $($readingTour.Count)"
Write-Output "  Comprehension questions: $($comprehension.Count)"
Write-Output "  First safe tasks: $($firstTasks.Count)"
foreach ($c in $cats) { Write-Output "  $($c.category): $($c.count) files" }

$json = $result | ConvertTo-Json -Depth 5
if ($PassThru) { return $json }
Write-Output $json
