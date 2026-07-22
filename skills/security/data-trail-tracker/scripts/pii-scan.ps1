[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string]$ExtraTerms = ""
)

$ErrorActionPreference = 'Stop'
$pdir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $pdir) { Write-Error "Path not found: $ProjectDir"; exit 1 }
$pdir = $pdir.Path

$piiWords = @(
    'email','mail','e-mail','firstName','first_name','lastName','last_name','firstname','lastname',
    'name','fullname','full_name','surname','username',
    'phone','tel','mobile','telephone','cellphone','cell',
    'address','adresse','street','strasse','city','zip','plz','postal',
    'birth','geburt','dob','birthdate','birth_date','birthday','age',
    'gender','geschlecht','sex',
    'iban','bic','account','bank','card','ccnumber','creditcard',
    'ssn','social','sozialversicherung','steuer','tax_id','taxid','passport','ausweis',
    'ip_addr','ip_address','ip','location','geo','lat','lng','latitude','longitude',
    'photo','avatar','signature','picture','image','profile',
    'password','passwd','pwd','secret','token','apikey','api_key',
    'health','healthcare','medical','diagnosis','insurance',
    'salary','income','revenue'
)
if ($ExtraTerms) { $ExtraTerms -split ',' | ForEach-Object { $piiWords += $_.Trim().ToLower() } }
$piiWords = $piiWords | Select-Object -Unique

$piiCandidates = @()
$sinks = @{ log = @(); external = @(); export = @(); storage = @(); deletion = @() }
$scannedFiles = 0

$exts = @('*.js','*.ts','*.tsx','*.jsx','*.py','*.cs','*.go','*.java','*.rb','*.php','*.sql','*.prisma','*.graphql','*.proto')

# Two-pass: first collect candidates, then sinks
$allFileData = @()
$structureNames = @()

# Pass 1: collect structure info and PII candidates
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
        $allFileData += @{ rel = $rel; lines = $lines; ext = $ext }

        # Find structure definitions
        if ($ext -in '.js','.ts','.tsx','.jsx') {
            $structMatch = [regex]::Match($content, '(?:interface|type|class)\s+(\w*(?:Dto|DTO|Request|Response|Model|Payload|ViewModel|User|Customer|Person|Patient|Employee|Member|Contact|Profile|Account|Order|Payment|Session|Address))\b')
            while ($structMatch.Success) {
                $sname = $structMatch.Groups[1].Value
                if ($sname -notin $structureNames) { $structureNames += $sname }
                $blockStart = $content.IndexOf('{', $structMatch.Index)
                if ($blockStart -ge 0) {
                    $depth = 0; $blockEnd = $blockStart
                    for ($j = $blockStart; $j -lt $content.Length; $j++) {
                        if ($content[$j] -eq '{') { $depth++ }
                        elseif ($content[$j] -eq '}') { $depth-- }
                        if ($depth -eq 0) { $blockEnd = $j; break }
                    }
                    $blockText = $content.Substring($blockStart, $blockEnd - $blockStart + 1)
                    foreach ($bl in ($blockText -split "`n")) {
                        $blt = $bl.Trim()
                        if ($blt -match '^\s*(\w[\w?]*)\s*[:?]') {
                            $fname = $matches[1].TrimEnd('?')
                            $fnameLower = $fname.ToLower()
                            foreach ($pw in $piiWords) {
                                if ($fnameLower -match [regex]::Escape($pw)) {
                                    $piiCandidates += @{ structure = $sname; field = $fname; file = $rel; source = $ext.TrimStart('.'); line = 0 }
                                    break
                                }
                            }
                        }
                    }
                }
                $structMatch = $structMatch.NextMatch()
            }
        }

        # SQL CREATE TABLE
        if ($ext -eq '.sql') {
            $structMatch = [regex]::Match($content, 'CREATE\s+TABLE\s+(\w+)')
            while ($structMatch.Success) {
                $sname = $structMatch.Groups[1].Value
                if ($sname -notin $structureNames) { $structureNames += $sname }
                $blockStart = $content.IndexOf('(', $structMatch.Index)
                if ($blockStart -ge 0) {
                    $blockEnd = $content.IndexOf(')', $blockStart)
                    $blockText = $content.Substring($blockStart, $blockEnd - $blockStart + 1)
                    foreach ($fl in ($blockText -split "`n")) {
                        $flt = $fl.Trim()
                        if ($flt -match '^\s*(\w+)\s') {
                            $fname = $matches[1]
                            $fnameLower = $fname.ToLower()
                            if ($fnameLower -notin 'id','created_at','updated_at','deleted_at') {
                                foreach ($pw in $piiWords) {
                                    if ($fnameLower -match [regex]::Escape($pw)) {
                                        $piiCandidates += @{ structure = $sname; field = $fname; file = $rel; source = 'sql'; line = 0 }
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                $structMatch = $structMatch.NextMatch()
            }
        }

        # Prisma models
        if ($ext -eq '.prisma') {
            $structMatch = [regex]::Match($content, '^model\s+(\w+)\s*{', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            while ($structMatch.Success) {
                $sname = $structMatch.Groups[1].Value
                if ($sname -notin $structureNames) { $structureNames += $sname }
                $blockStart = $content.IndexOf('{', $structMatch.Index)
                $blockEnd = $content.IndexOf('}', $blockStart)
                if ($blockStart -ge 0 -and $blockEnd -gt $blockStart) {
                    $blockText = $content.Substring($blockStart, $blockEnd - $blockStart + 1)
                    foreach ($bl in ($blockText -split "`n")) {
                        $blt = $bl.Trim()
                        if ($blt -match '^(\w+)\s') {
                            $fname = $matches[1]
                            $fnameLower = $fname.ToLower()
                            foreach ($pw in $piiWords) {
                                if ($fnameLower -match [regex]::Escape($pw)) {
                                    $piiCandidates += @{ structure = $sname; field = $fname; file = $rel; source = 'prisma'; line = 0 }
                                    break
                                }
                            }
                        }
                    }
                }
                $structMatch = $structMatch.NextMatch()
            }
        }
    }
}

# Pass 2: Sink detection (now with full structureNames + piiCandidates)
foreach ($fd in $allFileData) {
    $rel = $fd.rel
    $lines = $fd.lines
    $lineNum = 0
    $ext = $fd.ext
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed -match '^(#|//|--|\*)') { continue }

        $matched = @()
        $lowerTrimmed = $trimmed.ToLower()
        foreach ($sn in $structureNames) {
            if ($lowerTrimmed -match [regex]::Escape($sn.ToLower())) { $matched += $sn }
        }
        foreach ($pc in $piiCandidates) {
            if ($lowerTrimmed -match [regex]::Escape($pc.field.ToLower())) { $matched += "$($pc.structure).$($pc.field)" }
        }
        $matched = $matched | Select-Object -Unique
        if ($matched.Count -eq 0) { continue }

        $lineText = $trimmed.Substring(0, [Math]::Min(100, $trimmed.Length))

        if ($trimmed -match '\b(log|logger|console\.|printf|println|info|warn|error|debug|trace)\s*\(') {
            $sinks.log += @{ file = $rel; line = $lineNum; text = $lineText; matched = $matched }
        }
        if ($trimmed -match '(?:fetch|axios|http\.|requests\.|HttpClient|curl|Invoke-RestMethod)(?:\.\w+)?\s*\(') {
            $sinks.external += @{ file = $rel; line = $lineNum; text = $lineText; matched = $matched }
        }
        if ($trimmed -match '(writeFile|createWriteStream|csv|xlsx|export|SaveAs|Set-Content|Out-File)\s*\(' -or $trimmed -match '\.write\s*\(|\.save\s*\(') {
            $sinks.export += @{ file = $rel; line = $lineNum; text = $lineText; matched = $matched }
        }
        if ($trimmed -match '\b(INSERT|UPDATE|save|create|store|persist|add|insert|put)\s*\(' -or $trimmed -match '\.save\s*\(|\.create\s*\(|\.insert\s*\(') {
            $sinks.storage += @{ file = $rel; line = $lineNum; text = $lineText; matched = $matched }
        }
        if ($trimmed -match '\b(delete|remove|anonymi|purge|retention|gdpr|dsgvo|erase|destroy|wipe)\b') {
            $sinks.deletion += @{ file = $rel; line = $lineNum; text = $lineText; matched = $matched }
        }
    }
}

$result = @{
    piiCandidates = $piiCandidates
    sinks = $sinks
    counts = @{ candidates = $piiCandidates.Count; log = $sinks.log.Count; external = $sinks.external.Count; export = $sinks.export.Count; storage = $sinks.storage.Count; deletion = $sinks.deletion.Count }
    scannedFiles = $scannedFiles
}

Write-Output "=== PII Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  PII candidates: $($piiCandidates.Count)"
Write-Output "  Log sinks: $($sinks.log.Count)"
Write-Output "  External sinks: $($sinks.external.Count)"
Write-Output "  Export sinks: $($sinks.export.Count)"
Write-Output "  Storage sinks: $($sinks.storage.Count)"
Write-Output "  Deletion signals: $($sinks.deletion.Count)"

Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
