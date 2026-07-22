param(
    [string]$ProjectDir,
    [string]$Ref = ""
)

$pdir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $pdir) { Write-Error "Path not found: $ProjectDir"; exit 1 }
$pdir = $pdir.Path

# Working tree or git ref mode
$useRef = $Ref -ne ""

if ($useRef) {
    # Verify ref exists
    $check = git -C $pdir rev-parse --verify "$Ref^{object}" 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "Invalid ref: $Ref"; exit 1 }

    # Get file list from ref
    $files = git -C $pdir ls-tree -r $Ref --name-only 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to list ref: $Ref"; exit 1 }
} else {
    # Working tree: find files via Get-ChildItem
    $exts = @('*.js','*.ts','*.tsx','*.jsx','*.py','*.cs','*.go','*.java','*.rb','*.php','*.kt','*.swift','*.graphql','*.proto')
    $files = @()
    foreach ($ext in $exts) {
        Get-ChildItem -LiteralPath $pdir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__'
        } | ForEach-Object { $files += $_.FullName }
    }
}

$routes = @()
$dtos = @()
$signatures = @()
$openapiFiles = @()

function Get-Rel($base, $target) {
    $b = $base.TrimEnd('\')
    $t = $target.TrimEnd('\')
    if ($t -eq $b) { return '.' }
    if ($t.StartsWith($b + '\')) { return $t.Substring($b.Length + 1) }
    return $t
}

# Process each file
foreach ($f in $files) {
    $content = ""
    $filePath = ""
    $relPath = ""

    if ($useRef) {
        $filePath = $f  # relative path from git ls-tree
        $relPath = $f
        $lines = git -C $pdir show "$Ref`:$f" 2>&1
        if ($LASTEXITCODE -ne 0) { continue }
        $content = $lines -join "`n"
    } else {
        $filePath = $f
        $relPath = Get-Rel $pdir $f
        $content = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    }

    # Detect extension
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()

    # 1. OpenAPI/Swagger files
    $fileName = [System.IO.Path]::GetFileName($filePath).ToLower()
    if ($fileName -match '^(openapi|swagger)' -and $ext -in '.json','.yaml','.yml') {
        $openapiFiles += $relPath
        # Parse basic OpenAPI structure
        if ($ext -eq '.json') {
            try {
                $parsed = $content | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($parsed.paths) {
                    foreach ($path in $parsed.paths.PSObject.Properties) {
                        $routePath = $path.Name
                        foreach ($method in $path.Value.PSObject.Properties) {
                            if ($method.Name -match '^(get|post|put|delete|patch|head|options)$') {
                                $params = @()
                                if ($method.Value.parameters) {
                                    foreach ($p in $method.Value.parameters) {
                                        $required = $p.required -eq $true
                                        $params += "$($p.name):$($p.in)" + $(if ($required) { "" } else { "?" })
                                    }
                                }
                                $routes += @{ method = $method.Name.ToUpper(); path = $routePath; params = $params; source = "openapi"; file = $relPath; line = 0 }
                            }
                        }
                    }
                }
                # Extract schemas as DTOs
                if ($parsed.components -and $parsed.components.schemas) {
                    foreach ($schema in $parsed.components.schemas.PSObject.Properties) {
                        $fields = @()
                        if ($schema.Value.properties) {
                            foreach ($prop in $schema.Value.properties.PSObject.Properties) {
                                $opt = -not ($schema.Value.required -contains $prop.Name)
                                $type = if ($prop.Value.type) { $prop.Value.type } else { "object" }
                                $fields += @{ name = $prop.Name; type = $type; optional = $opt }
                            }
                        }
                        $dtos += @{ name = $schema.Name; fields = $fields; source = "openapi"; file = $relPath }
                    }
                }
            } catch {}
        }
        continue
    }

    # Skip non-code files
    if ($ext -notin '.js','.ts','.tsx','.jsx','.py','.cs','.go','.java','.rb','.php','.kt','.swift','.graphql','.proto') { continue }

    $lines = $content -split "`r`n|`n"

    # 2. Code routes (Express/Hono/Fastify style)
    if ($ext -in '.js','.ts','.tsx','.jsx') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '(?:router|app|server|route)\s*\.\s*(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1].ToUpper()
                $rpath = $matches[2]
                $routes += @{ method = $meth; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # Flask/FastAPI style
    if ($ext -eq '.py') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '@\w+\.route\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $rpath = $matches[1]
                $routes += @{ method = "ANY"; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            } elseif ($trimmed -match '@\w+\.(get|post|put|delete|patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1].ToUpper()
                $rpath = $matches[2]
                $routes += @{ method = $meth; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # ASP.NET Core / C# attribute routing
    if ($ext -eq '.cs') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '\[Http(Get|Post|Put|Delete|Patch)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1].ToUpper()
                $rpath = $matches[2]
                $routes += @{ method = $meth; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            } elseif ($trimmed -match '\[Route\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $routes += @{ method = "ANY"; path = $matches[1]; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # Go router (mux/gin/echo)
    if ($ext -eq '.go') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '\.(GET|POST|PUT|DELETE|PATCH)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1]
                $rpath = $matches[2]
                $routes += @{ method = $meth; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # Java Spring
    if ($ext -eq '.java') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\s*\(\s*["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1] -replace 'Mapping',''
                $rpath = $matches[2]
                $routes += @{ method = $meth.ToUpper(); path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # Ruby on Rails / Sinatra
    if ($ext -eq '.rb') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '\b(get|post|put|delete|patch)\s+["\x27]([^"\x27]+)["\x27]') {
                $meth = $matches[1].ToUpper()
                $rpath = $matches[2]
                $routes += @{ method = $meth; path = $rpath; params = @(); source = "code"; file = $relPath; line = $lineNum }
            }
        }
    }

    # 3. DTO/Types (interface/type/class with Dto/Request/Response/Model/Payload suffix)
    $dtoMatch = [regex]::Match($content, '(?:interface|type|class|record)\s+(\w*(?:Dto|DTO|Request|Response|Model|Payload|ViewModel|Command|Event))\b')
    while ($dtoMatch.Success) {
        $dtoName = $dtoMatch.Groups[1].Value
        $dtoLine = $content.Substring(0, $dtoMatch.Index).Split("`n").Length
        $fields = @()

        # Find the block content
        $blockStart = $content.IndexOf('{', $dtoMatch.Index)
        if ($blockStart -ge 0) {
            $depth = 0
            $blockEnd = $blockStart
            for ($j = $blockStart; $j -lt $content.Length; $j++) {
                if ($content[$j] -eq '{') { $depth++ }
                elseif ($content[$j] -eq '}') { $depth-- }
                if ($depth -eq 0) { $blockEnd = $j; break }
            }
            $blockText = $content.Substring($blockStart, $blockEnd - $blockStart + 1)
            $blockLines = $blockText -split "`n"
            foreach ($bl in $blockLines) {
                $blt = $bl.Trim()
                if ($blt -match '^\s*(\w[\w?]*)\s*[:?]\s*(.+?)\s*[;,]?\s*$' -and $blt -notmatch '^{|^}|^import|^export|^interface|^type|^class|^record|^constructor|^new\b|extends|implements') {
                    $fname = $matches[1].TrimEnd('?')
                    $ftype = $matches[2].Trim()
                    $fopt = $matches[1].EndsWith('?') -or $ftype -match '\bnull\b|undefined|Optional'
                    $fields += @{ name = $fname; type = $ftype; optional = $fopt }
                }
            }
        }
        $dtos += @{ name = $dtoName; fields = $fields; source = "code"; file = $relPath; line = $dtoLine }
        $dtoMatch = $dtoMatch.NextMatch()
    }

    # 4. Exported function signatures (library API)
    if ($ext -in '.js','.ts','.tsx','.jsx') {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            $trimmed = $line.Trim()
            if ($trimmed -match '^export\s+(default\s+)?function\s+(\w+)\s*\(([^)]*)') {
                $fname = $matches[2]
                $fparams = $matches[3].Trim()
                $sigLine = $lineNum
                # Get return type from next line or same line
                $returnType = ""
                if ($trimmed -match '\)\s*:\s*(\S+)') { $returnType = $matches[1] }
                $signatures += @{ name = $fname; params = $fparams; returnType = $returnType; file = $relPath; line = $sigLine }
            }
        }
    }
}

# Dedup routes
$uniqueRoutes = @{}
$dedupedRoutes = @()
foreach ($r in $routes) {
    $key = "$($r.method)|$($r.path)"
    if (-not $uniqueRoutes.ContainsKey($key)) {
        $uniqueRoutes[$key] = $true
        $dedupedRoutes += $r
    }
}

$result = @{
    ref = if ($useRef) { $Ref } else { "working-tree" }
    source = if ($openapiFiles.Count -gt 0) { "openapi+code" } else { "code" }
    routes = $dedupedRoutes
    dtos = $dtos
    signatures = $signatures
    openapiFiles = $openapiFiles
    counts = @{ routes = $dedupedRoutes.Count; dtos = $dtos.Count; signatures = $signatures.Count; openapiFiles = $openapiFiles.Count }
}

Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
