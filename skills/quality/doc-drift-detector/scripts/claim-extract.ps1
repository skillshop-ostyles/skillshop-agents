[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$DocGlobs = @('README*', '*.md', 'docs/**/*.md', 'CONTRIBUTING*'),
    [int]$MaxClaims = 500
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path

# -- Collect doc files: README*/CONTRIBUTING*/*.md in root + docs/**/*.md recursively --
$rootFiles = @(
    Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)^(README|CONTRIBUTING)' -or $_.Extension -eq '.md' }
)
$docsDir = Join-Path $root 'docs'
$nestedFiles = @()
if (Test-Path -LiteralPath $docsDir) {
    $nestedFiles = @(Get-ChildItem -LiteralPath $docsDir -File -Recurse -Filter '*.md' -ErrorAction SilentlyContinue)
}
$seenPaths = New-Object System.Collections.Generic.HashSet[string]
$docFileInfos = New-Object System.Collections.Generic.List[object]
foreach ($f in ($rootFiles + $nestedFiles)) {
    if ($seenPaths.Add($f.FullName)) { $docFileInfos.Add($f) }
}

if ($docFileInfos.Count -eq 0) {
    $empty = [ordered]@{
        docFiles      = @()
        claims        = @()
        countsByType  = [ordered]@{ path = 0; command = 0; config = 0; endpoint = 0; version = 0; symbol = 0 }
        truncated     = $false
    }
    Write-Output (ConvertTo-Json $empty -Depth 6)
    Write-Output "`nKeine Doku-Dateien gefunden (README*/*.md/docs/**/*.md/CONTRIBUTING*) unter: $root"
    exit 0
}

# -- Regexe je Claim-Typ --
$backtickRegex = '`([^`\r\n]+)`'
$pathLikeRegex = '[\\/]|\.[A-Za-z0-9]{1,6}$'
$configUpperRegex = '^[A-Z0-9]+(_[A-Z0-9]+){2,}$'
$configKnownPrefixRegex = '^(NODE_|NEXT_PUBLIC_|VITE_|REACT_APP_|DATABASE_|API_|AWS_|GITHUB_|CLOUDFLARE_)[A-Z0-9_]+$'
$configContextLineRegex = '(?i)\b(config|env|setting|variable|umgebungsvariable)\w*\b'
$commandFenceLang = '(?i)^(bash|sh|shell|powershell|ps1|console|cmd)$'
$commandLineStartRegex = '^\s*[$>]?\s*(npm|yarn|pnpm|pip|python|dotnet|go|cargo|make|git)\s'
$endpointRegex = '(GET|POST|PUT|DELETE|PATCH)\s+(/[\w/{}:.-]*)'
$endpointApiPathRegex = '(?<![\w])(/api/[\w/{}:.-]*)'
$versionRegex = '(?i)\b(node|python|dotnet|go|java|npm)\b[^\n]{0,20}?(\d+(\.\d+)*)'
$versionRequiresRegex = '(?i)\brequires\b[^\n]{0,40}?\d+(\.\d+)*'
$symbolIdentRegex = '^[A-Za-z_][A-Za-z0-9_]*$'
$camelRegex = '[a-z][A-Z]'
$snakeLowerRegex = '^[a-z][a-z0-9]*(_[a-z0-9]+)+$'

$priority = @{ 'command' = 0; 'path' = 1; 'endpoint' = 2; 'config' = 3; 'version' = 4; 'symbol' = 5 }
$claimMap = [ordered]@{}

function Add-Claim($type, $text, $doc, $line) {
    $key = "$type|$text"
    if ($claimMap.Contains($key)) {
        $claimMap[$key].occurrences += 1
    } else {
        $claimMap[$key] = [ordered]@{
            type = $type; text = $text; doc = $doc; line = $line; occurrences = 1
        }
    }
}

foreach ($docFile in $docFileInfos) {
    $relDoc = $docFile.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = @(Get-Content -LiteralPath $docFile.FullName -ErrorAction SilentlyContinue)

    $inFence = $false
    $fenceIsCommandLang = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        # Fenced-Code-Bloecke erkennen (```lang ... ```)
        if ($line -match '^\s*```\s*([A-Za-z0-9]*)\s*$') {
            if (-not $inFence) {
                $inFence = $true
                $fenceIsCommandLang = ($matches[1] -match $commandFenceLang)
            } else {
                $inFence = $false
                $fenceIsCommandLang = $false
            }
            continue
        }

        # -- 2. Kommandos --
        if ($inFence -and $fenceIsCommandLang) {
            $trimmed = $line.Trim()
            if ($trimmed -ne '' -and $trimmed -notmatch '^#') {
                Add-Claim 'command' $trimmed $relDoc $lineNum
            }
        } elseif (-not $inFence -and $line -match $commandLineStartRegex) {
            Add-Claim 'command' $line.Trim() $relDoc $lineNum
        }

        # -- Backtick tokens: path / config / symbol --
        foreach ($m in [regex]::Matches($line, $backtickRegex)) {
            $token = $m.Groups[1].Value.Trim()
            if ($token -eq '') { continue }
            if ($token -match $commandLineStartRegex) { continue }

            if ($token -match $pathLikeRegex) {
                Add-Claim 'path' $token $relDoc $lineNum
            } elseif (($token -match $configUpperRegex) -or ($token -match $configKnownPrefixRegex)) {
                Add-Claim 'config' $token $relDoc $lineNum
            } elseif ($token -match $symbolIdentRegex -and (($token -match $camelRegex) -or ($token -match $snakeLowerRegex))) {
                Add-Claim 'symbol' $token $relDoc $lineNum
            }
        }

        # -- Config/Env ausserhalb Backticks in Config-Kontext-Zeilen --
        if ($line -match $configContextLineRegex) {
            foreach ($m in [regex]::Matches($line, '\b[A-Z0-9]+(_[A-Z0-9]+)+\b')) {
                $tok = $m.Value
                if (($tok -match $configUpperRegex) -or ($tok -match $configKnownPrefixRegex)) {
                    Add-Claim 'config' $tok $relDoc $lineNum
                }
            }
        }

        # -- 4. Endpoints --
        foreach ($m in [regex]::Matches($line, $endpointRegex)) {
            Add-Claim 'endpoint' ($m.Groups[1].Value + ' ' + $m.Groups[2].Value) $relDoc $lineNum
        }
        foreach ($m in [regex]::Matches($line, $endpointApiPathRegex)) {
            Add-Claim 'endpoint' $m.Groups[1].Value $relDoc $lineNum
        }

        # -- 5. Versionen --
        $vm = [regex]::Match($line, $versionRegex)
        if ($vm.Success) {
            Add-Claim 'version' $vm.Value.Trim() $relDoc $lineNum
        }
        $rm = [regex]::Match($line, $versionRequiresRegex)
        if ($rm.Success) {
            Add-Claim 'version' $rm.Value.Trim() $relDoc $lineNum
        }
    }
}

# -- Count per type: complete, independent of truncation --
$countsByType = [ordered]@{ path = 0; command = 0; config = 0; endpoint = 0; version = 0; symbol = 0 }
foreach ($c in $claimMap.Values) { $countsByType[$c.type] += 1 }

# -- Selection for output: prioritize command/path when truncating --
$ordered = @($claimMap.Values | Sort-Object -Property @{Expression = { $priority[$_.type] }}, doc, line)
$truncated = $ordered.Count -gt $MaxClaims
$outClaims = if ($truncated) { $ordered[0..($MaxClaims - 1)] } else { $ordered }

$result = [ordered]@{
    docFiles     = @($docFileInfos | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') })
    claims       = @($outClaims)
    countsByType = $countsByType
    truncated    = $truncated
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== DOC-DRIFT: CLAIM-EXTRACT ==="
Write-Output "  Doku-Dateien: $($docFileInfos.Count)"
foreach ($k in $countsByType.Keys) { Write-Output "  ${k}: $($countsByType[$k])" }
Write-Output "  Gekappt: $truncated"
