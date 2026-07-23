[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Session creation patterns: frameworks that establish a session.
$sessionCreation = @(
    @{ regex='session\s*\(\s*\{'; kind='creation' },
    @{ regex='Session\.Start\s*\('; kind='creation' },
    @{ regex='session_start\s*\('; kind='creation' },
    @{ regex='cookie-parser'; kind='creation' },
    @{ regex='express-session'; kind='creation' },
    @{ regex='session\s*=\s*[A-Za-z]+Session\s*\('; kind='creation' },
    @{ regex='flask[.\s]*session\b'; kind='creation' }
)

# Session ID usage.
$sessionIdPatterns = @(
    @{ regex='req\.sessionID\b'; kind='session-id' },
    @{ regex='session\.id\b'; kind='session-id' },
    @{ regex='session\.sessionId\b'; kind='session-id' },
    @{ regex='context\.session_id\b'; kind='session-id' }
)

# Auth login events.
$authLoginPatterns = @(
    @{ regex='\.login\s*\('; kind='login' },
    @{ regex='signIn\s*\('; kind='login' },
    @{ regex='authenticate\s*\('; kind='login' },
    @{ regex='passport\.authenticate'; kind='login' },
    @{ regex='LogInAsync\s*\('; kind='login' },
    @{ regex='\.sign_in\s*\('; kind='login' }
)

# Session regeneration (the fix for fixation).
$sessionRegenPatterns = @(
    @{ regex='regenerate\s*\('; kind='regenerate' },
    @{ regex='session\.regenerate'; kind='regenerate' },
    @{ regex='session\.regen'; kind='regenerate' },
    @{ regex='session\.invalidate'; kind='regenerate' }
)

# JWT token creation / verification.
$jwtPatterns = @(
    @{ regex='jwt\.sign\s*\('; kind='jwt-sign' },
    @{ regex='jwt\.verify\s*\('; kind='jwt-verify' },
    @{ regex='refreshToken\b'; kind='refresh-token' },
    @{ regex='accessToken\b'; kind='access-token' }
)

# Logout cleanup.
$logoutPatterns = @(
    @{ regex='logout\s*\('; kind='logout' },
    @{ regex='signOut\s*\('; kind='logout' },
    @{ regex='session\.destroy'; kind='destroy' },
    @{ regex='clearCookie\s*\('; kind='destroy' },
    @{ regex='session\.clear'; kind='destroy' },
    @{ regex='session\.flush\b'; kind='destroy' },
    @{ regex='session\.\w+\s*=\s*null\b'; kind='implicit-clear' },
    @{ regex='logout|sign.?out'; kind='logout-ref' }
)

# Refresh rotation.
$refreshRotatePatterns = @(
    @{ regex='rotateRefresh\b'; kind='rotate' },
    @{ regex='tokenRotation\b'; kind='rotate' },
    @{ regex='newRefresh\b'; kind='rotate' },
    @{ regex='refreshToken\s*=\s*generateToken'; kind='rotate' },
    @{ regex='setRefreshToken\s*\('; kind='rotate' }
)

$findings = @()
$linesScanned = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        $linesScanned += $lines.Count

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            $matchedKind = $null

            # Session creation
            foreach ($r in $sessionCreation) {
                if ($ln -match $r.regex) { $matchedKind = 'creation'; break }
            }
            # Session ID
            if (-not $matchedKind) {
                foreach ($r in $sessionIdPatterns) {
                    if ($ln -match $r.regex) { $matchedKind = 'session-id'; break }
                }
            }
            # Auth login
            if (-not $matchedKind) {
                foreach ($r in $authLoginPatterns) {
                    if ($ln -match $r.regex) { $matchedKind = 'login'; break }
                }
            }
            # JWT
            if (-not $matchedKind) {
                foreach ($r in $jwtPatterns) {
                    if ($ln -match $r.regex) {
                        $matchedKind = if ($r.kind -eq 'jwt-sign' -or $r.kind -eq 'jwt-verify') { 'jwt' } else { $r.kind }
                        break
                    }
                }
            }
            # Logout
            if (-not $matchedKind) {
                foreach ($r in $logoutPatterns) {
                    if ($ln -match $r.regex) {
                        $matchedKind = $r.kind
                        break
                    }
                }
            }
            # Refresh rotation
            if (-not $matchedKind) {
                foreach ($r in $refreshRotatePatterns) {
                    if ($ln -match $r.regex) { $matchedKind = 'rotate'; break }
                }
            }

            if (-not $matchedKind) { continue }

            # Scan nearby lines (±5) for regen / invalidate / rotate context.
            $startIdx = [Math]::Max(0, $li - 5)
            $endIdx = [Math]::Min($lines.Count - 1, $li + 5)
            $hasRegen = $false
            $hasInvalidate = $false
            $hasRotate = $false
            for ($wi = $startIdx; $wi -le $endIdx; $wi++) {
                $wl = $lines[$wi]
                if ($wl -match 'regenerate\s*\(') { $hasRegen = $true }
                if ($wl -match 'session\.invalidate|session\.destroy|session\.clear|session\.flush') { $hasInvalidate = $true }
                if ($wl -match 'rotateRefresh\s*\(|tokenRotation\s*\(|newRefresh\s*\(|setRefreshToken\s*\(') { $hasRotate = $true }
            }

            # Determine if this is a JWT-context finding (token-based auth).
            $isJwtContext = ($hasRotate -or
                ($ln -match 'jwt\.sign|jwt\.verify|accessToken|refreshToken'))

            $findings += @{
                file = $rel
                line = $li + 1
                sessionType = $matchedKind
                code = ($ln.Trim() -replace '\s+', ' ')
                hasRegen = $hasRegen
                hasInvalidate = $hasInvalidate
                hasRotate = $hasRotate
                isJwtContext = $isJwtContext
            }
        }
    }
}

# Deduce anomalies from the findings.
$anomalies = @()
foreach ($f in $findings) {
    # Login in session context without regen = fixation risk.
    if ($f.sessionType -eq 'login' -and -not $f.isJwtContext -and -not $f.hasRegen) {
        $anomalies += @{
            file = $f.file
            line = $f.line
            anomaly = 'session-fixation'
            description = "Login without session regeneration. Attacker can fixate session ID before auth."
        }
    }
    # Login in JWT context without rotation = long-lived token.
    if ($f.sessionType -eq 'login' -and $f.isJwtContext -and -not $f.hasRotate) {
        $anomalies += @{
            file = $f.file
            line = $f.line
            anomaly = 'no-refresh-rotation'
            description = "JWT login without refresh-token rotation. Stolen refresh token stays valid indefinitely."
        }
    }
    # Logout or logout reference without destroy/clear = lingering session.
    if (($f.sessionType -eq 'logout' -or $f.sessionType -eq 'logout-ref' -or $f.sessionType -eq 'implicit-clear') -and -not $f.hasInvalidate) {
        $anomalies += @{
            file = $f.file
            line = $f.line
            anomaly = 'lingering-session'
            description = "Logout without session destroy/clear. Session remains valid after logout."
        }
    }
    # Refresh token found without rotation.
    if ($f.sessionType -eq 'refresh-token' -and -not $f.hasRotate) {
        $anomalies += @{
            file = $f.file
            line = $f.line
            anomaly = 'no-refresh-rotation'
            description = "Refresh token without rotation. Long-lived token window increases re-use risk."
        }
    }
    # Session creation or ID usage without regen/invalidate nearby.
    if (($f.sessionType -eq 'creation' -or $f.sessionType -eq 'session-id') -and -not $f.hasRegen -and -not $f.hasInvalidate) {
        $anomalies += @{
            file = $f.file
            line = $f.line
            anomaly = 'creation-without-regen'
            description = "Session created but no regenerate or invalidate found nearby. Verify lifecycle."
        }
    }
}

Write-Output "=== Session State Anomaly Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Session findings: $($findings.Count)"
Write-Output "  Anomalies detected: $($anomalies.Count)"
Write-Output "    session-fixation: $((@($anomalies | Where-Object { $_.anomaly -eq 'session-fixation' }).Count))"
Write-Output "    lingering-session: $((@($anomalies | Where-Object { $_.anomaly -eq 'lingering-session' }).Count))"
Write-Output "    no-refresh-rotation: $((@($anomalies | Where-Object { $_.anomaly -eq 'no-refresh-rotation' }).Count))"
Write-Output "    creation-without-regen: $((@($anomalies | Where-Object { $_.anomaly -eq 'creation-without-regen' }).Count))"

$result = @{
    findings = $findings
    anomalies = $anomalies
    counts = @{
        files = $fileSet.Count
        linesScanned = $linesScanned
        totalFindings = $findings.Count
        totalAnomalies = $anomalies.Count
        sessionFixation = (@($anomalies | Where-Object { $_.anomaly -eq 'session-fixation' }).Count)
        lingeringSession = (@($anomalies | Where-Object { $_.anomaly -eq 'lingering-session' }).Count)
        noRefreshRotation = (@($anomalies | Where-Object { $_.anomaly -eq 'no-refresh-rotation' }).Count)
        creationWithoutRegen = (@($anomalies | Where-Object { $_.anomaly -eq 'creation-without-regen' }).Count)
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
