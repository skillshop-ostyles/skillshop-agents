[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Symbols = "",

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs",

    [string]$Exclude = ""
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

function Get-RelativePath($base, $target) {
    $base = $base.TrimEnd('\').TrimEnd('/')
    $targetPath = $target.TrimEnd('\').TrimEnd('/')
    if ($targetPath -eq $base) { return '.' }
    if ($targetPath.StartsWith($base + '\') -or $targetPath.StartsWith($base + '/')) {
        return $targetPath.Substring($base.Length + 1)
    }
    return $targetPath
}

$testPatterns = @('\.test\.', '\.spec\.', '_test\.', '\btests\b')
function Is-TestFile($relPath) {
    foreach ($p in $testPatterns) {
        if ($relPath -match $p) { return $true }
    }
    return $false
}

$symbolList = if ($Symbols) { $Symbols -split ',' | ForEach-Object { $_.Trim() } } else { @() }
$testFiles = @()
$scannedFiles = 0

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $path = $_.FullName
        $skip = $false
        foreach ($exc in $excludeList) { if ($exc -and $path -match $exc) { $skip = $true } }
        if ($path -match 'node_modules|\.git|venv|bin|obj|__pycache__') { $skip = $true }
        -not $skip
    } | ForEach-Object {
        $relPath = Get-RelativePath $ProjectDir $_.FullName
        if (-not (Is-TestFile $relPath)) { return }
        $scannedFiles++
        $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { return }
        $content = $lines -join "`n"
        $ext = $_.Extension.ToLower()

        # Detect framework
        $framework = "unknown"
        if ($ext -in '.js','.ts','.jsx','.tsx') {
            if ($content -match 'from\s+["\x27]vitest') { $framework = "vitest" }
            elseif ($content -match 'from\s+["\x27]@jest|require\(["\x27]jest') { $framework = "jest" }
            elseif ($content -match 'from\s+["\x27]mocha') { $framework = "mocha" }
        } elseif ($ext -eq '.py') {
            if ($content -match 'import\s+pytest') { $framework = "pytest" }
            elseif ($content -match 'import\s+unittest') { $framework = "unittest" }
        } elseif ($ext -eq '.cs') {
            if ($content -match 'xunit') { $framework = "xunit" }
            elseif ($content -match 'NUnit') { $framework = "nunit" }
        } elseif ($ext -eq '.go') { $framework = "go-test" }
        elseif ($ext -eq '.rb') {
            if ($content -match 'RSpec|rspec') { $framework = "rspec" }
            elseif ($content -match 'Minitest|minitest') { $framework = "minitest" }
        } elseif ($ext -eq '.java') { $framework = "junit" }
        elseif ($ext -eq '.php') {
            if ($content -match 'PHPUnit|phpunit') { $framework = "phpunit" }
        }

        # Extract test cases
        $cases = @()
        $suites = @()
        $currentSuite = ""

        if ($ext -in '.js','.ts','.jsx','.tsx') {
            # describe/suite blocks
            $suiteMatch = [regex]::Match($content, '(?:describe|context|suite)\s*\(\s*["\x27]([^"\x27]+)["\x27]')
            while ($suiteMatch.Success) {
                $lineNo = $content.Substring(0, $suiteMatch.Index).Split("`n").Length
                $suites += @{ name = $suiteMatch.Groups[1].Value; line = $lineNo }
                $suiteMatch = $suiteMatch.NextMatch()
            }
            # it/test cases
            $caseMatch = [regex]::Match($content, '(?:it|test)\s*\(\s*["\x27]([^"\x27]+)["\x27]')
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.py') {
            # class TestX: method
            $classMatch = [regex]::Match($content, '^class\s+(\w+Test|\w+Spec)\s*\(', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($classMatch.Success) {
                $lineNo = $content.Substring(0, $classMatch.Index).Split("`n").Length
                $suites += @{ name = $classMatch.Groups[1].Value; line = $lineNo }
                $classMatch = $classMatch.NextMatch()
            }
            # def test_
            $caseMatch = [regex]::Match($content, '^def\s+(test_\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.cs') {
            $caseMatch = [regex]::Match($content, '\[Fact\]|\[Theory\]')
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = "Fact$($cases.Count + 1)"; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.go') {
            $caseMatch = [regex]::Match($content, '^func\s+(Test\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.rb') {
            $caseMatch = [regex]::Match($content, '(?:it|specify|scenario)\s+["\x27]([^"\x27]+)["\x27]')
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.java') {
            $caseMatch = [regex]::Match($content, '@Test')
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = "Test$($cases.Count + 1)"; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.php') {
            $caseMatch = [regex]::Match($content, '^function\s+(test\w+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        } elseif ($ext -eq '.ps1') {
            $caseMatch = [regex]::Match($content, '(?:It|Should -Invoke|Assert-MockCalled)\s+["\x27]([^"\x27]+)["\x27]')
            while ($caseMatch.Success) {
                $lineNo = $content.Substring(0, $caseMatch.Index).Split("`n").Length
                $cases += @{ name = $caseMatch.Groups[1].Value; line = $lineNo }
                $caseMatch = $caseMatch.NextMatch()
            }
        }

        # Extract imports for symbol mapping
        $imports = @()
        if ($ext -in '.js','.ts','.jsx','.tsx') {
            $importMatch = [regex]::Match($content, '(?:import|require)\s*\(?\s*["\x27]([./][^"\x27]+)["\x27]')
            while ($importMatch.Success) {
                $imp = $importMatch.Groups[1].Value
                if ($imp -notmatch '\.test\.|\.spec\.') { $imports += $imp }
                $importMatch = $importMatch.NextMatch()
            }
        } elseif ($ext -eq '.py') {
            $importMatch = [regex]::Match($content, '^(?:from\s+([\w.]+)\s+import|import\s+(\w[\w.]*))', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($importMatch.Success) {
                $imp = if ($importMatch.Groups[1].Value) { $importMatch.Groups[1].Value } else { $importMatch.Groups[2].Value }
                $imports += $imp
                $importMatch = $importMatch.NextMatch()
            }
        } elseif ($ext -eq '.go') {
            $importMatch = [regex]::Match($content, 'import\s+["\x27]([^"\x27]+)["\x27]')
            while ($importMatch.Success) { $imports += $importMatch.Groups[1].Value; $importMatch = $importMatch.NextMatch() }
        }

        # Match referenced symbols if provided
        $referencedSymbols = @()
        if ($symbolList.Count -gt 0) {
            $lowerContent = $content.ToLower()
            foreach ($sym in $symbolList) {
                if ($lowerContent -match [regex]::Escape($sym.ToLower())) {
                    $referencedSymbols += $sym
                }
            }
        }

        $testFiles += @{
            file = $relPath
            framework = $framework
            cases = $cases
            suites = $suites
            imports = $imports
            referencedSymbols = $referencedSymbols
        }
    }
}

$totalCases = 0
foreach ($tf in $testFiles) { $totalCases += $tf.cases.Count }

$result = @{
    testFiles = $testFiles
    counts = @{ files = $testFiles.Count; cases = $totalCases; scannedFiles = $scannedFiles }
}

$json = $result | ConvertTo-Json -Depth 10
Write-Output $json
exit 0
