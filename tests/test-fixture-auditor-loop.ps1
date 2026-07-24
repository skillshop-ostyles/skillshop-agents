$ErrorActionPreference = 'Stop'
$resolvedDir = (Resolve-Path -LiteralPath ./skills/data/data-fixture-auditor/tests/fixtures/smoke).Path
$raw = Get-Content -LiteralPath "$resolvedDir/src/seed.json" -Raw -Encoding UTF8
$data = $raw | ConvertFrom-Json
$entities = @{}
foreach ($prop in $data.PSObject.Properties.Name) {
    $value = $data.$prop
    if ($null -ne $value -and $value -is [System.Array] -and $value.Count -gt 0) {
        $first = $value[0]
        if ($null -ne $first -and $first -is [System.Management.Automation.PSCustomObject]) {
            $entities[$prop] = @($value)
        }
    }
}
foreach ($entityName in $entities.Keys) {
    $records = $entities[$entityName]
    Write-Host "Entity $entityName : $($records.Count) records"
    $fieldValues = @{}
    foreach ($rec in $records) {
        foreach ($prop in $rec.PSObject.Properties.Name) {
            if (-not $fieldValues.ContainsKey($prop)) { $fieldValues[$prop] = @() }
            $fieldValues[$prop] += , $rec.$prop
        }
    }
    Write-Host "  fields: $($fieldValues.Keys -join ', ')"
}
Write-Host "DONE"
