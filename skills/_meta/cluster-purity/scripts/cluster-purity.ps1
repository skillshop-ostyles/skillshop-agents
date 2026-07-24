[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$clusterKeywords = @{
    quality = @('code','smell','pattern','refactor','lint','style','consistency','naming','dead','doc','duplicate','magic','invariant')
    security = @('auth','injection','secret','ssl','cors','session','permission','vulnerability','trust','rate','crypto','bypass','ssrf')
    understanding = @('architect','onboard','knowledge','doc','api','config','integration','dataflow','techdebt','changelog','runbook')
    data = @('migration','schema','sql','query','pii','fixture','seed','contract','relationship')
    operations = @('deploy','rollback','backup','health','capacity','ci','env','log','monitor','docker','dependency')
    runtime = @('startup','error','repro','mirror','concurrency','cache','shutdown','type','mock','thread','performance')
    'ai-ml' = @('prompt','embedding','token','llm','guardrail','drift','rag','observability','finetune','determinism','leak','fidelity')
}
$results = New-Object System.Collections.Generic.List[object]

Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart('\')
    $cluster = $rel -split '[\\/]' | Select-Object -Skip 1 -First 1
    $skillName = (Get-Item $_.Directory).Name
    $content = Get-Content $_.FullName -Raw
    $desc = if ($content -match 'description:\s*"(.+?)"') { $matches[1] } else { '' }
    $words = ($desc + ' ' + $skillName) -split '\W+' | Where-Object { $_.Length -gt 2 } | ForEach-Object { $_.ToLower() } | Sort-Object -Unique
    $scores = @{}
    foreach ($kv in $clusterKeywords.GetEnumerator()) {
        $matchCount = ($words | Where-Object { $kv.Value -contains $_ }).Count
        if ($matchCount -gt 0) { $scores[$kv.Key] = $matchCount }
    }
    $bestFit = ($scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    if ($bestFit -and $bestFit -ne $cluster) {
        $results.Add([ordered]@{ skill = $skillName; currentCluster = $cluster; suggestedCluster = $bestFit; score = $scores[$bestFit] })
    }
}
Write-Output (ConvertTo-Json ([ordered]@{ candidates = $results.ToArray(); totalMismatches = $results.Count }) -Depth 6)
Write-Output "`n=== CLUSTER-PURITY ===`n  Mismatch candidates: $($results.Count)"
