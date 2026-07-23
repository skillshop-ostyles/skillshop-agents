// Fixture for tls-config-drift.
// TLS config scenarios: safe, weak, cipher arrays, cert-pin, mTLS, validation.

import * as tls from 'tls';
import * as https from 'https';

// 1. Safe TLS config: TLSv1.2 with strong ciphers.
const safeOptions: tls.TlsOptions = {
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
    ciphers: 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305',
    secureOptions: tls.SSL_OP_NO_SSLv3 | tls.SSL_OP_NO_TLSv1 | tls.SSL_OP_NO_TLSv1_1,
};

// 2. Weak TLS version: TLSv1.0 with insecure protocol.
const weakOptions: tls.TlsOptions = {
    minVersion: 'TLSv1',
    secureProtocol: 'TLSv1_method',
};

// 3. Cipher array with weak suites (RC4, CBC-SHA, NULL-cipher).
const weakCiphers: https.ServerOptions = {
    ciphers: [
        'TLS_RSA_WITH_RC4_128_SHA',
        'TLS_RSA_WITH_AES_128_CBC_SHA',
        'TLS_RSA_WITH_NULL_MD5',
        'ECDHE-RSA-AES128-GCM-SHA256',
    ].join(':'),
};

// 4. Cert-pinning block using public key pinning (HPKP).
const pinningOptions = {
    publicKeyPinning: {
        keys: [
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
        ],
        includeSubDomains: true,
    },
    hpkp: {
        maxAge: 60000,
        sha256s: ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
    },
};

// 5. mTLS config with rejectUnauthorized and requestCert.
const mtlsOptions: tls.TlsOptions = {
    requestCert: true,
    rejectUnauthorized: true,
    ca: fs.readFileSync('/etc/certs/ca.pem'),
    cert: fs.readFileSync('/etc/certs/server.crt'),
    key: fs.readFileSync('/etc/certs/server.key'),
};

// 6. Cert-validation callback that bypasses hostname checks.
const server = tls.createServer({
    ...safeOptions,
    checkServerIdentity: (hostname, cert) => {
        return undefined; // bypass: accepts any certificate
    },
});

function validateCert(cert: any): boolean {
    const now = Date.now();
    if (cert.validTo < now || cert.validFrom > now) {
        return false;
    }
    return true;
}
