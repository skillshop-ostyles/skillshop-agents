---
name: third-party-trust
description: "Third-party trust boundary analyzer: inventories every outbound HTTP/RPC call (fetch, axios, got, requests, curl, Invoke-RestMethod). For each, identifies literal-vs-template URL, classifies known-trusted vs unknown domain, detects auth-header presence in call window, flags webhook handlers missing signature verification. Read-only. Audience: Senior. Trigger: /third-party-trust"
trigger: /third-party-trust
---

## What this is for

Fetch/axios/Supabase/Stripe calls are TRUST BOUNDARIES going OUTWARD.
Which outbound calls accept user-controlled URLs without re-validation?
Which API key has no origin restriction? Which webhook receiver lacks
signature verification? `input-validation-audit` checks input-validation
coming IN. Missing: outbound trust contract - the mapping of what WE
trust to be on the other end of each outbound connection.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/outbound-calls.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each outbound call:
   - **Known-trusted vs unknown**: stripe/amazon/googleapis/etc vs
     arbitrary endpoint. Unknown providers = higher risk.
   - **Template URL**: variable-based URL (e.g. `req.query.url`) is
     attacker-controlled. SSRF-class risk.
   - **Auth hint in call window**: Authorization header / api-key /
     bearer present? If yes, rotation-burden risk.
   - **Webhook handler** with no signature verification (look for
     `webhooks.constructEvent` or HMAC verify calls - if absent, the
     endpoint will accept forged events).
   - **Retry attempt count**: 3+ retries with no idempotency-key →
     duplicate side-effects on a 5xx.
5. Write `third-party-trust-report.md` to the working directory.

## Usage

```
/third-party-trust                          # interactive
/third-party-trust <dir>                    # scan project
/third-party-trust -help                    # show usage
```

Returns JSON with `calls[]`:
`{file, line, lib, url, isTemplateUrl, authHint, retrySignals,
webhookHandler, lineContent}` plus summary counts.
