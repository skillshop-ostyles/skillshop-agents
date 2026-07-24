[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$skills = Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object { $_.FullName }
$pairs = New-Object System.Collections.Generic.List[object]

for ($i = 0; $i -lt $skills.Count; $i++) {
    $aContent = Get-Content $skills[$i] -Raw; $aDir = (Get-Item $skills[$i]).Directory.Name
    $aDesc = if ($aContent -match 'description:\s*"(.+?)"') { $matches[1] } else { '' }
    $aWords = $aDesc -split '\W+' | Where-Object { $_.Length -gt 3 } | ForEach-Object { $_.ToLower() } | Sort-Object -Unique

    for ($j = $i + 1; $j -lt $skills.Count; $j++) {
        $bContent = Get-Content $skills[$j] -Raw; $bDir = (Get-Item $skills[$j]).Directory.Name
        $bDesc = if ($bContent -match 'description:\s*"(.+?)"') { $matches[1] } else { '' }
        $bWords = $bDesc -split '\W+' | Where-Object { $_.Length -gt 3 } | ForEach-Object { $_.ToLower() } | Sort-Object -Unique
        $intersection = $aWords | Where-Object { $bWords -contains $_ }
        $union = ($aWords + $bWords) | Sort-Object -Unique
        $jaccard = if ($union.Count -gt 0) { [math]::Round($intersection.Count / $union.Count, 2) } else { 0 }
        if ($jaccard -ge 0.3) { $pairs.Add([ordered]@{ a = $aDir; b = $bDir; overlap = $jaccard; sharedTerms = $intersection -join ', ' }) }
    }
}
$sorted = $pairs | Sort-Object { $_.overlap } -Descending
Write-Output (ConvertTo-Json ([ordered]@{ pairs = $sorted; totalSkills = $skills.Count; candidatePairs = $pairs.Count }) -Depth 6)
Write-Output "`n=== SKILL-DEDUP ===`n  Skills: $($skills.Count) | Overlap pairs >= 30%: $($pairs.Count)"
