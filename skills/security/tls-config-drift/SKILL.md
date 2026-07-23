---
name: tls-config-drift
description: "TLS config drift scanner: harvests every TLS-version constant, cipher-suite array, cert-pinning call, mTLS flag, cert-validation callback, and FIPS-mode setting. LLM analyses each statement as acceptable, misconfigured, or downgrade-prone when an element is missing. Read-only. Audience: Senior. Trigger: /ssl-drift"
trigger: /ssl-drift
---

## What this is for

TLS configuration drifts silently: a developer adds TLS_RSA_WITH_RC4_128_SHA to
a cipher array, pins the wrong public-key fingerprint, or forgets `rejectUnauthorized`
in an mTLS setup. `security-smell-scanner` flags generic "use TLS 1.2+" — no tool
reads the actual cipher suites and cert-pin values and classifies each as acceptable
vs downgrade-risk. This skill catalogs every TLS-relevant statement, and the LLM
classifies each by drift-type.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/tls-config-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - **TLS version**: is it TLSv1.2+ (acceptable) or TLSv1/TLSv1.1 (deprecated)?
   - **Cipher suite array**: any NULL-cipher, RC4, CBC-SHA, or export-grade suite? Is the array restrictive or overly permissive?
   - **Cert pinning**: is the fingerprint correct for the current certificate? Is HPKP used (deprecated/dangerous)?
   - **mTLS**: is `rejectUnauthorized` set to `true`? Is `requestCert` paired with `ca`?
   - **Cert validation**: does `checkServerIdentity` bypass checks? Is a custom validator weakening security?
   - **FIPS mode**: is it explicitly enabled? Is it consistent across the project?
   - **Downgrade risk**: if a config element is missing (e.g., no `minVersion`), what is the implicit default?
   - Severity scale: FIPS-disabled > weak pin > TLSv1.1 > TLSv1.2 with wide cipher > missing mTLS flag.
5. Write `tls-config-drift-report.md` to the working directory.

## Usage

```
/ssl-drift                              # interactive
/ssl-drift <dir>                        # scan project
/ssl-drift -help                        # show usage
```

Returns JSON with `findings[]`:
`{file, line, findingType, lineContent}` plus summary counts.
