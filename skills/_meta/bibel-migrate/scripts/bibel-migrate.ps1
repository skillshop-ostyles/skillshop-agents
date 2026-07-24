[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$migrations = New-Object System.Collections.Generic.List[object]
$total = 0; $migratable = 0

Get-ChildItem $root/skills -Recurse -Filter '*.ps1' | ForEach-Object {
    $total++
    $content = Get-Content $_.FullName -Raw; $rel = $_.FullName.Substring($root.Length).TrimStart('\')
    $patches = @()
    if ($content -notmatch '\[CmdletBinding\(\)\]') { $patches += "add [CmdletBinding()] param block after param(" }
    if ($content -notmatch 'ErrorActionPreference') { $patches += "add `$ErrorActionPreference = 'Stop'" }
    if ($content -notmatch 'OutputEncoding.*UTF8') { $patches += "add UTF-8 OutputEncoding" }
    if ($content -notmatch 'ConvertTo-Json') { $patches += 'add Write-Output (ConvertTo-Json ...) before === TITLE ===' }
    if ($content -notmatch '=== ') {
        $name = (Get-Item $_.Directory.Parent.Parent).Name.ToUpper() -replace '-','_'
        $patches += "add === $name ==="
    }
    if ($patches.Count -gt 0) { $migratable++; $migrations.Add([ordered]@{ file = $rel; patches = $patches }) }
}
Write-Output (ConvertTo-Json ([ordered]@{ migrations = $migrations.ToArray(); totalScripts = $total; needingMigration = $migratable }) -Depth 6)
Write-Output "`n=== BIBEL-MIGRATE ===`n  Scripts: $total | Need migration: $migratable"
