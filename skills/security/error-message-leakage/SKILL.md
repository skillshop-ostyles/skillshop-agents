---
name: error-message-leakage
description: "Error message leakage detector: harvests every HTTP-error-return and log-error-call, classifies what kind of information leaks (stacktrace, SQL error message, env-vars, user input echo, request dump). LLM validates each finding as legitimate production-leak and proposes sanitization. Read-only. Audience: Both. Trigger: /error-leakage"
trigger: /error-leakage
---

## What this is for

Production error-messages leaking stack-traces, SQL queries, file-paths,
secrets, internal IPs. `security-scan` and `security-smell-scanner` mark
generically "don't expose stack traces" - no tool reads the actual
production-return-codes and classifies what exact information reaches
the attacker. This skill catalogs every error-return and log-error call,
and the LLM classifies each as leak-by-info-type.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/error-returns.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - Is this a development-only error path? Does it run in production,
     dev-only (NODE_ENV=development), or test-only?
   - What information is leaked? (per `leakKind`): stacktrace gives
     file-paths+code; SQL error gives schema; env-vars give cloud keys;
     user-input echo gives reflection-injection surface.
   - Severity scale: stacktrace > SQL error > generic 'Error: X' > request dump.
   - Propose sanitization: convert `res.send(err)` to a sanitized error-id,
     log full context internally, return generic to caller.
5. Write `error-leakage-report.md` to the working directory.

## Usage

```
/error-leakage                            # interactive
/error-leakage <dir>                      # scan project
/error-leakage -help                      # show usage
```

Returns JSON with `findings[]`:
`{file, line, leakKind, surface, lineContent}` plus summary counts.
