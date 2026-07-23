# Session State Anomaly - /session-anomaly

Scans authentication middleware for session lifecycle defects: missing
regeneration after login (session fixation), missing destroy after logout
(lingering session), missing refresh-token rotation (long-lived token).

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/session-state-anomaly ~/.claude/skills/
```

## Usage

```
/session-anomaly                            # interactive
/session-anomaly <dir>                      # scan project
```
