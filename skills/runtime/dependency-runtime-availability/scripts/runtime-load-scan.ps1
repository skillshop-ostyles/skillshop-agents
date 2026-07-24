[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('js', 'jsx', 'ts', 'tsx', 'mjs', 'cjs', 'mts', 'cts', 'py', 'rb', 'php', 'go', 'rs', 'java', 'cs'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '.next', '.nuxt')
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

$knownNativeModules = @(
    'sharp', 'canvas', 'bcrypt', 'bcryptjs', 'node-canvas', 'node-gyp',
    'bufferutil', 'utf-8-validate', 'erlpack', 'msgpackr', 'simdjson',
    'onnxruntime-node', 'node-pty', 'fsevents', 'leveldown', 'snappy',
    'deasync', 'isolated-vm', 'tree-sitter', 'esbuild', 'better-sqlite3',
    'sqlite3', 'grpc', 'node-expat', 'dtrace-provider'
)
$knownNativeExePatterns = @('\.node$', '\.dll$', '\.so$', '\.dylib$', '\.wasm$')

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    $leaf = Split-Path $fullPath -Leaf
    if ($leaf -match '(?i)\.min\.' -or $leaf -match '(?i)generated') { return $true }
    return $false
}

function Get-Context($lines, $idx) {
    $result = @()
    for ($j = [Math]::Max(0, $idx - 2); $j -lt $idx; $j++) { $result += [string]$lines[$j] }
    for ($j = $idx + 1; $j -le [Math]::Min($lines.Count - 1, $idx + 2); $j++) { $result += [string]$lines[$j] }
    return $result
}

function Get-RelPath($fullPath) {
    return $fullPath.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
}

# Resolve a string literal path relative to the file's directory
function Resolve-RelativePath($relDir, $candidatePath) {
    $normalized = $candidatePath -replace '[''"]', ''
    $normalized = $normalized -replace '^\./', ''
    $combined = Join-Path $relDir $normalized -Resolve -ErrorAction SilentlyContinue
    if ($combined) { return (Resolve-Path $combined -ErrorAction SilentlyContinue).Path }
    return $null
}

# Known native modules registry
function Test-IsKnownNative($name) {
    $lower = $name.ToLower()
    foreach ($k in $knownNativeModules) {
        if ($lower -eq $k -or $lower -like "$k*") { return $true }
    }
    foreach ($pat in $knownNativeExePatterns) {
        if ($lower -match $pat) { return $true }
    }
    return $false
}

function Test-IsPlatformSpecific($line) {
    $platformHints = @(
        '(?i)process\.platform', '(?i)__dirname.*[/\\]platform',
        '(?i)os\.(platform|arch|type)\(', '(?i)win32',
        '(?i)darwin', '(?i)linux', '(?i)arm64', '(?i)x64',
        '(?i)\brpath\b', '(?i)\bnormalize\b'
    )
    foreach ($h in $platformHints) {
        if ($line -match $h) { return $true }
    }
    return $false
}

function Test-IsComputed($line) {
    $computedHints = @(
        '\+', '`\${\w', '\${\w', 'process\.env',
        'path\.join\(', 'path\.resolve\(', '__dirname',
        '__filename', 'template\s*`', '\bconfig\b', '\bsettings\b',
        '\.concat\(', 'replace\(', 'split\(',
        'runtime', 'variable'
    )
    foreach ($h in $computedHints) {
        if ($line -match $h) { return $true }
    }
    return $false
}

# Check the package.json for devDependencies at runtime
function Test-IsDevDependency($packageDir, $moduleName) {
    $pkgJson = Join-Path $packageDir 'package.json'
    if (-not (Test-Path -LiteralPath $pkgJson)) { return $false }
    try {
        $pkg = Get-Content -LiteralPath $pkgJson -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($pkg.devDependencies) {
            $props = $pkg.devDependencies.PSObject.Properties
            foreach ($prop in $props) {
                if ($prop.Name -eq $moduleName) { return $true }
                if ($prop.Name -like "$moduleName*") { return $true }
            }
        }
    } catch { }
    return $false
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)
$scannedFiles = $allFiles.Count

$loadRefs = New-Object System.Collections.Generic.List[object]

$patternCategories = [ordered]@{
    'dynamic-import' = @(
        '(?<!\w)require\([^''"`\n][^)]*\)',
        '(?<!\w)import\([^''"`\n][^)]*\)',
        'require\(`[^`]*`\)',
        'import\(`[^`]*`\)',
        '\bimport\s*\(\s*\w',
        '\brequire\s*\(\s*\w',
        'require\([''"][^''"]+[''"]\)'
    )
    'native-binding' = @(
        'require\([''"]\.node[''"]\)',
        '\bnode-gyp\b',
        '\bN-API\b',
        '\bnapi_\w+',
        '\bdlopen\b',
        'LoadLibrary[A-Z]\w*\(',
        '\[DllImport\('
    )
    'file-read' = @(
        'fs\.readFileSync\s*\(',
        'fs\.readFile\s*\(',
        'fs\.createReadStream\s*\(',
        'fs\.accessSync\s*\(',
        'fs\.statSync\s*\(',
        'fs\.existsSync\s*\(',
        'fs\.open\s*\(',
        'fs\.openSync\s*\('
    )
    'plugin-load' = @(
        'require\.resolve\s*\(',
        'plugins:\s*\[',
        '\.use\s*\(\s*\w',
        '\.load\s*\(',
        '\.register\s*\(',
        '\binstallPlugin\b',
        '\baddPlugin\b'
    )
    'config-path' = @(
        '(?i)process\.env\.\w+\s*\+\s*[''"]',
        '(?i)config\.\w+\s*\+\s*[''"]',
        '(?i)settings\.\w+\s*\+\s*[''"]'
    )
    'dll' = @(
        '\bdlopen\b',
        'LoadLibrary[A-Z]\w*\(',
        '\[DllImport\(',
        '\bkernel32\b',
        'GetProcAddress\s*\('
    )
}

foreach ($f in $allFiles) {
    $relPath = Get-RelPath $f.FullName
    $fileDir = Split-Path $f.FullName -Parent
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        $matchedCategories = @()
        foreach ($cat in $patternCategories.Keys) {
            foreach ($pat in $patternCategories[$cat]) {
                if ($line -match $pat) {
                    $matchedCategories += $cat
                    break
                }
            }
        }

        if ($matchedCategories.Count -eq 0) { continue }

        $isComputed = Test-IsComputed $line
        $isPlatformSpecific = Test-IsPlatformSpecific $line

        $target = ''
        $risk = 'safe'
        $existsInProject = $null
        $recommendation = ''
        $isNativeModule = $false
        $isDevDep = $false

        # Extract the target module/path from the line
        if ($line -match '(?:require|import)\s*\(([^)]+)\)') {
            $target = $matches[1].Trim()
            # Check if it's a literal string
            if ($target -match '^[''"]([^''"]+)[''"](\.js|\.json|\.node)?$') {
                $literalPath = $matches[1]
                $target = $literalPath
                $isComputed = $false

                # Try to find the resource in the project
                if ($literalPath -match '^\.') {
                    $resolved = Resolve-RelativePath $fileDir $literalPath
                    $existsInProject = $resolved -ne $null
                } else {
                    # npm module
                    $moduleName = ($literalPath -split '/')[0]
                    if ($literalPath.StartsWith('@')) {
                        $moduleName = ($literalPath -split '/')[0..1] -join '/'
                    }
                    $isNativeModule = Test-IsKnownNative $moduleName
                    $isDevDep = Test-IsDevDependency $root $moduleName
                    $existsInProject = (Test-Path (Join-Path $root "node_modules\$moduleName") -ErrorAction SilentlyContinue)
                }
            } else {
                $isComputed = $true
                # Check for known native modules in computed expressions
                foreach ($nm in $knownNativeModules) {
                    if ($line -match [regex]::Escape($nm)) {
                        $isNativeModule = $true
                        $target = $nm
                        break
                    }
                }
            }
        } elseif ($line -match 'fs\.\w+\s*\(([^)]+)\)') {
            $argStr = $matches[1].Trim()
            if ($argStr -match '^[''"]([^''"]+)[''"]') {
                $target = $matches[1]
                $resolved = Resolve-RelativePath $fileDir $target
                $existsInProject = $resolved -ne $null
            } else {
                $target = $argStr
                $isComputed = $true
            }
        } elseif ($line -match '\[DllImport\([''"]?([^''"]+)[''"]?\)') {
            $target = $matches[1]
        } elseif ($line -match '\bdlopen\b' -or $line -match 'LoadLibrary[A-Z]\w*\(' -or $line -match 'GetProcAddress\s*\(') {
            $target = $line.Trim()
        } elseif ($line -match 'require\.resolve\s*\(([^)]+)\)') {
            $target = $matches[1].Trim()
            if ($target -match '^[''"]([^''"]+)[''"]') {
                $target = $matches[1]
                $moduleName = ($target -split '/')[0]
                if ($target.StartsWith('@')) { $moduleName = ($target -split '/')[0..1] -join '/' }
                $isNativeModule = Test-IsKnownNative $moduleName
                $existsInProject = (Test-Path (Join-Path $root "node_modules\$moduleName") -ErrorAction SilentlyContinue)
            }
        } elseif ($line -match 'plugins:\s*\[\s*[''"]?([^''"\]]+)[''"]?\s*\]') {
            $target = $matches[1]
        } elseif ($line -match '\.use\s*\(\s*[''"]?([^''")]+)[''"]?\s*\)') {
            $target = $matches[1]
        } elseif ($line -match '\.load\s*\(\s*[''"]?([^''")]+)[''"]?\s*\)') {
            $target = $matches[1]
        }

        # Determine risk
        if ($isNativeModule) {
            $risk = 'might-fail'
            $recommendation = "Verify native module compatibility on target platform"
        } elseif ($existsInProject -eq $false -and $target -match '^\.') {
            $risk = 'will-fail'
            $recommendation = "Referenced local path does not exist in the project tree"
        } elseif ($isDevDep) {
            $risk = 'will-fail'
            $recommendation = "Module is a devDependency - not available at runtime in production"
        } elseif ($existsInProject -eq $false -and -not ($target -match '^\.')) {
            # npm module not found in node_modules
            $risk = 'will-fail'
            $recommendation = "Module not found in project dependencies"
        } elseif ($isComputed) {
            $risk = 'might-fail'
            $recommendation = "Path is computed at runtime - verify that the resolved path exists"
        } elseif ($isPlatformSpecific) {
            $risk = 'might-fail'
            $recommendation = "Platform-specific path - verify availability on all deployment targets"
        } elseif ($existsInProject -eq $true) {
            $risk = 'safe'
            $recommendation = "Deterministic path, resource exists in project"
        } else {
            $risk = 'safe'
            $recommendation = "Deterministic path"
        }

        $loadRefs.Add([ordered]@{
            file               = $relPath
            line               = $i + 1
            type               = ($matchedCategories -join ',')
            target             = $target
            isDeterministic    = -not $isComputed
            existsInProject    = $existsInProject
            isPlatformSpecific = $isPlatformSpecific
            isNativeModule     = $isNativeModule
            isDevDependency    = $isDevDep
            context            = @(Get-Context $lines $i)
            risk               = $risk
            recommendation     = $recommendation
        })
    }
}

$willFail = @($loadRefs | Where-Object { $_.risk -eq 'will-fail' })
$mightFail = @($loadRefs | Where-Object { $_.risk -eq 'might-fail' })
$safe = @($loadRefs | Where-Object { $_.risk -eq 'safe' })

$result = [ordered]@{
    loadRefs     = $loadRefs.ToArray()
    total        = $loadRefs.Count
    willFail     = $willFail.Count
    mightFail    = $mightFail.Count
    safe         = $safe.Count
    scannedFiles = $scannedFiles
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== RUNTIME-LOAD-SCAN ==="
Write-Output "  Scanned files: $scannedFiles"
Write-Output "  Total references: $($loadRefs.Count)"
Write-Output "  Will-fail: $($willFail.Count)"
Write-Output "  Might-fail: $($mightFail.Count)"
Write-Output "  Safe: $($safe.Count)"
