[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.test.ts,*.spec.ts,*.test.js,*.spec.js,*.test.tsx,*_test.go,test_*.py,*_test.py,*.Tests.cs",
    [string]$Exclude = "",
    [string]$TestRunner = "auto"
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Heuristics for test-case detection (language-agnostic, regex on text).
$testNamePatterns = @(
    '^\s*(it|test|describe|xit|xdescribe|it\.skip|test\.skip)\s*\(',
    '^\s*def\s+test_',
    '^\s*func\s+Test',
    '^\s*\[Fact\]',
    '^\s*\[Theory\]'
)

# Suspicious patterns we want to count per test.
$disablePatterns = @('^\s*(it\.skip|test\.skip|xit|xdescribe|@Skip|@Disabled|xfail|@pytest\.mark\.skip)', '^\s*#\s*skip', '^\s*//\s*skip')

$assertLikePatterns = @( # we count occurrences, presence alone is not enough
    'expect\s*\(',
    'assert\s+',
    'assertEqual|assertTrue|assertFalse|assertEquals|assertNotEqual|Shouldly|FluentAssertions',
    'assert\.',
    '\.Equal\s*\(',
    '\.NotEqual\s*\(',
    'should\.be\.',
    'pytest\.raises',
    'unittest\.assert'
)

$tryAroundAssertPattern = 'try\s*:\s*[\s\S]{0,400}?(expect|assert)'

$tests = @()
$scannedFiles = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')

        # Split content into per-test-case blocks.
        $text = $content
        # JS/TS: `it(...)` and `test(...)` calls. Find each opening `it(`, `test(` / `(.{` matched braces.
        $positions = @()
        foreach ($p in $testNamePatterns) {
            $regex = [regex]::Matches($text, $p, [System.Text.RegularExpressions.RegexOptions]::Multiline)
            foreach ($m in $regex) { $positions += @{ pos = $m.Index; kind = $p } }
        }
        $positions = $positions | Sort-Object { $_.pos }

        # Deduplicate overlapping positions.
        $dedup = @()
        $last = -9999
        foreach ($p in $positions) {
            if ($p.pos - $last -gt 20) { $dedup += $p }
            $last = $p.pos
        }

        foreach ($p in $dedup) {
            # Slice from current match to the next test boundary (next it/test/describe open OR 800 chars max).
            $maxSlice = [Math]::Min(800, $text.Length - $p.pos)
            $tail = $text.Substring($p.pos, $maxSlice)
            # Find next test boundary after the current one.
            $nextMatch = [regex]::Match($tail.Substring(50), '^\s*(it|test|describe)\s*\(', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $sliceLen = if ($nextMatch.Success -and $nextMatch.Index -lt 750) { 50 + $nextMatch.Index } else { $maxSlice }
            $slice = $text.Substring($p.pos, $sliceLen)
            $nameMatch = [regex]::Match($slice, '["\x27]([^"\x27]+)["\x27]')
            $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { "anonymous" }

            $assertCount = 0
            foreach ($ap in $assertLikePatterns) {
                $assertCount += ([regex]::Matches($slice, $ap)).Count
            }

            $disabled = $false
            foreach ($dp in $disablePatterns) {
                if ($slice -match $dp) { $disabled = $true; break }
            }
            # Also catch line-leading markers.
            $sliceLines = $slice -split "`n"
            foreach ($sl in $sliceLines) {
                if ($sl -match '^\s*(it\.skip|test\.skip|xit|xdescribe|@Skip|@Disabled|xfail|pytest\.mark\.skip)\b') {
                    $disabled = $true; break
                }
                if ($sl -match '^\s*(#|//)\s*(skip|todo:?|wip|disabled)') {
                    if ($sl -match '(skip|wip|disabled)') { $disabled = $true; break }
                }
            }

            $tryAssert = $slice -match $tryAroundAssertPattern

            # Identify line number in file.
            $lineNum = ($text.Substring(0, $p.pos) -split "`n").Count

            # Severity heuristic for the LLM to review:
            # - assertionCount == 0 and not disabled -> cannot-fail candidate
            # - assertionCount == 1 with literal target -> tautology candidate (rough heuristic)
            $t1 = ($slice -match 'expect\s*\(\s*true\s*\)')
            $t2 = ($slice -match 'assert\s+True')
            $t3 = ($slice -match "expect\s*\(\s*[" + [char]39 + "]?[\w\-]+[" + [char]39 + "]?\.toBe\s*\(\s*true")
            $tautologySuspicion = ($assertCount -le 1) -and ($t1 -or $t2 -or $t3)

            $tests += @{
                file = $rel
                line = $lineNum
                name = $name
                runner = ($p.kind -replace '^\s*', '')
                assertionCount = $assertCount
                disabled = $disabled
                tryAroundAssert = $tryAssert
                tautologySuspicion = $tautologySuspicion
                body = $slice.Substring(0, [Math]::Min(600, $slice.Length))
            }
        }
    }
}

# Compute age of skip markers via git blame if available (only if ProjectDir is in a git repo).
$inGitRepo = $false
if (Test-Path -LiteralPath (Join-Path $ProjectDir '.git') -PathType Any) { $inGitRepo = $true }
foreach ($t in $tests) {
    if ($t.disabled -and $inGitRepo) {
        $blame = git -C $ProjectDir blame --line-porcelain (Join-Path $ProjectDir $t.file) -L "$($t.line),$($t.line)" 2>&1 | Out-String
        if ($blame -notmatch 'fatal:' -and $blame -match 'author-time ') {
            $authorTime = ($blame | Where-Object { $_ -match '^author-time ' } | Select-Object -First 1)
            if ($authorTime) {
                $ts = [int]($authorTime -replace '^author-time\s+', '')
                $days = [int]((Get-Date).ToUniversalTime() - [DateTime]::FromUnixTimeSeconds($ts).ToUniversalTime()).TotalDays
                $t.disabledSinceDays = $days
            }
        }
    }
}

$result = @{
    tests = $tests
    counts = @{
        scannedFiles = $scannedFiles
        totalTests = $tests.Count
        disabledTests = @($tests | Where-Object { $_.disabled }).Count
        zeroAssertTests = @($tests | Where-Object { $_.assertionCount -eq 0 -and -not $_.disabled }).Count
        tryAroundAssert = @($tests | Where-Object { $_.tryAroundAssert }).Count
    }
}

Write-Output "=== Test Honesty Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Tests total: $($tests.Count)"
Write-Output "  Disabled/skipped: $($result.counts.disabledTests)"
Write-Output "  Zero-assertion (not disabled): $($result.counts.zeroAssertTests)"
Write-Output "  Try-around-assert (swallows): $($result.counts.tryAroundAssert)"

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
