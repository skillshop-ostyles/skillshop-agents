[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'java', 'rb', 'go', 'rs', 'cs'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', '.mypy_cache')
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

function Get-RelativePath($fullPath) {
    return $fullPath.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
}

function Strip-Comments($text) {
    $result = ''
    $i = 0
    $len = $text.Length
    while ($i -lt $len) {
        if ($i -lt $len - 1 -and $text[$i] -eq '/' -and $text[$i + 1] -eq '/') {
            while ($i -lt $len -and $text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($i -lt $len - 1 -and $text[$i] -eq '/' -and $text[$i + 1] -eq '*') {
            $i += 2
            while ($i -lt $len - 1 -and -not ($text[$i] -eq '*' -and $text[$i + 1] -eq '/')) { $i++ }
            if ($i -lt $len) { $i += 2 }
            continue
        }
        $result += $text[$i]
        $i++
    }
    return $result
}

function Extract-ObjectLiteral($text, $startIndex) {
    $braceDepth = 0
    $inSingle = $false
    $inDouble = $false
    $inTemplate = $false
    $foundOpening = $false
    $objEnd = 0

    for ($j = $startIndex; $j -lt $text.Length; $j++) {
        $ch = $text[$j]
        $nextCh = if ($j + 1 -lt $text.Length) { $text[$j + 1] } else { $null }

        if (-not $inSingle -and -not $inDouble -and -not $inTemplate) {
            if ($ch -eq "'" -and -not ($j -gt 0 -and $text[$j - 1] -eq '\')) { $inSingle = $true; continue }
            if ($ch -eq '"' -and -not ($j -gt 0 -and $text[$j - 1] -eq '\')) { $inDouble = $true; continue }
            if ($ch -eq '`') { $inTemplate = $true; continue }

            if ($ch -eq '/' -and $nextCh -eq '/') {
                while ($j -lt $text.Length -and $text[$j] -ne "`n") { $j++ }
                continue
            }
            if ($ch -eq '/' -and $nextCh -eq '*') {
                $j += 2
                while ($j -lt $text.Length - 1 -and -not ($text[$j] -eq '*' -and $text[$j + 1] -eq '/')) { $j++ }
                if ($j -lt $text.Length) { $j++ }
                continue
            }

            if ($ch -eq '{') {
                $braceDepth++
                if (-not $foundOpening) { $foundOpening = $true; $braceDepth = 1 }
                continue
            }
            if ($ch -eq '}') {
                $braceDepth--
                if ($foundOpening -and $braceDepth -le 0) { $objEnd = $j + 1; break }
                continue
            }
        }
        else {
            if ($inSingle -and $ch -eq "'" -and -not ($j -gt 0 -and $text[$j - 1] -eq '\')) { $inSingle = $false }
            if ($inDouble -and $ch -eq '"' -and -not ($j -gt 0 -and $text[$j - 1] -eq '\')) { $inDouble = $false }
            if ($inTemplate -and $ch -eq '`') { $inTemplate = $false }
        }
    }

    if ($objEnd -gt 0) {
        return $text.Substring($startIndex, $objEnd - $startIndex)
    }
    return $null
}

function Get-ObjectKeys($objectLiteral) {
    $keys = New-Object System.Collections.Generic.List[object]

    $clean = Strip-Comments $objectLiteral

    $braceDepth = 0
    $i = 0
    $len = $clean.Length
    $inSingle = $false
    $inDouble = $false
    $inTemplate = $false
    $keywords = @('function', 'get', 'set', 'async', 'static', 'class', 'new', 'typeof', 'return', 'if', 'else', 'for', 'while', 'switch', 'case', 'break', 'continue', 'import', 'export', 'default', 'from', 'const', 'let', 'var')
    $constructorContext = $false

    while ($i -lt $len) {
        $ch = $clean[$i]

        if ($inSingle) {
            if ($ch -eq "'" -and -not ($i -gt 0 -and $clean[$i - 1] -eq '\')) { $inSingle = $false }
            $i++; continue
        }
        if ($inDouble) {
            if ($ch -eq '"' -and -not ($i -gt 0 -and $clean[$i - 1] -eq '\')) { $inDouble = $false }
            $i++; continue
        }
        if ($inTemplate) {
            if ($ch -eq '`') { $inTemplate = $false }
            $i++; continue
        }

        if ($ch -eq "'") { $inSingle = $true; $i++; continue }
        if ($ch -eq '"') { $inDouble = $true; $i++; continue }
        if ($ch -eq '`') { $inTemplate = $true; $i++; continue }

        if ($ch -eq '{') { $braceDepth++; $i++; continue }
        if ($ch -eq '}') { $braceDepth--; $i++; continue }

        if ($ch -match '[a-zA-Z_$]') {
            $identBuf = ''
            while ($i -lt $len -and $clean[$i] -match '[a-zA-Z0-9_$]') {
                $identBuf += $clean[$i]; $i++
            }
            $isKeyword = $identBuf -in $keywords
            if ($i -lt $len -and $clean[$i] -eq ':') {
                if (-not $isKeyword -and -not $constructorContext) {
                    $keys.Add([ordered]@{ key = $identBuf; kind = 'identifier' })
                }
            }
            elseif (-not $isKeyword -and $braceDepth -ge 1 -and -not $constructorContext) {
                $nextNonSpace = $i
                while ($nextNonSpace -lt $len -and ($clean[$nextNonSpace] -eq ' ' -or $clean[$nextNonSpace] -eq "`t" -or $clean[$nextNonSpace] -eq "`r" -or $clean[$nextNonSpace] -eq "`n")) { $nextNonSpace++ }
                if ($nextNonSpace -lt $len -and $clean[$nextNonSpace] -ne ':') {
                    $keys.Add([ordered]@{ key = $identBuf; kind = 'shorthand' })
                }
            }
            $constructorContext = ($identBuf -eq 'new')
            continue
        }
        $i++
    }

    return $keys.ToArray()
}

function Get-RealModulePath($mockPath, $testFileDir) {
    if ($mockPath -match '^[\.]') {
        $resolved = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($testFileDir, $mockPath))
        $candidates = @(
            "$resolved.js",
            "$resolved.ts",
            "$resolved.jsx",
            "$resolved.tsx",
            "$resolved.mjs",
            "$resolved.cjs",
            "$resolved\index.js",
            "$resolved\index.ts",
            "$resolved\index.jsx",
            "$resolved\index.tsx"
        )
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c) { return $c }
        }
        return $null
    }
    return $null
}

# ---- Pass 1: Find mock definitions in test files ----

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

$testFiles = @($allFiles | Where-Object {
    $rel = Get-RelativePath $_.FullName
    ($rel -match '\.test\.') -or
    ($rel -match '\.spec\.') -or
    ($rel -match '_test\.') -or
    ($rel -match '__tests__[\\/]')
})

$mocksCollected = New-Object System.Collections.Generic.List[object]
$allScannedTestFiles = New-Object System.Collections.Generic.List[object]
$allScannedRealFiles = New-Object System.Collections.Generic.List[object]

foreach ($tf in $testFiles) {
    $tfRel = Get-RelativePath $tf.FullName
    $allScannedTestFiles.Add($tfRel)
    $tfDir = Split-Path -Parent $tf.FullName
    $lines = Get-Content -LiteralPath $tf.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Pattern: jest.mock('module', () => ({...}))
    $jestMockPattern = [regex]::Matches($content, '(?is)jest\.mock\(\s*[''`"]([^''`"]+)[''`"]\s*,\s*(?:\(\)\s*=>|function\s*\(\))\s*\(\s*\{')
    foreach ($jm in $jestMockPattern) {
        $modPath = $jm.Groups[1].Value
        $factoryStart = $jm.Index + $jm.Length - 1

        $braceDepth = 0
        $factoryBody = ''
        $i = $factoryStart
        while ($i -lt $content.Length) {
            $ch = $content[$i]
            $factoryBody += $ch
            if ($ch -eq '{') { $braceDepth++ }
            elseif ($ch -eq '}') {
                $braceDepth--
                if ($braceDepth -le 0) { break }
            }
            $i++
        }

        $returnValueMatches = [regex]::Matches($factoryBody, '(?is)(mockReturnValue|mockResolvedValue|mockImplementation)\s*\(')
        foreach ($rv in $returnValueMatches) {
            $objText = $factoryBody.Substring($rv.Index + $rv.Length)
            $objLiteral = Extract-ObjectLiteral $objText 0
            if (-not $objLiteral) { continue }

            $keys = Get-ObjectKeys $objLiteral
            $realPath = Get-RealModulePath $modPath $tfDir

            $mockEntry = [ordered]@{
                testFile     = $tfRel
                mockedModule = $modPath
                mockType     = 'jest.mock'
                mockFields   = @($keys | ForEach-Object { $_.key })
                realFile     = if ($realPath) { Get-RelativePath $realPath } else { $null }
            }
            $mocksCollected.Add($mockEntry)
        }
    }

    # Pattern: jest.mock('module') without factory (automatic mock)
    $jestMockAuto = [regex]::Matches($content, '(?is)jest\.mock\(\s*[''`"]([^''`"]+)[''`"]\s*\)')
    foreach ($jma in $jestMockAuto) {
        $modPath = $jma.Groups[1].Value
        $realPath = Get-RealModulePath $modPath $tfDir
        $mockEntry = [ordered]@{
            testFile     = $tfRel
            mockedModule = $modPath
            mockType     = 'jest.mock (auto)'
            mockFields   = @()
            realFile     = if ($realPath) { Get-RelativePath $realPath } else { $null }
        }
        $mocksCollected.Add($mockEntry)
    }

    # Pattern: jest.fn().mockReturnValue({...}) / mockResolvedValue({...})
    $jestFnPattern = [regex]::Matches($content, '(?is)(?:jest\.fn|jest\.spyOn)[^;]*\.(mockReturnValue|mockResolvedValue|mockReturnValueOnce|mockResolvedValueOnce|mockImplementation)\s*\(')
    foreach ($jf in $jestFnPattern) {
        $remaining = $content.Substring($jf.Index + $jf.Length)
        $objLiteral = Extract-ObjectLiteral $remaining 0
        if (-not $objLiteral) { continue }

        $keys = Get-ObjectKeys $objLiteral
        if ($keys.Count -eq 0) { continue }

        $mockEntry = [ordered]@{
            testFile     = $tfRel
            mockedModule = $null
            mockType     = 'jest.fn().mockReturnValue/ResolvedValue'
            mockFields   = @($keys | ForEach-Object { $_.key })
            realFile     = $null
        }
        $mocksCollected.Add($mockEntry)
    }

    # Pattern: sinon.stub(obj, 'method').returns({...})
    $sinonPattern = [regex]::Matches($content, '(?is)sinon\.stub\([^,]+,\s*[''`"]([^''`"]+)[''`"]\s*\)\.(returns|resolves|callsFake)\s*\(')
    foreach ($ss in $sinonPattern) {
        $methodName = $ss.Groups[1].Value
        $remaining = $content.Substring($ss.Index + $ss.Length)
        $objLiteral = Extract-ObjectLiteral $remaining 0
        if (-not $objLiteral) { continue }

        $keys = Get-ObjectKeys $objLiteral
        if ($keys.Count -eq 0) { continue }

        $mockEntry = [ordered]@{
            testFile     = $tfRel
            mockedModule = $methodName
            mockType     = 'sinon.stub().returns()'
            mockFields   = @($keys | ForEach-Object { $_.key })
            realFile     = $null
        }
        $mocksCollected.Add($mockEntry)
    }

    # Pattern: Python unittest.mock.patch('module.method', return_value={...})
    $pyPatchPattern = [regex]::Matches($content, '(?is)(?:unittest\.mock\.patch|mock\.patch|@patch)\(')
    foreach ($pp in $pyPatchPattern) {
        $patchFnStart = $pp.Index
        $parenDepth = 0
        $patchEnd = $patchFnStart
        for ($j = $patchFnStart; $j -lt $content.Length; $j++) {
            if ($content[$j] -eq '(') { $parenDepth++ }
            elseif ($content[$j] -eq ')') {
                $parenDepth--
                if ($parenDepth -le 0) { $patchEnd = $j + 1; break }
            }
        }
        $patchCall = $content.Substring($patchFnStart, $patchEnd - $patchFnStart)

        $modMethodMatch = [regex]::Match($patchCall, '[''`"]([^''`"]+)[''`"]')
        $modMethod = if ($modMethodMatch.Success) { $modMethodMatch.Groups[1].Value } else { $null }

        $rvMatch = [regex]::Match($patchCall, 'return_value\s*=\s*(\{)')
        $keys = @()
        if ($rvMatch.Success) {
            $objLiteral = Extract-ObjectLiteral $patchCall $rvMatch.Index
            if ($objLiteral) { $keys = Get-ObjectKeys $objLiteral }
        }

        $mockEntry = [ordered]@{
            testFile     = $tfRel
            mockedModule = $modMethod
            mockType     = 'unittest.mock.patch'
            mockFields   = @($keys | ForEach-Object { $_.key })
            realFile     = $null
        }
        $mocksCollected.Add($mockEntry)
    }

    # Pattern: Java @Mock annotation
    $javaMockPattern = [regex]::Matches($content, '@Mock\s+(private|public|protected)?\s*(\w+)\s+(\w+)')
    foreach ($jvm in $javaMockPattern) {
        $javaType = $jvm.Groups[2].Value
        $mockEntry = [ordered]@{
            testFile     = $tfRel
            mockedModule = $javaType
            mockType     = '@Mock (Java)'
            mockFields   = @()
            realFile     = $null
        }
        $mocksCollected.Add($mockEntry)
    }
}

# ---- Pass 2: Find real implementations and compare ----

function Get-ExportedFunctionNames($content) {
    $names = New-Object 'System.Collections.Generic.HashSet[string]'

    $m1 = [regex]::Matches($content, '(?is)module\.exports\s*=\s*\{([^}]+)\}')
    foreach ($m in $m1) {
        $objBody = $m.Groups[1].Value
        $propMatches = [regex]::Matches($objBody, '(\w+)\s*(?::|,|\}|$)')
        foreach ($pm in $propMatches) {
            $n = $pm.Groups[1].Value.Trim()
            if ($n -ne '') { [void]$names.Add($n) }
        }
    }

    $m2 = [regex]::Matches($content, '(?is)(?:exports|module\.exports)\s*\.\s*(\w+)\s*=')
    foreach ($m in $m2) { [void]$names.Add($m.Groups[1].Value) }

    $m3 = [regex]::Matches($content, '(?is)\bfunction\s+(\w+)\s*\(')
    foreach ($m in $m3) { [void]$names.Add($m.Groups[1].Value) }

    $m4 = [regex]::Matches($content, '(?is)\bexport\s+(?:function|const|let|var)\s+(\w+)')
    foreach ($m in $m4) { [void]$names.Add($m.Groups[1].Value) }

    $m5 = [regex]::Matches($content, '(?is)(?:const|let|var)\s+(\w+)\s*=\s*(?:\([^)]*\)|[a-zA-Z_]\w*)\s*=>')
    foreach ($m in $m5) { [void]$names.Add($m.Groups[1].Value) }

    return @($names)
}

function Get-FunctionBody($content, $funcName) {
    $escapedName = [regex]::Escape($funcName)

    $pat0 = '(?is)function\s+' + $escapedName + '\s*\([^)]*\)\s*\{'
    $pat1 = '(?is)' + $escapedName + '\s*[:=]\s*function\s*\([^)]*\)\s*\{'
    $pat2 = '(?is)' + $escapedName + '\s*[:=]\s*\([^)]*\)\s*=>\s*\{'
    $pat3 = '(?is)' + $escapedName + '\s*[:=]\s*\([^)]*\)\s*=>\s*$'
    $pat4 = '(?is)(?:const|let|var)\s+' + $escapedName + '\s*=\s*(?:\([^)]*\)\s*=>\s*\{|[a-zA-Z_]\w*\s*=>\s*\{)'
    $patterns = @($pat0, $pat1, $pat2, $pat3, $pat4)

    foreach ($pat in $patterns) {
        $funcMatch = [regex]::Match($content, $pat)
        if ($funcMatch.Success) {
            $bodyStart = $funcMatch.Index + $funcMatch.Length
            $remaining = $content.Substring($bodyStart)
            $braceDepth = 1
            $bodyEnd = 0
            for ($j = 0; $j -lt $remaining.Length; $j++) {
                if ($remaining[$j] -eq '{') { $braceDepth++ }
                elseif ($remaining[$j] -eq '}') {
                    $braceDepth--
                    if ($braceDepth -le 0) { $bodyEnd = $j; break }
                }
            }
            if ($bodyEnd -gt 0) {
                return $remaining.Substring(0, $bodyEnd)
            }
        }
    }
    return $null
}

function Get-FunctionReturnObjectKeys($funcBody) {
    if (-not $funcBody) { return @() }

    $returnMatch = [regex]::Match($funcBody, '(?is)return\s+(\{)')
    if (-not $returnMatch.Success) { return @() }

    $objLiteral = Extract-ObjectLiteral $funcBody $returnMatch.Index
    if (-not $objLiteral) { return @() }

    return Get-ObjectKeys $objLiteral
}

function Get-FunctionThrowTypes($funcBody) {
    $throwTypes = New-Object System.Collections.Generic.List[object]
    if (-not $funcBody) { return @() }

    $throwMatches = [regex]::Matches($funcBody, '(?is)throw\s+(?:new\s+)?(\w+)')
    foreach ($tm in $throwMatches) {
        $typeName = $tm.Groups[1].Value
        if ($typeName -ne $null -and $typeName -ne '') {
            $throwTypes.Add($typeName)
        }
    }
    return $throwTypes.ToArray()
}

$divergences = New-Object System.Collections.Generic.List[object]

foreach ($mock in $mocksCollected) {
    $realFilePath = $null
    if ($mock.mockedModule -and $mock.mockedModule -match '^[\.]') {
        $testFileFull = [System.IO.Path]::Combine($root, $mock.testFile)
        $testDir = Split-Path -Parent $testFileFull
        $candidates = @()

        $base = [System.IO.Path]::Combine($testDir, $mock.mockedModule)
        $base = [System.IO.Path]::GetFullPath($base)
        foreach ($ext in @('js', 'ts', 'jsx', 'tsx', 'mjs', 'cjs')) {
            $candidates += "$base.$ext"
        }
        foreach ($ext in @('js', 'ts', 'jsx', 'tsx')) {
            $candidates += "$base\index.$ext"
        }

        $projBase = [System.IO.Path]::Combine($root, $mock.mockedModule)
        $projBase = [System.IO.Path]::GetFullPath($projBase)
        foreach ($ext in @('js', 'ts', 'jsx', 'tsx', 'mjs', 'cjs')) {
            $candidates += "$projBase.$ext"
        }

        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c -PathType Leaf) {
                $realFilePath = $c
                break
            }
        }
    }

    if (-not $realFilePath -and $mock.mockedModule -and -not ($mock.mockedModule -match '^[\.]')) {
        $nameOnly = [System.IO.Path]::GetFileNameWithoutExtension($mock.mockedModule)
        $searchResult = $allFiles | Where-Object { $_.BaseName -eq $nameOnly -or $_.BaseName -eq ($nameOnly -replace '\.(test|spec)$', '') } |
            Select-Object -First 1
        if ($searchResult) { $realFilePath = $searchResult.FullName }
    }

    if ($realFilePath) {
        $relReal = Get-RelativePath $realFilePath
        $allScannedRealFiles.Add($relReal)
        $realContent = Get-Content -LiteralPath $realFilePath -Raw -ErrorAction SilentlyContinue
        if ($realContent) {
            $exportedFns = Get-ExportedFunctionNames $realContent

            foreach ($efn in $exportedFns) {
                $funcBody = Get-FunctionBody $realContent $efn
                $realReturnKeys = Get-FunctionReturnObjectKeys $funcBody
                $realThrowTypes = Get-FunctionThrowTypes $funcBody

                $realKeySet = New-Object 'System.Collections.Generic.HashSet[string]'
                foreach ($rk in $realReturnKeys) { [void]$realKeySet.Add($rk.key) }

                $mockKeySet = New-Object 'System.Collections.Generic.HashSet[string]'
                foreach ($mk in $mock.mockFields) { [void]$mockKeySet.Add($mk) }

                foreach ($rk in $realReturnKeys) {
                    if (-not $mockKeySet.Contains($rk.key)) {
                        $divergences.Add([ordered]@{
                            testFile     = $mock.testFile
                            mockedModule = $mock.mockedModule
                            function     = $efn
                            field        = $rk.key
                            mockValue    = '(missing)'
                            realValue    = $rk.kind
                            severity     = 'dangerous'
                            direction    = 'under-mocking'
                        })
                    }
                }

                foreach ($mk in $mock.mockFields) {
                    if (-not $realKeySet.Contains($mk)) {
                        $divergences.Add([ordered]@{
                            testFile     = $mock.testFile
                            mockedModule = $mock.mockedModule
                            function     = $efn
                            field        = $mk
                            mockValue    = '(present in mock)'
                            realValue    = '(absent from real)'
                            severity     = 'noisy'
                            direction    = 'over-mocking'
                        })
                    }
                }

                foreach ($rt in $realThrowTypes) {
                    $divergences.Add([ordered]@{
                        testFile     = $mock.testFile
                        mockedModule = $mock.mockedModule
                        function     = $efn
                        field        = "(throw) $rt"
                        mockValue    = '(not mocked)'
                        realValue    = "throw $rt"
                        severity     = 'dangerous'
                        direction    = 'throw-type-mismatch'
                    })
                }
            }
        }
    }
}

# ---- Output ----

$result = [ordered]@{
    mocks = $mocksCollected.ToArray()
    divergences = $divergences.ToArray()
    scannedTestFiles = $allScannedTestFiles.ToArray()
    scannedRealFiles = $allScannedRealFiles.ToArray()
    counts = [ordered]@{
        testFiles     = $testFiles.Count
        mocksFound    = $mocksCollected.Count
        divergences   = $divergences.Count
        dangerous     = @($divergences | Where-Object { $_.severity -eq 'dangerous' }).Count
        noisy         = @($divergences | Where-Object { $_.severity -eq 'noisy' }).Count
        realFilesScanned = $allScannedRealFiles.Count
    }
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== MOCK-SCAN ==="
Write-Output "  Test files scanned: $($testFiles.Count)"
Write-Output "  Mock definitions found: $($mocksCollected.Count)"
Write-Output "  Real implementation files scanned: $($allScannedRealFiles.Count)"
Write-Output "  Total divergences: $($divergences.Count)"
Write-Output "    Dangerous (under-mocking / throw-mismatch): $(@($divergences | Where-Object { $_.severity -eq 'dangerous' }).Count)"
Write-Output "    Noisy (over-mocking): $(@($divergences | Where-Object { $_.severity -eq 'noisy' }).Count)"
