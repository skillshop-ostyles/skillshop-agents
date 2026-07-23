---
name: ssrf-detector
description: "SSRF detector: finds every outbound HTTP call (fetch, axios, got, http, requests, HttpClient, Invoke-RestMethod) where the URL is user-controlled (req.body/req.query/req.params) and grades URL-pre-fetch validation (URL-parse, hostname allowlist, metadata-IP blocking). LLM per-URL-flow classifies user-control, pre-validation quality, and metadata-service exploitation risk (169.254.169.254). Read-only. Audience: Senior. Trigger: /ssrf-detector"
trigger: /ssrf-detector
---

## What this is for

Every `fetch(url)` where `url` comes from `req.query.url` is an SSRF
opportunity. Attackers route through the server to scan internal networks
or hit the cloud metadata service (169.254.169.254) for IAM credentials.
Existing scanners flag "no URL validation" generically — this skill
inventories each sink, traces whether the URL is user-controlled, and
grades each validation layer present (scheme, hostname, metadata-IP
blocking, DNS resolution check).

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/ssrf-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each URL-flow finding:
   - **User-controlled?** Does the URL descend from `req.body.*`,
     `req.query.*`, `req.params.*`, `event.body.*`, `context.args.*`?
   - **Pre-validated?** Is the URL parsed (`new URL(url)`), scheme-checked
     (`startsWith('https://')`), hostname-allowlisted (`allowlist.includes`),
     metadata-IP blocked (`169.254` / `127.0.0.1` / `localhost` checked)?
     Collect which `validationTypes[]` are present.
   - **Metadata-service risk:** If the attacker controls the URL, can they
     point it at `http://169.254.169.254/latest/meta-data/` to steal cloud
     provider IAM credentials? No metadata-IP block = high risk.
5. Write `ssrf-detector-report.md` to the working directory.

## Usage

```
/ssrf-detector                          # interactive
/ssrf-detector <dir>                    # scan project
/ssrf-detector -help                    # show usage
```

Returns JSON with `findings[]`:
`{file, line, sinkType, hasUserControl, hasValidation, validationTypes[], code}` plus summary counts.
