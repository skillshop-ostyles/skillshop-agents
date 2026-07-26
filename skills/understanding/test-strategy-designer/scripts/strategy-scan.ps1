[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.test.ts,*.test.js,*.spec.ts,*.spec.js,*.test.py,*.Test.cs,*.test.go,*.test.rs",

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

# Classification pattern sets
$unitPatterns = @(
    @{ regex='from\s+["\x27]jest["\x27]|require\s*\(\s*["\x27]jest["\x27]'; kind='jest-import' },
    @{ regex='from\s+["\x27]@jest|import\s+.*from\s+["\x27]vitest["\x27]'; kind='jest-vitest-import' },
    @{ regex='using\s+NUnit\.|using\s+Microsoft\.VisualStudio\.TestTools'; kind='nunit-mstest' },
    @{ regex='import\s+pytest|from\s+pytest'; kind='pytest-import' },
    @{ regex='import\s+org\.junit|@Test\s*$|@Test\s+public'; kind='junit' },
    @{ regex='describe\s*\(|it\s*\(|test\s*\('; kind='describe-it-test' }
)

$integrationPatterns = @(
    @{ regex='supertest|chai-http'; kind='http-client' },
    @{ regex='TestRestTemplate|WebTestClient|MockMvc'; kind='spring-test' },
    @{ regex='django\.test\.client|from\s+flask\.testing|webtest'; kind='python-test-client' },
    @{ regex='app\.listen|createApp\s*\(|createServer\s*\('; kind='app-listen' },
    @{ regex='sqlite.*memory|:memory:|in-memory|InMemoryDatabase'; kind='in-memory-db' },
    @{ regex='Testcontainers|testContainers|testcontainers'; kind='testcontainers' },
    @{ regex='mount\s*\(|shallowMount|render\s*\('; kind='component-mount' }
)

$e2ePatterns = @(
    @{ regex='playwright|@playwright'; kind='playwright' },
    @{ regex='cypress|Cypress'; kind='cypress' },
    @{ regex='puppeteer|Puppeteer'; kind='puppeteer' },
    @{ regex='selenium|Selenium|WebDriver'; kind='selenium' },
    @{ regex='protractor|Protractor'; kind='protractor' },
    @{ regex='page\.goto|page\.locator|page\.click|page\.type'; kind='page-interaction' }
)

# Assertion patterns
$assertPatterns = @(
    @{ regex='expect\s*\(|assert\s*\(|\.toEqual\s*\(|\.toBe\s*\(|\.toMatch\s*\('; kind='jest-assert' },
    @{ regex='assert\.\w+|self\.assert|assertEquals|assertTrue|assertFalse'; kind='generic-assert' },
    @{ regex='\.should\s*\(|should\s+\.|chai\.expect'; kind='chai-assert' },
    @{ regex='verify\s*\(|thenReturn|when\s*\('; kind='mockito-verify' }
)

# Mock patterns
$mockPatterns = @(
    @{ regex='jest\.mock\s*\(|jest\.spyOn|jest\.fn\s*\('; kind='jest-mock' },
    @{ regex='vi\.mock\s*\(|vi\.spyOn|vi\.fn\s*\('; kind='vitest-mock' },
    @{ regex='patch\s*\(|monkeypatch\.|MagicMock|Mock\s*\('; kind='python-mock' },
    @{ regex='Mockito\.mock|Mock\s*<|@Mock\s*$|@InjectMocks'; kind='java-mock' },
    @{ regex='createMock|mock\s*<'; kind='generic-mock' }
)

$unitTests = @()
$integrationTests = @()
$e2eTests = @()
$allTestFiles = @()
$totalAssertions = 0
$assertionStats = @{}
$mockComplexity = @{}

# Build exclusion regex
$excludeDirs = 'node_modules[\\/]|\.git[\\/]|venv[\\/]|__pycache__[\\/]|dist[\\/]|build[\\/]|bin[\\/]|obj[\\/]'

# Phase 1: Discover and classify test files
foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $accept = $true

        if ($rel -match $excludeDirs) { $accept = $false }
        if ($accept -and ($rel -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($rel -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($rel -match '[\\/]node_modules[\\/]')) { $accept = $false }

        if (-not $accept) { continue }

        # Filter custom exclude list
        if ($Exclude) {
            foreach ($ex in ($Exclude -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                if ($rel -match $ex) { $accept = $false; break }
            }
        }
        if (-not $accept) { continue }

        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $lines = $content -split "`n"
        $lineText = ($lines -join "`n").ToLower()

        # Count assertions
        $assertCount = 0
        foreach ($ap in $assertPatterns) {
            $matches = [regex]::Matches($content, $ap.regex)
            $assertCount += $matches.Count
        }
        $totalAssertions += $assertCount
        $assertionStats[$rel] = $assertCount

        # Count mocks
        $mockCount = 0
        foreach ($mp in $mockPatterns) {
            $matches = [regex]::Matches($content, $mp.regex)
            $mockCount += $matches.Count
        }
        $mockComplexity[$rel] = $mockCount

        # Classify: E2E takes priority, then Integration, then Unit
        $isE2e = $false
        $isIntegration = $false

        foreach ($ep in $e2ePatterns) {
            if ($lineText -match $ep.regex) { $isE2e = $true; break }
        }

        if (-not $isE2e) {
            foreach ($ip in $integrationPatterns) {
                if ($lineText -match $ip.regex) { $isIntegration = $true; break }
            }
        }

        if ($isE2e) {
            $e2eTests += @{ file = $rel; assertions = $assertCount; mocks = $mockCount }
        } elseif ($isIntegration) {
            $integrationTests += @{ file = $rel; assertions = $assertCount; mocks = $mockCount }
        } else {
            $unitTests += @{ file = $rel; assertions = $assertCount; mocks = $mockCount }
        }

        $allTestFiles += @{ file = $rel; assertions = $assertCount; mocks = $mockCount }
    }
}

# Phase 2: Untested module detection
$untestedModules = @()
$sourceExtensions = '*.ts', '*.tsx', '*.js', '*.jsx', '*.py', '*.cs', '*.go', '*.rs', '*.java'

# Collect all test file names (stripped of path and test suffix)
$testNames = @{}
foreach ($tf in $allTestFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($tf.file)
    # Strip .test, .spec, .integration, .e2e suffixes
    $cleanName = $baseName -replace '\.(test|spec|integration|e2e)(\..+)?$', ''
    $testNames[$cleanName.ToLower()] = $true
    # Also try without the last extension
    $baseNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
    $testNames[$baseNameNoExt.ToLower()] = $true
}

foreach ($srcExt in ($sourceExtensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $srcItems = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $srcExt -File -ErrorAction SilentlyContinue
    foreach ($si in $srcItems) {
        $sfn = $si.FullName
        $rel = $sfn.Substring($ProjectDir.Length).TrimStart('\')

        # Skip if it is a test file itself
        if ($rel -match '\.test\.|\.spec\.|_test\.py|Test\.cs') { continue }
        # Skip excluded dirs (but NOT fixtures)
        if ($rel -match $excludeDirs) { continue }
        if ($rel -match '[\\/]fixtures[\\/]') { continue }
        if ($rel -match '[\\/]tests[\\/]fixtures[\\/]') {
            # But include fixture source files
            if ($rel -match '[\\/]smoke[\\/]src[\\/]') { } else { continue }
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sfn)
        if (-not $testNames.ContainsKey($baseName.ToLower())) {
            $untestedModules += @{ file = $rel; module = $baseName }
        }
    }
}

# Phase 3: Build pyramid
$unitCount = $unitTests.Count
$integrationCount = $integrationTests.Count
$e2eCount = $e2eTests.Count
$totalCount = $unitCount + $integrationCount + $e2eCount

# Console summary
Write-Output "=== Test Strategy Scan Complete ==="
Write-Output "  Test files found: $totalCount"
Write-Output "  Unit tests: $unitCount ($(if ($totalCount -gt 0) { [math]::Round($unitCount / $totalCount * 100) } else { 0 })%)"
Write-Output "  Integration tests: $integrationCount ($(if ($totalCount -gt 0) { [math]::Round($integrationCount / $totalCount * 100) } else { 0 })%)"
Write-Output "  E2E tests: $e2eCount ($(if ($totalCount -gt 0) { [math]::Round($e2eCount / $totalCount * 100) } else { 0 })%)"
Write-Output "  Ideal pyramid: 60/30/10 (unit/integration/e2e)"
Write-Output "  Total assertions: $totalAssertions"
Write-Output "  Untested modules: $($untestedModules.Count)"
foreach ($um in $untestedModules) { Write-Output "    - $($um.file)" }

# Collate assertion stats
$assertSummaries = @()
foreach ($tf in $allTestFiles) {
    $assertSummaries += @{ file = $tf.file; count = $tf.assertions }
}
$mockSummaries = @()
foreach ($tf in $allTestFiles) {
    $mockSummaries += @{ file = $tf.file; count = $tf.mocks }
}

$result = @{
    unitTests = $unitTests
    integrationTests = $integrationTests
    e2eTests = $e2eTests
    testPyramid = @{
        unit = $unitCount
        integration = $integrationCount
        e2e = $e2eCount
        total = $totalCount
        unitPct = if ($totalCount -gt 0) { [math]::Round($unitCount / $totalCount * 100, 1) } else { 0 }
        integrationPct = if ($totalCount -gt 0) { [math]::Round($integrationCount / $totalCount * 100, 1) } else { 0 }
        e2ePct = if ($totalCount -gt 0) { [math]::Round($e2eCount / $totalCount * 100, 1) } else { 0 }
        idealRatio = "60/30/10"
    }
    untestedModules = $untestedModules
    assertionStats = $assertionStats
    mockComplexity = $mockComplexity
    counts = @{
        totalTestFiles = $totalCount
        unitTests = $unitCount
        integrationTests = $integrationCount
        e2eTests = $e2eCount
        totalAssertions = $totalAssertions
        untestedModules = $untestedModules.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
