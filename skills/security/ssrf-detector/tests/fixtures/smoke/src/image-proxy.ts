// Fixture for ssrf-detector.
// Scenarios: unsafe, safe, partially-validated, internal-service, metadata-risk.

import express from 'express';

// ================================================================
// 1. UNSAFE: image-proxy taking req.query.url, fetch-ing directly.
//    No URL validation whatsoever. Classic SSRF.
// ================================================================
export async function unsafeImageProxy(req: express.Request) {
    const url = (req.query.url as string) || '';
    const res = await fetch(url);
    return res.blob();
}

// ================================================================
// 2. SAFE: URL-parsed + scheme-checked + hostname-allowlisted.
//    Proper SSRF defence chain.
// ================================================================
const ALLOWED_HOSTS = ['images.cdn.example.com', 'static.cdn.example.com'];

export async function safeImageProxy(req: express.Request) {
    const raw = (req.query.url as string) || '';
    let parsed: URL;
    try {
        parsed = new URL(raw);
    } catch {
        return { error: 'invalid URL' };
    }
    if (!ALLOWED_HOSTS.includes(parsed.hostname)) {
        return { error: 'host not allowed' };
    }
    if (!parsed.protocol.startsWith('https:')) {
        return { error: 'only https allowed' };
    }
    const res = await fetch(parsed.toString());
    return res.blob();
}

// ================================================================
// 3. PARTIALLY VALIDATED: only scheme-check, no hostname
//    allowlist, no metadata-IP block. Still exploitable.
// ================================================================
export async function partialValidationProxy(req: express.Request) {
    const url = (req.query.url as string) || '';
    if (!url.startsWith('https://')) {
        return { error: 'only https allowed' };
    }
    const res = await fetch(url);
    return res.blob();
}

// ================================================================
// 4. SAFE (INTERNAL): hardcoded URL, no user input.
// ================================================================
export async function internalHealthCheck() {
    const res = await fetch('http://internal.monitor:9090/health');
    return res.text();
}

// ================================================================
// 5. METADATA RISK: user-controlled URL, parsed + scheme-checked
//    but NO metadata-IP blocking. Attacker passes
//    http://169.254.169.254/latest/meta-data/ with https scheme.
// ================================================================
export async function metadataExploitableProxy(req: express.Request) {
    const raw = (req.query.url as string) || '';
    let parsed: URL;
    try {
        parsed = new URL(raw);
    } catch {
        return { error: 'invalid URL' };
    }
    if (!parsed.protocol.startsWith('https:')) {
        return { error: 'only https allowed' };
    }
    // Missing: metadata-IP block for 169.254.x.x, 127.0.0.1, localhost
    const res = await fetch(parsed.toString());
    return res.blob();
}
