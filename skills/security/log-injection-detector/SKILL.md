---
name: log-injection-detector
description: "Log injection detector: harvests every console.log/logger.info/log.Error/etc call, classifies arguments for attacker-controlled input (CWE-117), CRLF injection surface, sensitive data leakage (passwords, tokens, secrets). LLM validates each finding as injectable and proposes sanitization (parameterized logging, newline stripping, sensitive-field redaction). Read-only. Audience: Senior. Trigger: /log-injection"
trigger: /log-injection
---

## What this is for

User input flowing into log statements: CRLF-injection (`logger.info(userInput)`),
sensitive data logged (passwords, tokens), log-entries that attacker can forge
via newlines in user content. `data-trail-tracker` finds where PII lands;
doesn't surface CWE-117 log-injection attack vectors. This skill catalogs every
log-statement call, classifies each argument for injection risk, and proposes
sanitization per finding.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/log-arg-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - **Has user input?** Does the log call include `req.body`, `req.query`,
     `req.params`, `input`, `event.body`, `message.body`, or any directly
     passed HTTP request-derived variable?
   - **CRLF injection possible?** Is the argument unsanitized — concatenated
     with `+`, template-literal-interpolated with variables, passed raw to
     `logger.info(userVar)` — allowing attacker-controlled line breaks?
   - **Sensitive data leaked?** Do arguments contain keywords like `password`,
     `secret`, `token`, `key`, `auth`, `session`, `cookie`, `credit`, `ssn`,
     `email` — data that forensic attackers would harvest from log files?
   - **Payload impact:** What can attacker achieve via forged log entries?
     (log-poisoning, SIEM-alert evasion, incident-response misdirection,
     credential harvesting from logs.)
5. Write `log-injection-report.md` to the working directory.

## Usage

```
/log-injection                            # interactive
/log-injection <dir>                      # scan project
/log-injection -help                      # show usage
```

Returns JSON with `findings[]`:
`{file, line, callText, hasUserInput, hasSensitiveData, userInputSources[],
sensitiveKeys[], unsanitizedPlus, unsanitizedTemplate, hasCRLFRisk}` plus
summary counts.
