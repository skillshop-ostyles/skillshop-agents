---
name: session-state-anomaly
description: "Session state anomaly scanner: finds every session-generation, session-id usage, post-auth session-regeneration, post-logout cleanup, and refresh-token rotation site. LLM per finding: regen? invalidate? rotated? What attack arises if not? Read-only. Audience: Senior. Trigger: /session-anomaly"
trigger: /session-anomaly
---

## What this is for

Missing `session.regenerate()` after login = session fixation attack.
Missing `session.destroy()` after logout = session lingers, hijackable
if token was stolen. Missing refresh-token rotation = long-lived token
window. Generic `security-scan` flags none of these — they require
understanding the session lifecycle per mutation point.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/session-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding per sessionType:
   - **creation**: Does the caller call `regenerate` within the next 5 lines?
     If not = session fixation risk.
   - **login**: Is `regenerate()` called inside the successful auth branch?
     If not = session fixation risk.
   - **regenerate**: Already present — verify it's in the auth-success path
     and not orphaned.
   - **logout**: Is `destroy()` / `clearCookie()` / `session.clear()` called?
     If not = lingering session risk.
   - **jwt/refresh**: Is `rotateRefresh` / `newRefresh` called on refresh?
     If not = long-lived refresh token window.
5. Write `session-state-report.md` to the working directory.

## Usage

```
/session-anomaly                            # interactive
/session-anomaly <dir>                      # scan project
/session-anomaly -help                      # show usage
```

Returns JSON with `findings[]`:
`{file, line, sessionType, code, hasRegen, hasInvalidate, hasRotate}`
plus summary counts and `anomalies[]`.
