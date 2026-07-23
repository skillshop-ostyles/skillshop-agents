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

# Hash algorithm patterns (weak + modern)
$hashPatterns = @(
    @{ regex='crypto\.createHash\(["\x27]md5["\x27]\)';            algorithm='MD5';         isModern=$false; cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]md4["\x27]\)';            algorithm='MD4';         isModern=$false; cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]sha1["\x27]\)';           algorithm='SHA1';        isModern=$false; cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]sha-1["\x27]\)';          algorithm='SHA1';        isModern=$false; cryptoType='hash' }
    @{ regex='hashlib\.md5\b';                                      algorithm='MD5';         isModern=$false; cryptoType='hash' }
    @{ regex='hashlib\.sha1\b';                                     algorithm='SHA1';        isModern=$false; cryptoType='hash' }
    @{ regex='MessageDigest\.getInstance\(["\x27]MD5["\x27]';      algorithm='MD5';         isModern=$false; cryptoType='hash' }
    @{ regex='MessageDigest\.getInstance\(["\x27]SHA-?1["\x27]';   algorithm='SHA1';        isModern=$false; cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]sha256["\x27]\)';         algorithm='SHA-256';     isModern=$true;  cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]sha384["\x27]\)';         algorithm='SHA-384';     isModern=$true;  cryptoType='hash' }
    @{ regex='crypto\.createHash\(["\x27]sha512["\x27]\)';         algorithm='SHA-512';     isModern=$true;  cryptoType='hash' }
    @{ regex='hashlib\.sha256\b';                                   algorithm='SHA-256';     isModern=$true;  cryptoType='hash' }
    @{ regex='hashlib\.sha512\b';                                   algorithm='SHA-512';     isModern=$true;  cryptoType='hash' }
)

# Encryption algorithm patterns
$encryptionPatterns = @(
    @{ regex='crypto\.createCipher\(["\x27]aes-256-cbc["\x27]';    algorithm='AES-256-CBC (createCipher deprecated)'; isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipher\(["\x27]aes-128-cbc["\x27]';    algorithm='AES-128-CBC (createCipher deprecated)'; isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipher\(["\x27]aes-192-cbc["\x27]';    algorithm='AES-192-CBC (createCipher deprecated)'; isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipher\(["\x27]des["\x27]';            algorithm='DES';         isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipheriv.*["\x27]des["\x27]';          algorithm='DES';         isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipher\(["\x27]des-ede["\x27]';        algorithm='3DES';        isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipheriv.*["\x27]des-ede["\x27]';      algorithm='3DES';        isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipheriv.*["\x27]rc4["\x27]';          algorithm='RC4';         isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.createCipher\(["\x27]rc4["\x27]';            algorithm='RC4';         isModern=$false; cryptoType='encryption' }
    @{ regex='cipher:\s*["\x27]aes-256-cbc["\x27]';               algorithm='AES-256-CBC'; isModern=$false; cryptoType='encryption' }
    @{ regex='cipher:\s*["\x27]aes-128-cbc["\x27]';               algorithm='AES-128-CBC'; isModern=$false; cryptoType='encryption' }
    @{ regex='["\x27]ECB["\x27]';                                   algorithm='ECB';         isModern=$false; cryptoType='encryption' }
    @{ regex='crypto\.subtle\.encrypt';                             algorithm='subtle.encrypt'; isModern=$true; cryptoType='encryption' }
    @{ regex='crypto\.subtle\.importKey';                           algorithm='subtle.importKey'; isModern=$true; cryptoType='encryption' }
    @{ regex='["\x27]AES-GCM["\x27]';                              algorithm='AES-GCM';     isModern=$true;  cryptoType='encryption' }
    @{ regex='["\x27]aes-256-gcm["\x27]';                          algorithm='AES-256-GCM'; isModern=$true;  cryptoType='encryption' }
    @{ regex='["\x27]chacha20["\x27]';                             algorithm='ChaCha20';    isModern=$true;  cryptoType='encryption' }
    @{ regex='["\x27]XChaCha20["\x27]';                            algorithm='XChaCha20';   isModern=$true;  cryptoType='encryption' }
)

# Password hashing patterns
$passwordHashingPatterns = @(
    @{ regex='bcrypt\.compare\b';                                   algorithm='bcrypt.compare';  isModern=$true;  cryptoType='password-hash' }
    @{ regex='bcrypt\.compareSync\b';                               algorithm='bcrypt.compareSync'; isModern=$true; cryptoType='password-hash' }
    @{ regex='bcrypt\.hash\b';                                      algorithm='bcrypt.hash';     isModern=$true;  cryptoType='password-hash' }
    @{ regex='bcrypt\.hashSync\b';                                  algorithm='bcrypt.hashSync'; isModern=$true;  cryptoType='password-hash' }
    @{ regex='argon2\b';                                            algorithm='argon2';          isModern=$true;  cryptoType='password-hash' }
    @{ regex='scrypt\b';                                            algorithm='scrypt';          isModern=$true;  cryptoType='password-hash' }
    @{ regex='PBKDF2';                                              algorithm='PBKDF2';          isModern=$true;  cryptoType='password-hash' }
    @{ regex='crypto\.pbkdf2\b';                                    algorithm='PBKDF2';          isModern=$true;  cryptoType='password-hash' }
    @{ regex='crypto\.pbkdf2Sync\b';                                algorithm='PBKDF2';          isModern=$true;  cryptoType='password-hash' }
)

# JWT patterns
$jwtPatterns = @(
    @{ regex='jsonwebtoken';                                        algorithm='jsonwebtoken';    isModern=$false; cryptoType='jwt' }
    @{ regex='jose';                                                algorithm='jose';            isModern=$true;  cryptoType='jwt' }
    @{ regex='jwt\.sign\b';                                         algorithm='jwt.sign';        isModern=$false; cryptoType='jwt' }
    @{ regex='jwt\.verify\b';                                       algorithm='jwt.verify';      isModern=$false; cryptoType='jwt' }
    @{ regex='jwt\.decode\b';                                       algorithm='jwt.decode';      isModern=$false; cryptoType='jwt' }
    @{ regex='secret:\s*["\x27][A-Za-z0-9_-]{4,}["\x27]';          algorithm='hardcoded-secret'; isModern=$false; cryptoType='jwt' }
    @{ regex='signWith\s*\(?\s*(?:HS256|HS384|HS512)';             algorithm='HMAC-JWT';        isModern=$false; cryptoType='jwt' }
    @{ regex='algorithm:\s*["\x27]HS256["\x27]';                   algorithm='HS256';           isModern=$false; cryptoType='jwt' }
    @{ regex='algorithm:\s*["\x27]HS384["\x27]';                   algorithm='HS384';           isModern=$false; cryptoType='jwt' }
    @{ regex='algorithm:\s*["\x27]RS256["\x27]';                   algorithm='RS256';           isModern=$true;  cryptoType='jwt' }
    @{ regex='algorithm:\s*["\x27]ES256["\x27]';                   algorithm='ES256';           isModern=$true;  cryptoType='jwt' }
    @{ regex='publicKey\s*=';                                       algorithm='asymmetric-key';  isModern=$true;  cryptoType='jwt' }
    @{ regex='privateKey\s*=';                                      algorithm='asymmetric-key';  isModern=$true;  cryptoType='jwt' }
)

# Key generation patterns
$keyGenPatterns = @(
    @{ regex='crypto\.generateKeyPair\b';                           algorithm='generateKeyPair';   isModern=$true;  cryptoType='key-gen' }
    @{ regex='crypto\.generateKey\b';                               algorithm='generateKey';       isModern=$true;  cryptoType='key-gen' }
    @{ regex='crypto\.webcrypto\.subtle\.generateKey';              algorithm='subtle.generateKey'; isModern=$true; cryptoType='key-gen' }
    @{ regex='createKeyPair\b';                                     algorithm='createKeyPair';     isModern=$false; cryptoType='key-gen' }
    @{ regex='modulusLength:\s*10[24]\b';                           algorithm='RSA-1024';          isModern=$false; cryptoType='key-gen' }
    @{ regex='modulusLength:\s*20[48]\b';                           algorithm='RSA-2048';          isModern=$true;  cryptoType='key-gen' }
    @{ regex='modulusLength:\s*40[96]\b';                           algorithm='RSA-4096';          isModern=$true;  cryptoType='key-gen' }
    @{ regex='["\x27]RS256["\x27]';                                 algorithm='RSA-2048+';         isModern=$true;  cryptoType='key-gen' }
    @{ regex='["\x27]DSA["\x27]';                                   algorithm='DSA';               isModern=$false; cryptoType='key-gen' }
    @{ regex='["\x27]ECDSA["\x27]';                                 algorithm='ECDSA';             isModern=$true;  cryptoType='key-gen' }
    @{ regex='namedCurve:\s*["\x27]P-256["\x27]';                  algorithm='ECDSA-P256';        isModern=$true;  cryptoType='key-gen' }
    @{ regex='namedCurve:\s*["\x27]P-384["\x27]';                  algorithm='ECDSA-P384';        isModern=$true;  cryptoType='key-gen' }
    @{ regex='namedCurve:\s*["\x27]secp256r1["\x27]';              algorithm='ECDSA-P256';        isModern=$true;  cryptoType='key-gen' }
    @{ regex='namedCurve:\s*["\x27]secp224r1["\x27]';              algorithm='ECDSA-P224 (weak)'; isModern=$false; cryptoType='key-gen' }
)

# Config/patch bypass patterns
$configPatterns = @(
    @{ regex='ALLOW_WEAK';                                          algorithm='ALLOW_WEAK';          isModern=$false; cryptoType='config' }
    @{ regex='--harmony';                                           algorithm='--harmony';           isModern=$false; cryptoType='config' }
    @{ regex='legacy-crypto';                                       algorithm='legacy-crypto';       isModern=$false; cryptoType='config' }
    @{ regex='legacyCryptoProvider';                                algorithm='legacyCryptoProvider'; isModern=$false; cryptoType='config' }
    @{ regex='NODE_OPTIONS.*tls-cipher-list';                       algorithm='NODE_OPTIONS cipher list'; isModern=$false; cryptoType='config' }
    @{ regex='algorithm-allowlist';                                 algorithm='algorithm-allowlist'; isModern=$false; cryptoType='config' }
    @{ regex='crypto_allow_weak';                                   algorithm='crypto_allow_weak';   isModern=$false; cryptoType='config' }
    @{ regex='SSL_OP_NO_SSLv[23]';                                  algorithm='SSL_OP_NO_SSLv2/3';   isModern=$true;  cryptoType='config' }
    @{ regex='SSL_OP_NO_TLSv1\b';                                   algorithm='SSL_OP_NO_TLSv1';     isModern=$true;  cryptoType='config' }
)

$allPatterns = $hashPatterns + $encryptionPatterns + $passwordHashingPatterns `
             + $jwtPatterns + $keyGenPatterns + $configPatterns

$findings = @()
$linesScanned = 0
$counts = @{
    hash = 0
    encryption = 0
    passwordHash = 0
    jwt = 0
    keyGen = 0
    config = 0
}

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
            foreach ($r in $allPatterns) {
                if ($ln -match $r.regex) {
                    switch ($r.cryptoType) {
                        'hash'          { $counts.hash++ }
                        'encryption'    { $counts.encryption++ }
                        'password-hash' { $counts.passwordHash++ }
                        'jwt'           { $counts.jwt++ }
                        'key-gen'       { $counts.keyGen++ }
                        'config'        { $counts.config++ }
                    }
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        cryptoType = $r.cryptoType
                        algorithm = $r.algorithm
                        isModern = [bool]$r.isModern
                        code = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
        }
    }
}

Write-Output "=== Crypto Posture Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total findings: $($findings.Count)"
Write-Output "  hash: $($counts.hash)"
Write-Output "  encryption: $($counts.encryption)"
Write-Output "  password-hash: $($counts.passwordHash)"
Write-Output "  jwt: $($counts.jwt)"
Write-Output "  key-gen: $($counts.keyGen)"
Write-Output "  config: $($counts.config)"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        totalFindings = $findings.Count
        hash = $counts.hash
        encryption = $counts.encryption
        passwordHash = $counts.passwordHash
        jwt = $counts.jwt
        keyGen = $counts.keyGen
        config = $counts.config
    }
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
