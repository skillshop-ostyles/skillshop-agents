# Log-Injection Detector - /log-injection

Harvests every console.log/logger.info/etc call. Per finding: attacker-controlled
input possible (CWE-117), CRLF injection surface, sensitive data leakage.
LLM classifies severity and proposes sanitization (parameterized logging,
newline stripping, redaction).

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/log-injection-detector ~/.claude/skills/
```

## Usage

```
/log-injection                            # interactive
/log-injection <dir>                      # scan project
```
