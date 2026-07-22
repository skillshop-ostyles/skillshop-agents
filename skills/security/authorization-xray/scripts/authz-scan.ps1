[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$pdir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $pdir) { Write-Error "Path not found: $ProjectDir"; exit 1 }
$pdir = $pdir.Path

$endpoints = @()
$globalUse = @()
$inlineChecks = @()
$scannedFiles = 0

$exts = @('*.js','*.ts','*.tsx','*.jsx','*.py','*.cs','*.go','*.java','*.rb','*.php')

foreach ($ext in $exts) {
    Get-ChildItem -LiteralPath $pdir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $lines = $content -split "`r`n|`n"
        $rel = $fp.Substring($pdir.Length).TrimStart('\')
        $ext = $_.Extension.ToLower()

        # 1. Routes
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed -match '^(#|//|--|\*)') { continue }

            $method = $null
            $path = $null

            # Express-style: router.get/post/put/delete/patch
            if ($trimmed -match '(?:router|app|server|route)\s*\.\s*(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $method = $matches[1].ToUpper()
                $path = $matches[2]
            }
            # Flask/FastAPI
            elseif ($ext -eq '.py') {
                if ($trimmed -match '@\w+\.(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = $matches[1].ToUpper()
                    $path = $matches[2]
                } elseif ($trimmed -match '@\w+\.route\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = "ANY"
                    $path = $matches[1]
                }
            }
            # ASP.NET / C#
            elseif ($ext -eq '.cs') {
                if ($trimmed -match '\[Http(Get|Post|Put|Delete|Patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = $matches[1].ToUpper()
                    $path = $matches[2]
                } elseif ($trimmed -match '\[Route\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = "ANY"
                    $path = $matches[1]
                }
            }
            # Go: .GET/POST/PUT/DELETE/PATCH(...)
            elseif ($ext -eq '.go') {
                if ($trimmed -match '\.(GET|POST|PUT|DELETE|PATCH)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = $matches[1]
                    $path = $matches[2]
                }
            }
            # Java Spring
            elseif ($ext -eq '.java') {
                if ($trimmed -match '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $methMap = @{ GetMapping = 'GET'; PostMapping = 'POST'; PutMapping = 'PUT'; DeleteMapping = 'DELETE'; PatchMapping = 'PATCH' }
                    $method = $methMap[$matches[1]]
                    $path = $matches[2]
                }
            }
            # Ruby
            elseif ($ext -eq '.rb') {
                if ($trimmed -match '\b(get|post|put|delete|patch)\s+["\x27]([^"\x27]+)["\x27]') {
                    $method = $matches[1].ToUpper()
                    $path = $matches[2]
                }
            }
            # PHP
            elseif ($ext -eq '.php') {
                if ($trimmed -match '\$router->(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $method = $matches[1].ToUpper()
                    $path = $matches[2]
                }
            }

            if (-not $method -or -not $path) { continue }

            # Route-level guards: middleware args before handler
            $routeGuards = @()
            if ($ext -in '.js','.ts','.tsx','.jsx') {
                $rest = $trimmed
                # Extract middleware args: after path, comma-separated, before handler
                if ($rest -match '["\x27][^"\x27]+["\x27],\s*(.+),\s*(?:async\s*)?\(') {
                    $midText = $matches[1]
                    if ($midText -match '\b(\w+Auth|\w+Guard|\w+Middleware|auth|requireAuth|authenticate|authorize)\b') {
                        $routeGuards += $matches[1]
                    }
                    # Multiple guards
                    $guardMatches = [regex]::Matches($midText, '\b(\w+)\b')
                    foreach ($gm in $guardMatches) {
                        $g = $gm.Groups[1].Value
                        if ($g -match 'Auth|Guard|Middleware|auth|require|authenticate|authorize|role|permission') {
                            $routeGuards += $g
                        }
                    }
                }
            }

            # Decorators (from lines above)
            $decorators = @()
            for ($j = [Math]::Max(0, $lineNum - 5); $j -lt $lineNum; $j++) {
                $prevLine = $lines[$j].Trim()
                if ($prevLine -match '@(UseGuards|Roles|Authorize|login_required|permission_required|PreAuthorize|Secured)\s*(?:\(([^)]*)\))?') {
                    $decName = $matches[1]
                    $decArgs = if ($matches[2]) { $matches[2].Trim() } else { "" }
                    $decorators += "$decName($decArgs)"
                }
                elseif ($ext -eq '.cs' -and $prevLine -match '\[Authorize\s*(?:\(([^)]*)\))?\]') {
                    $decorators += "Authorize($($matches[1]))"
                }
                elseif ($ext -eq '.py' -and $prevLine -match '@login_required|@permission_required') {
                    $decorators += $prevLine -replace '^@', ''
                }
                # Java annotations
                elseif ($ext -eq '.java' -and $prevLine -match '@PreAuthorize\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $decorators += "PreAuthorize($($matches[1]))"
                }
                elseif ($ext -eq '.java' -and $prevLine -match '@Secured\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                    $decorators += "Secured($($matches[1]))"
                }
            }

            # Explicit public?
            $explicitlyPublic = $false
            for ($j = [Math]::Max(0, $lineNum - 5); $j -lt $lineNum; $j++) {
                $prevLine = $lines[$j].Trim()
                if ($prevLine -match 'AllowAnonymous|@Public|skipAuth') { $explicitlyPublic = $true }
            }

            $endpoints += @{
                method = $method
                path = $path
                file = $rel
                line = $lineNum
                mutating = $method -in 'POST','PUT','PATCH','DELETE'
                routeGuards = $routeGuards
                decorators = $decorators
                explicitlyPublic = $explicitlyPublic
            }
        }

        # 2. Global mounts: app.use / router.use
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '(?:app|router)\.use\s*\(\s*["\x27]([^"\x27]+)["\x27]\s*,\s*(\w+)') {
                $globalUse += @{ file = $rel; line = $lineNum; mountPath = $matches[1]; args = @($matches[2]) }
            } elseif ($trimmed -match '(?:app|router)\.use\s*\(\s*(\w+)') {
                $globalUse += @{ file = $rel; line = $lineNum; mountPath = "/"; args = @($matches[1]) }
            }
        }

        # 3. Inline auth checks in handler files
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '\b(role|permission|isAdmin|hasRole|can|ability|policy)\b') {
                $inlineChecks += @{ file = $rel; line = $lineNum; text = $trimmed.Substring(0, [Math]::Min(100, $trimmed.Length)) }
            }
        }
    }
}

$result = @{
    endpoints = $endpoints
    globalUse = $globalUse
    inlineChecks = $inlineChecks
    counts = @{
        endpoints = $endpoints.Count
        mutating = @($endpoints | Where-Object { $_.mutating }).Count
        globalMounts = $globalUse.Count
        inlineChecks = $inlineChecks.Count
    }
    scannedFiles = $scannedFiles
}

Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
