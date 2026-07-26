[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$findings = @()
$exitCode = -1

# Check package.json exists
$pkgPath = Join-Path $resolvedDir "package.json"
if (-not (Test-Path $pkgPath)) {
    $result = @{
        check = 'build'
        status = 'skip'
        findings = @(@{ type = 'error'; file = 'package.json'; line = 0; message = 'package.json not found — not a Node.js project' })
        summary = @{ errors = 1; warnings = 0 }
        exitCode = -1
    }
    Write-Output ($result | ConvertTo-Json -Depth 3)
    exit 0
}

# Check node_modules exists
$nmPath = Join-Path $resolvedDir "node_modules"
$hasNodeModules = Test-Path $nmPath
if (-not $hasNodeModules) {
    $findings += @{ type = 'warning'; file = 'node_modules'; line = 0; message = 'node_modules not found — run npm install first' }
}

# Check for build script
$pkg = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$hasBuildScript = $pkg.scripts -and $pkg.scripts.build
if (-not $hasBuildScript) {
    $findings += @{ type = 'error'; file = 'package.json'; line = 0; message = 'No "build" script defined in package.json' }
    $summary = @{ errors = ($findings | Where-Object { $_.type -eq 'error' }).Count; warnings = ($findings | Where-Object { $_.type -eq 'warning' }).Count }
    $result = @{ check = 'build'; status = 'fail'; findings = $findings; summary = $summary; exitCode = $exitCode }
    Write-Output ($result | ConvertTo-Json -Depth 3)
    exit 0
}

# Run npm run build with timeout
if ($hasNodeModules) {
    try {
        $buildOutput = & "npm" "run" "build" 2>&1
        $exitCode = $LASTEXITCODE
        $outputText = ($buildOutput | Out-String)

        if ($exitCode -eq 0) {
            $findings += @{ type = 'info'; file = 'build'; line = 0; message = 'Build completed successfully' }
        } else {
            $findings += @{ type = 'error'; file = 'build'; line = 0; message = 'Build failed with exit code ' + $exitCode }
        }

        # Extract TypeScript errors
        $outputText -split "`n" | ForEach-Object {
            if ($_ -match '^(.+\.(ts|tsx|js|jsx))\((\d+),\d+\):\s+error\s+') {
                $findings += @{ type = 'error'; file = $Matches[1]; line = [int]$Matches[3]; message = $_ }
            } elseif ($_ -match '^(.+\.(ts|tsx|js|jsx))\((\d+),\d+\):\s+warning\s+') {
                $findings += @{ type = 'warning'; file = $Matches[1]; line = [int]$Matches[3]; message = $_ }
            }
        }

        # Count warnings from output
        $warningCount = @($outputText | Select-String -Pattern 'warning' -SimpleMatch).Count

        if ($findings.Count -eq 1 -and $exitCode -eq 0) {
            # Only the success message
            $status = 'pass'
        } elseif ($exitCode -ne 0) {
            $status = 'fail'
        } else {
            $status = 'warn'
        }

        $errCount = ($findings | Where-Object { $_.type -eq 'error' }).Count
        $warnCount = ($findings | Where-Object { $_.type -eq 'warning' }).Count

        $result = @{
            check = 'build'
            status = $status
            findings = $findings
            summary = @{ errors = $errCount; warnings = $warnCount }
            exitCode = $exitCode
        }
        Write-Output ($result | ConvertTo-Json -Depth 3)
    } catch {
        $findings += @{ type = 'error'; file = 'build'; line = 0; message = 'Build execution failed: ' + $_.Exception.Message }
        $result = @{ check = 'build'; status = 'fail'; findings = $findings; summary = @{ errors = 1; warnings = 0 }; exitCode = -1 }
        Write-Output ($result | ConvertTo-Json -Depth 3)
    }
} else {
    $result = @{ check = 'build'; status = 'skip'; findings = $findings; summary = @{ errors = 0; warnings = 1 }; exitCode = -1 }
    Write-Output ($result | ConvertTo-Json -Depth 3)
}
