[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "",
    [string]$Exclude = ""
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

function Get-RelativePath($base, $target) {
    $base = $base.TrimEnd('\').TrimEnd('/')
    $targetPath = $target.TrimEnd('\').TrimEnd('/')
    if ($targetPath -eq $base) { return '.' }
    if ($targetPath.StartsWith($base + '\') -or $targetPath.StartsWith($base + '/')) {
        return $targetPath.Substring($base.Length + 1)
    }
    return $targetPath
}

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$sensitivePattern = 'SECRET|TOKEN|KEY|PASSWORD|PWD|CREDENTIAL|API_KEY|PRIVATE|PEM'

$definitions = @()
$reads = @()
$dynamicReads = @()

function Add-Definition($key, $source, $line, $hasValue, $commented, $defaultType) {
    $isSensitive = $key -cmatch $sensitivePattern
    $script:definitions += @{
        key = $key
        source = $source
        line = $line
        hasValue = $hasValue
        commented = $commented -eq $true
        sensitive = $isSensitive
        defaultType = $defaultType
    }
}

function Add-Read($key, $file, $line, $pattern) {
    $script:reads += @{
        key = $key
        file = $file
        line = $line
        pattern = $pattern
    }
}

# --- Definition sources ---

# 1. .env files
Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter ".env*" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { return }
    $relPath = Get-RelativePath $ProjectDir $_.FullName
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed -match '^#') {
            if ($trimmed -match '^#\s*(\w[\w_]*)=(.*)') {
                Add-Definition -key $matches[1] -source $relPath -line $lineNum -hasValue ($matches[2].Trim() -ne '') -commented $true -defaultType $null
            }
            continue
        }
        if ($trimmed -match '^(\w[\w_]*)=(.*)') {
            $val = $matches[2].Trim()
            $hasVal = $val -ne ''
            $type = if (-not $hasVal) { "empty" } elseif ($val -match '^\d+\.?\d*$') { "number" } elseif ($val -match '^(true|false|yes|no)$') { "bool" } else { "string" }
            Add-Definition -key $matches[1] -source $relPath -line $lineNum -hasValue $hasVal -commented $false -defaultType $type
        }
    }
}

# 2. Config files: appsettings*.json, config/**/*.json/yaml/yml/toml
$configFiles = @{}
$configPatterns = @("appsettings*.json", "config\**\*.json", "config\**\*.yaml", "config\**\*.yml", "config\**\*.toml")
foreach ($pat in $configPatterns) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter (Split-Path $pat -Leaf) -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__'
    } | ForEach-Object { $configFiles[$_.FullName] = $_ }
}
$configFiles.Values | ForEach-Object {
    $relPath = Get-RelativePath $ProjectDir $_.FullName
    if ($relPath -match 'docker-compose') { return }
    $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }
    $ext = $_.Extension.ToLower()
    if ($ext -eq '.json') {
        try {
            $parsed = $content | ConvertFrom-Json -ErrorAction Stop
            & {
                function Walk-Json($obj, $prefix) {
                    if ($null -eq $obj) { return }
                    if ($obj -is [PSCustomObject]) {
                        foreach ($prop in $obj.PSObject.Properties) {
                            $path = if ($prefix) { "$prefix.$($prop.Name)" } else { $prop.Name }
                            if ($null -eq $prop.Value -or $prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double]) {
                                $v = $prop.Value
                                $hasV = $null -ne $v
                                $t = if ($null -eq $v) { $null } elseif ($v -is [int] -or $v -is [double]) { "number" } elseif ($v -is [bool]) { "bool" } else { "string" }
                                Add-Definition -key $path -source $relPath -line 0 -hasValue $hasV -commented $false -defaultType $t
                            } else { Walk-Json $prop.Value $path }
                        }
                    } elseif ($obj -is [System.Collections.IDictionary]) {
                        foreach ($kv in $obj.GetEnumerator()) {
                            $path = if ($prefix) { "$prefix.$($kv.Key)" } else { $kv.Key }
                            if ($null -eq $kv.Value -or $kv.Value -is [string] -or $kv.Value -is [int] -or $kv.Value -is [bool] -or $kv.Value -is [double]) {
                                $v = $kv.Value
                                $hasV = $null -ne $v
                                $t = if ($null -eq $v) { $null } elseif ($v -is [int] -or $v -is [double]) { "number" } elseif ($v -is [bool]) { "bool" } else { "string" }
                                Add-Definition -key $path -source $relPath -line 0 -hasValue $hasV -commented $false -defaultType $t
                            } else { Walk-Json $kv.Value $path }
                        }
                    }
                }
                Walk-Json $parsed ""
            }
        }
        catch { }
    } elseif ($ext -in '.yaml', '.yml') {
        $lines = $content -split "`n"
        $lineNum = 0
        $path = @()
        $prevIndent = -1
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed -match '^#') { continue }
            $indent = ($line.Length - $line.TrimStart().Length)
            while ($path.Count -gt 0 -and $indent -le $prevIndent) {
                $path = $path[0..($path.Count - 2)]
                $prevIndent = -1
            }
            $prevIndent = $indent
            if ($trimmed -match '^(\w[\w_]*):\s*(.*)') {
                $key = $matches[1]
                $val = $matches[2].Trim()
                $fullPath = if ($path.Count -gt 0) { ($path + $key) -join '.' } else { $key }
                if ($val -eq '' -or $val -eq '|' -or $val -eq '>') {
                    $path += $key
                } else {
                    $hasV = $val -ne ''
                    $t = if (-not $hasV) { "empty" } elseif ($val -match '^\d+\.?\d*$') { "number" } elseif ($val -match '^(true|false|yes|no)$') { "bool" } else { "string" }
                    Add-Definition -key $fullPath -source $relPath -line $lineNum -hasValue $hasV -commented $false -defaultType $t
                }
            } elseif ($trimmed -match '^-\s+(.*)') {
                $val = $matches[1].Trim()
                if ($val -match '(\w[\w_]*)\s*:\s*(.*)') {
                    $key = $matches[1]
                    $sub = $matches[2].Trim()
                    $fullPath = if ($path.Count -gt 0) { ($path + $key) -join '.' } else { $key }
                    $hasV = $sub -ne ''
                    $t = if (-not $hasV) { "empty" } elseif ($sub -match '^\d+\.?\d*$') { "number" } elseif ($sub -match '^(true|false|yes|no)$') { "bool" } else { "string" }
                    Add-Definition -key $fullPath -source $relPath -line $lineNum -hasValue $hasV -commented $false -defaultType $t
                }
            }
        }
    } elseif ($ext -eq '.toml') {
        $lines = $content -split "`n"
        $lineNum = 0
        $tomlSection = ""
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed -match '^#|^//') { continue }
            if ($trimmed -match '^\[(.+)\]') { $tomlSection = $matches[1]; continue }
            if ($trimmed -match '^(\w[\w_]*)\s*=\s*(.*)') {
                $key = $matches[1]; $val = $matches[2].Trim()
                $fullKey = if ($tomlSection) { "$tomlSection.$key" } else { $key }
                $hasV = $val -ne ''
                $t = if (-not $hasV) { "empty" } elseif ($val -match '^\d+\.?\d*$') { "number" } elseif ($val -match '^(true|false)$') { "bool" } else { "string" }
                Add-Definition -key $fullKey -source $relPath -line $lineNum -hasValue $hasV -commented $false -defaultType $t
            }
        }
    }
}

# 3. docker-compose*.yml
Get-ChildItem -LiteralPath $ProjectDir -Filter "docker-compose*.yml" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $relPath = Get-RelativePath $ProjectDir $_.FullName
    $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }
    $lineNum = 0
    $envSection = $false
    $serviceName = ""
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNum = $i + 1
        $line = $lines[$i].Trim()
        if ($line -match '^environment:') { $envSection = $true; continue }
        if ($envSection -and $lines[$i] -notmatch '^\s') { $envSection = $false; continue }
        if ($envSection -and $line -match '^\s{4,}-\s*(\w[\w_]*)') {
            $ekey = $matches[1]
            Add-Definition -key $ekey -source "$relPath`:$serviceName" -line $lineNum -hasValue $true -commented $false -defaultType $null
        } elseif ($envSection -and $line -match '^\s{4,}(\w[\w_]*):\s*(.*)') {
            $ekey = $matches[1]
            $eval = $matches[2].Trim()
            $hasV = $eval -ne '' -and $eval -notmatch '^\$\{'
            Add-Definition -key $ekey -source "$relPath`:$serviceName" -line $lineNum -hasValue $hasV -commented $false -defaultType $null
        }
        if ($line -match '^\s{2}(\w[\w_-]*):') { $serviceName = $matches[1] }
    }
}

# 4. Dockerfile*
Get-ChildItem -LiteralPath $ProjectDir -Filter "Dockerfile*" -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -notmatch 'node_modules|\.git'
} | ForEach-Object {
    $relPath = Get-RelativePath $ProjectDir $_.FullName
    $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { return }
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if ($trimmed -match '^ENV\s+(\w[\w_]*)\s*=\s*(.*)') {
            Add-Definition -key $matches[1] -source $relPath -line $lineNum -hasValue ($matches[2].Trim() -ne '') -commented $false -defaultType $null
        } elseif ($trimmed -match '^ENV\s+(\w[\w_]*)\s+(.*)') {
            Add-Definition -key $matches[1] -source $relPath -line $lineNum -hasValue ($matches[2].Trim() -ne '') -commented $false -defaultType $null
        }
    }
}

# --- Read sites in code ---

$codeExtensions = @('*.ps1','*.py','*.js','*.ts','*.jsx','*.tsx','*.rb','*.php','*.java','*.go','*.cs','*.rs','*.swift','*.kt')
foreach ($ext in $codeExtensions) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__'
    } | ForEach-Object {
        $relFile = Get-RelativePath $ProjectDir $_.FullName
        $content = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $lineNum = 0
        foreach ($line in $content) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '^#|^\/\/|^--|^\*|^\s*$') { continue }

            # process.env.KEY / process.env["KEY"]
            if ($_.Extension -in '.js','.ts','.jsx','.tsx','.mjs','.cjs') {
                if ($trimmed -match 'process\.env\.(\w+)') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "process.env.$($matches[1])"
                }
                if ($trimmed -match "process\.env\s*\[\s*['""]([\w_]+)['""]\s*\]") {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "process.env[]"
                }
                if ($trimmed -match '\{\s*([\w,\s]+)\s*\}\s*=\s*process\.env') {
                    $matches[1] -split ',' | ForEach-Object {
                        $k = $_.Trim()
                        if ($k) { Add-Read -key $k -file $relFile -line $lineNum -pattern "destructure" }
                    }
                }
                # dynamic import for non-literal keys
                if ($trimmed -match 'process\.env\s*\[([^''""]\w+)') {
                    $dynamicReads += @{ file = $relFile; line = $lineNum }
                }
            }

            # os.environ["KEY"]
            if ($_.Extension -eq '.py') {
                if ($trimmed -match "os\.environ\s*\[\s*['""]([\w_]+)['""]\s*\]") {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "os.environ[]"
                }
                if ($trimmed -match "os\.getenv\s*\(\s*['""]([\w_]+)['""]") {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "os.getenv()"
                }
                if ($trimmed -match "os\.environ\.get\s*\(\s*['""]([\w_]+)['""]") {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "os.environ.get()"
                }
            }

            # env::var for Rust
            if ($_.Extension -eq '.rs') {
                if ($trimmed -match 'env::var\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "env::var()"
                }
            }

            # os.Getenv / os.LookupEnv for Go
            if ($_.Extension -eq '.go') {
                if ($trimmed -match '(?:os\.Getenv|os\.LookupEnv)\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "os.Getenv()"
                }
            }

            # System.getenv for Java
            if ($_.Extension -eq '.java') {
                if ($trimmed -match 'System\.getenv\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "System.getenv()"
                }
            }

            # IConfiguration / .NET
            if ($_.Extension -eq '.cs') {
                if ($trimmed -match 'IConfiguration\[\s*["\x27]([\w:]+)["\x27]\s*\]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "IConfiguration[]"
                }
                if ($trimmed -match '\.GetSection\s*\(\s*["\x27]([\w:]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "GetSection()"
                }
            }

            # env() / getenv() generic (only for languages without specific handler)
            if ($_.Extension -notin '.py','.js','.ts','.jsx','.tsx','.go','.java','.cs','.rs','.rb','.php','.swift','.kt','.ps1') {
                if ($trimmed -match '(?:getenv|env)\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "getenv/env()"
                }
                if ($trimmed -match 'config\.(?:get|get_string|get_bool|get_int)\s*\(\s*["\x27]([\w_.]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "config.get()"
                }
            }
            # $env:KEY for PS1
            if ($_.Extension -eq '.ps1') {
                if ($trimmed -match '\$env:(\w+)') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern '$env:'
                }
            }
            # $_SERVER / $_ENV for PHP
            if ($_.Extension -eq '.php') {
                if ($trimmed -match '\$_SERVER\[\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern '$_SERVER[]'
                }
                if ($trimmed -match '\$_ENV\[\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern '$_ENV[]'
                }
                if ($trimmed -match 'getenv\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "getenv()"
                }
            }
            # Env.get / Env.string for Ruby
            if ($_.Extension -eq '.rb') {
                if ($trimmed -match 'ENV\[\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern 'ENV[]'
                }
            }
            # Process.env / System.getenv for Swift
            if ($_.Extension -eq '.swift') {
                if ($trimmed -match 'ProcessInfo\.process\.environment\[\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "ProcessInfo.environment[]"
                }
            }
            # System.getenv for Kotlin
            if ($_.Extension -eq '.kt') {
                if ($trimmed -match '(?:System\.getenv|System\.getProperty)\s*\(\s*["\x27]([\w_]+)["\x27]') {
                    Add-Read -key $matches[1] -file $relFile -line $lineNum -pattern "System.getenv()"
                }
            }
        }
    }
}

# --- Output ---
$distinctKeys = @(($definitions | ForEach-Object { $_.key }) + ($reads | ForEach-Object { $_.key }) | Select-Object -Unique)

$result = @{
    definitions = $definitions
    reads = $reads
    dynamicReads = $dynamicReads
    counts = @{
        definitions = $definitions.Count
        reads = $reads.Count
        distinctKeys = $distinctKeys.Count
        dynamicReads = $dynamicReads.Count
    }
}

$json = $result | ConvertTo-Json -Depth 10
Write-Output $json
exit 0
