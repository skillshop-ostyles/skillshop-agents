---
name: secret-lifecycle-auditor
description: "Secret lifecycle auditor: inventories every secret-shaped key/value across .env, k8s manifests, Vault configs, IAM refs, terraform. Per secret: age from git log -S, masked value (first-8/last-4), reachability-check against installed dependencies, type guess from key prefix. LLM judges rotation cadence and emits prioritized rotate-now / rotate-soon / remove-dead list. Read-only. Audience: Senior. Trigger: /secret-lifecycle"
trigger: /secret-lifecycle
---

## What this is for

Trufflehog/Gitleaks (and our `security-scan`) find the EXISTENCE of
hardcoded secrets. They do not answer: is the secret still active, who
owns it, is there a rotation policy, is the documented rotation overdue,
has the secret been expired-but-not-revoked. This skill inventories every
secret reference, reconciles them via git age and dependency reachability,
and the LLM judges each one's lifecycle health.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/secret-census.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each secret:
   - Identify likely owner (last author of relevant file, via git).
   - Classify by type (api-key, db-password, jwt, admin, hmac-secret).
   - Recommend rotation cadence (API 90d, DB 60d, admin 30d, JWT 30d, HMAC per usage).
   - Flag dead: no dependency reaches this secret (check
     `referencedByDeps` plus manual grep).
   - Flag stale: `ageDays > 180` AND in active use.
5. Write `secret-lifecycle-report.md` to the working directory.

## Usage

```
/secret-lifecycle                          # interactive
/secret-lifecycle <dir>                    # scan project
/secret-lifecycle <dir> -SecretFilePatterns ".env,*.tf"
/secret-lifecycle -help                    # show usage
```

Returns JSON with `secrets[]`:
`{key, file, line, maskedValue, length, firstCommit, firstSubject,
ageDays, serviceGuess, referencedByDeps}` plus summary counts.
