[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.yml,*.yaml,*.json",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Patterns by finding type
$tlsVersionPatterns = @(
    @{ regex='TLS_RSA_\w+'; type='tls-version' },
    @{ regex='TLS_ECDHE_\w+'; type='tls-version' },
    @{ regex='TLS_AES_\d+_\w+'; type='tls-version' },
    @{ regex='ECDHE-RSA-AES\d+-\w+'; type='tls-version' },
    @{ regex='TLSv1_2_method'; type='tls-version' },
    @{ regex='TLSv1_1_method'; type='tls-version' },
    @{ regex='TLSv1_method'; type='tls-version' },
    @{ regex='TLSv1\.2'; type='tls-version' },
    @{ regex='TLSv1\.1'; type='tls-version' },
    @{ regex='TLSv1[.\s]'; type='tls-version' },
    @{ regex='secureProtocol\s*:\s*"TLSv1'; type='tls-version' },
    @{ regex='minVersion\s*:\s*"TLSv1'; type='tls-version' },
    @{ regex='maxVersion\s*:\s*"TLSv1'; type='tls-version' }
)

$sslContextPatterns = @(
    @{ regex='crypto\.createCredentials'; type='ssl-context' },
    @{ regex='tls\.createSecureContext'; type='ssl-context' },
    @{ regex='ssl\.createDefaultContext'; type='ssl-context' },
    @{ regex='SecureContextOptions'; type='ssl-context' },
    @{ regex='secureOptions\s*:'; type='ssl-context' },
    @{ regex='SSL_OP_NO_SSLv\d'; type='ssl-context' },
    @{ regex='SSL_OP_NO_TLSv1'; type='ssl-context' }
)

$cipherSuitePatterns = @(
    @{ regex='cipher.*(?:\[.*?\]|array|list|set)'; type='cipher-suite' },
    @{ regex='ciphers\s*:'; type='cipher-suite' },
    @{ regex='CipherSuite\s*='; type='cipher-suite' },
    @{ regex='ECDHE|DHE|AES|CHACHA|RC4|CBC|GCM'; type='cipher-suite' },
    @{ regex='ssl_cipher|sslCipher|tls_cipher'; type='cipher-suite' },
    @{ regex='CIPHER_SUITES'; type='cipher-suite' }
)

$certPinPatterns = @(
    @{ regex='publicKeyPinning'; type='cert-pin' },
    @{ regex='hpkp'; type='cert-pin' },
    @{ regex='CertificatePinner'; type='cert-pin' },
    @{ regex='certPinning'; type='cert-pin' },
    @{ regex='fingerprint'; type='cert-pin' },
    @{ regex='pinning\s*='; type='cert-pin' },
    @{ regex='\.pin\s*\('; type='cert-pin' },
    @{ regex='public_key_pins'; type='cert-pin' }
)

$mtlsPatterns = @(
    @{ regex='requestCert'; type='mtls' },
    @{ regex='rejectUnauthorized'; type='mtls' },
    @{ regex='mutualTLS'; type='mtls' },
    @{ regex='mtls'; type='mtls' },
    @{ regex='clientAuth'; type='mtls' },
    @{ regex='mTLS'; type='mtls' },
    @{ regex='MutualTls'; type='mtls' },
    @{ regex='requireClientCert'; type='mtls' }
)

$certValidationPatterns = @(
    @{ regex='checkServerIdentity'; type='cert-validation' },
    @{ regex='checkValidity'; type='cert-validation' },
    @{ regex='certValidation'; type='cert-validation' },
    @{ regex='validateCert'; type='cert-validation' },
    @{ regex='verifyCert'; type='cert-validation' },
    @{ regex='certificateVerification'; type='cert-validation' }
)

$fipsPatterns = @(
    @{ regex='FIPSMode'; type='fips' },
    @{ regex='fips'; type='fips' },
    @{ regex='openssl_fips'; type='fips' },
    @{ regex='FIPS\s*:'; type='fips' },
    @{ regex='OpenSSL\.FIPS'; type='fips' },
    @{ regex='enableFips'; type='fips' }
)

$allPatterns = $tlsVersionPatterns + $sslContextPatterns + $cipherSuitePatterns `
              + $certPinPatterns + $mtlsPatterns + $certValidationPatterns `
              + $fipsPatterns

$findings = @()
$linesScanned = 0
$counts = @{
    tlsVersion = 0
    sslContext = 0
    cipherSuite = 0
    certPin = 0
    mtls = 0
    certValidation = 0
    fips = 0
}

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { $accept = $false }
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
            foreach ($r in $allPatterns) {
                if ($ln -match $r.regex) {
                    $typeKey = $r.type -replace '-', ''
                    $typeKeyPascal = $typeKey.Substring(0,1).ToUpper() + $typeKey.Substring(1)
                    switch ($r.type) {
                        'tls-version'     { $counts.tlsVersion++ }
                        'ssl-context'     { $counts.sslContext++ }
                        'cipher-suite'    { $counts.cipherSuite++ }
                        'cert-pin'        { $counts.certPin++ }
                        'mtls'            { $counts.mtls++ }
                        'cert-validation' { $counts.certValidation++ }
                        'fips'            { $counts.fips++ }
                    }
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        findingType = $r.type
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
        }
    }
}

Write-Output "=== TLS Config Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total findings: $($findings.Count)"
Write-Output "  tls-version: $($counts.tlsVersion)"
Write-Output "  ssl-context: $($counts.sslContext)"
Write-Output "  cipher-suite: $($counts.cipherSuite)"
Write-Output "  cert-pin: $($counts.certPin)"
Write-Output "  mtls: $($counts.mtls)"
Write-Output "  cert-validation: $($counts.certValidation)"
Write-Output "  fips: $($counts.fips)"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        totalFindings = $findings.Count
        tlsVersion = $counts.tlsVersion
        sslContext = $counts.sslContext
        cipherSuite = $counts.cipherSuite
        certPin = $counts.certPin
        mtls = $counts.mtls
        certValidation = $counts.certValidation
        fips = $counts.fips
    }
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
