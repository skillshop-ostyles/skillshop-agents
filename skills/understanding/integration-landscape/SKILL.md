---
name: integration-landscape
description: "Maps every external integration from code: HTTP APIs, databases, message queues, storage. Classifies protocol, auth type, criticality, retry/fallback coverage. Read-only. Audience: Senior. Trigger: /integrations"
trigger: /integrations
---

## What this is for

Every project calls external services. When Stripe is down, what breaks? When SendGrid times out, does the whole API fail or just the email feature? This skill maps all integrations with their criticality, resilience patterns, and outage impact.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/integration-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. Per integration:
   - What is this integration used for? What business feature depends on it?
   - What happens when the service is down? Graceful degradation or crash?
   - Is there a fallback/circuit-breaker/retry? If not, was the risk accepted?
   - What monitoring signals exist (health check, timeout, error tracking)?
5. Write `integration-landscape.md` to the working directory.

## Usage

```
/integrations                            # interactive
/integrations <dir>                      # scan project
/integrations -help                      # show usage
```

Returns JSON with `integrations[]` each having `{type, target, protocol, authType, criticality, hasRetry, hasFallback}`.
