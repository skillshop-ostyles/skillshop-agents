// Fixture for crypto-downgrade-detector.
// Scenarios: weak algorithms, modern alternatives, JWT misuse, password hashing, key gen, config bypass.

import crypto from 'crypto';

// 1. Weak: deprecated Node createCipher with AES-256-CBC (no IV, password-derived key).
const password = 'super-secret-password';
const cipher = crypto.createCipher('aes-256-cbc', password);
let encrypted = cipher.update('plaintext', 'utf8', 'hex');
encrypted += cipher.final('hex');

// 2. Modern: Web Crypto API subtle.encrypt with AES-GCM.
async function encryptModern(plain: Buffer, key: CryptoKey): Promise<Buffer> {
    const iv = crypto.randomBytes(12);
    const encrypted = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv: iv },
        key,
        plain
    );
    return Buffer.from(encrypted);
}

// 3. Weak: MD5 hash usage.
const md5hash = crypto.createHash('md5').update('password').digest('hex');
console.log('MD5 hash (weak):', md5hash);

// 4. JWT with hardcoded secret string (HS256 symmetric, no key rotation).
import jwt from 'jsonwebtoken';
const token = jwt.sign({ userId: 123, role: 'admin' }, 'hardcoded-jwt-secret-2024', { algorithm: 'HS256' });
const decoded = jwt.verify(token, 'hardcoded-jwt-secret-2024');
console.log('JWT (hardcoded secret):', decoded);

// 5. bcrypt compare with constant-time safe call.
import bcrypt from 'bcrypt';
const hash = bcrypt.hashSync('user-password', 12);
const match = bcrypt.compareSync('user-password', hash);
console.log('bcrypt match:', match);

// 6. Weak HMAC with SHA1.
const hmac = crypto.createHmac('sha1', 'key');
hmac.update('message');
const digest = hmac.digest('hex');
console.log('HMAC-SHA1 (weak):', digest);

// 7. Key generation - generateKeyPair with RSA-4096 (modern, acceptable).
crypto.generateKeyPair('rsa', {
    modulusLength: 4096,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
}, (err, publicKey, privateKey) => {
    if (err) throw err;
    console.log('RSA-4096 key pair generated');
});
