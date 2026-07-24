[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @("py","js","ts","jsx","tsx","cs","java","rb","rs","go"),

    [string[]]$Exclude = @()
)

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$ProjectDirPath = Convert-Path -LiteralPath $ProjectDir

$includePatterns = $Extensions | ForEach-Object { "*.$_" }

if ($Exclude.Count -gt 0) {
    $excludePattern = $Exclude -join "|"
    $files = Get-ChildItem -Path $ProjectDirPath -Recurse -File -Include $includePatterns `
        | Where-Object { $_.DirectoryName -notmatch $excludePattern }
    $promptFiles = Get-ChildItem -Path $ProjectDirPath -Recurse -File -Include @("*.prompt", "*.prmpt") `
        | Where-Object { $_.DirectoryName -notmatch $excludePattern }
} else {
    $files = Get-ChildItem -Path $ProjectDirPath -Recurse -File -Include $includePatterns
    $promptFiles = Get-ChildItem -Path $ProjectDirPath -Recurse -File -Include @("*.prompt", "*.prmpt")
}

$formatSpecPattern      = '\b(json|xml|markdown|format|schema)\b'
$safetyInstructionPattern = '\b(harmful|safe|ethical|honest|guidelines|policy|rules)\b'
$dynamicContextPattern  = '\{[\w\.]+\}'
$userInputVarPattern    = '\b(input|message|query|user_text|question)\b'

function Classify-Content {
    param([string]$Content)
    $hasFmt   = [regex]::IsMatch($Content, $formatSpecPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $hasSafe  = [regex]::IsMatch($Content, $safetyInstructionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $hasDyn   = [regex]::IsMatch($Content, $dynamicContextPattern)
    $hasInput = [regex]::IsMatch($Content, $userInputVarPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $class = "open-ended"
    if ($hasInput) { $class = "injection-susceptible" }
    elseif ($hasFmt -and $hasSafe) { $class = "structured" }
    elseif ($hasFmt -or $hasSafe) { $class = "semi-structured" }
    return @{ hasFormatSpec=$hasFmt; hasSafetyInstructions=$hasSafe; usesDynamicContext=$hasDyn; includesUserInput=$hasInput; classification=$class }
}

function Add-Match {
    param($File, $Line, $Type, $Role, $Content, $PreClassified)
    if ($PreClassified) {
        $cls = $PreClassified
    } else {
        $cls = Classify-Content -Content $Content
    }
    return @{
        File   = $File
        Line   = $Line
        Type   = $Type
        Role   = $Role
        Content = $Content
        hasFormatSpec          = $cls.hasFormatSpec
        hasSafetyInstructions  = $cls.hasSafetyInstructions
        usesDynamicContext     = $cls.usesDynamicContext
        includesUserInput      = $cls.includesUserInput
        classification         = $cls.classification
    }
}

$allMatches = @()

# --- prompt files (*.prompt, *.prmpt) ---
foreach ($file in $promptFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    $allMatches += Add-Match -File $file.FullName -Line 1 -Type "prompt-file" -Role "system" -Content $content
}

# --- source files ---
foreach ($file in $files) {
    $lines      = Get-Content -LiteralPath $file.FullName -Encoding utf8
    $fileContent = $lines -join "`n"
    $filePath   = $file.FullName

    # 1) f-strings: f"text {var} text"
    $fStringMatches = [regex]::Matches($fileContent, 'f"[^"]*\{[^}]+}[^"]*"')
    foreach ($m in $fStringMatches) {
        $lineNo = ($fileContent.Substring(0, $m.Index).Split("`n").Length)
        $allMatches += Add-Match -File $filePath -Line $lineNo -Type "template" -Role "user" -Content $m.Value
    }

    # 2) .format(): "text {var} text".format(
    $formatMatches = [regex]::Matches($fileContent, '"[^"]*\{[^}]+}[^"]*"\s*\.\s*format\(')
    foreach ($m in $formatMatches) {
        $lineNo = ($fileContent.Substring(0, $m.Index).Split("`n").Length)
        $allMatches += Add-Match -File $filePath -Line $lineNo -Type "template" -Role "user" -Content $m.Value
    }

    # 3) $variable interpolation: "text $var text"
    $dollarVarMatches = [regex]::Matches($fileContent, '"[^"]*\$\w+[^"]*"')
    foreach ($m in $dollarVarMatches) {
        $lineNo = ($fileContent.Substring(0, $m.Index).Split("`n").Length)
        $allMatches += Add-Match -File $filePath -Line $lineNo -Type "template" -Role "user" -Content $m.Value
    }

    # 4) ChatPromptTemplate.from_messages
    $cptMatches = [regex]::Matches($fileContent, 'ChatPromptTemplate\.from_messages\(\[([^\]]+)\]')
    foreach ($m in $cptMatches) {
        $lineNo  = ($fileContent.Substring(0, $m.Index).Split("`n").Length)
        $content = $m.Groups[1].Value
        $pairMatches = [regex]::Matches($content, '\(\s*"(system|human|user|ai|assistant)"\s*,\s*"([^"]*)"\s*\)')
        foreach ($pm in $pairMatches) {
            $role = $pm.Groups[1].Value
            $role = switch ($role) {
                "human" { "user" }
                "ai"    { "assistant" }
                default { $role }
            }
            $promptContent = $pm.Groups[2].Value
            $allMatches += Add-Match -File $filePath -Line $lineNo -Type $role -Role $role -Content $promptContent
        }
    }

    # 5) Inline {"role":..., "content":...} message arrays
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $role = "unknown"
        if ($line -match '\"role\":\s*\"(system|user|assistant|tool)\"') {
            $role = $matches[1]
        }
        if ($line -match '\"content\":\s*\"([^"]*)\"') {
            $content = $matches[1]
            if ($content.Trim().Length -gt 0) {
                $allMatches += Add-Match -File $filePath -Line ($i + 1) -Type $role -Role $role -Content $content
            }
        }
    }

    # 6) Unquoted content variable: "content": variable_name
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '\"content\":\s*(\w+)') {
            $varName = $matches[1]
            if ($varName -ne "null" -and $varName -ne "None" -and $varName -ne "undefined") {
                $allMatches += Add-Match -File $filePath -Line ($i + 1) -Type "template" -Role "user" -Content "user_input_variable: $varName"
            }
        }
    }

    # 7) String concatenation: "prefix " + variable (inside messages context)
    $concatMatches = [regex]::Matches($fileContent, '"[^"]*"\s*\+')
    foreach ($m in $concatMatches) {
        $lineNo = ($fileContent.Substring(0, $m.Index).Split("`n").Length)
        $ctxStart = [Math]::Max(0, $m.Index - 200)
        $ctxEnd   = [Math]::Min($fileContent.Length, $m.Index + 200)
        $ctx = $fileContent.Substring($ctxStart, $ctxEnd - $ctxStart)
        if ($ctx -match 'messages' -or $ctx -match 'content') {
            $allMatches += Add-Match -File $filePath -Line $lineNo -Type "template" -Role "user" -Content $m.Value
        }
    }

    # 8) role: "..." style (system/user/human: "text")
    $roleLinePatterns = @(
        @{Pattern = 'system:\s*"([^"]*)"'; Role = "system"}
        @{Pattern = 'user:\s*"([^"]*)"';   Role = "user"}
        @{Pattern = 'human:\s*"([^"]*)"';  Role = "user"}
    )
    foreach ($rp in $roleLinePatterns) {
        $roleMatches = [regex]::Matches($fileContent, $rp.Pattern)
        foreach ($rm in $roleMatches) {
            $lineNo = ($fileContent.Substring(0, $rm.Index).Split("`n").Length)
            $content = $rm.Groups[1].Value
            if ($content.Trim().Length -gt 0) {
                $allMatches += Add-Match -File $filePath -Line $lineNo -Type $rp.Role -Role $rp.Role -Content $content
            }
        }
    }
}

# --- Deduplicate and build final result ---
$seen = @{}
$prompts = @()
foreach ($m in $allMatches) {
    $key = "$($m.File):$($m.Line):$($m.Type):$($m.Content.GetHashCode())"
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $relFile = $m.File
        if ($relFile.StartsWith($ProjectDirPath)) {
            $relFile = $relFile.Substring($ProjectDirPath.Length).TrimStart("\").TrimStart("/")
        }
        $prompts += @{
            file = $relFile
            line = $m.Line
            type = $m.Type
            role = $m.Role
            hasFormatSpec          = $m.hasFormatSpec
            hasSafetyInstructions  = $m.hasSafetyInstructions
            usesDynamicContext     = $m.usesDynamicContext
            includesUserInput      = $m.includesUserInput
            classification         = $m.classification
        }
    }
}

$total = $prompts.Count
$structured = 0; $semiStructured = 0; $openEnded = 0; $injectionSusceptible = 0
foreach ($p in $prompts) {
    $c = $p["classification"]
    switch ($c) {
        "structured" { $structured++ }
        "semi-structured" { $semiStructured++ }
        "open-ended" { $openEnded++ }
        "injection-susceptible" { $injectionSusceptible++ }
        default { Write-Warning "Unknown classification: $c" }
    }
}

$result = @{
    scannedDir = $ProjectDirPath
    totalFiles = $files.Count
    promptFiles = $promptFiles.Count
    total = $total
    structured = $structured
    semiStructured = $semiStructured
    openEnded = $openEnded
    injectionSusceptible = $injectionSusceptible
    prompts = $prompts
}

$json = $result | ConvertTo-Json -Depth 10
Write-Output $json

Write-Output ""
Write-Output "=== PROMPT-SCAN ==="
Write-Output "Scanned: $ProjectDirPath"
Write-Output "Files: $($files.Count) source, $($promptFiles.Count) prompt files"
Write-Output "Total prompts found: $total"
Write-Output "  Structured: $structured"
Write-Output "  Semi-structured: $semiStructured"
Write-Output "  Open-ended: $openEnded"
Write-Output "  Injection-susceptible: $injectionSusceptible"
Write-Output "===================="
