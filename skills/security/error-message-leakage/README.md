# Error-Message Leakage - /error-leakage

Catalogs every HTTP-error-return and log-error-call. Per finding: kind of
information leaked (stacktrace, SQL error text, env-vars, user-input echo,
request dump). LLM classifies severity and proposes sanitization.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/error-message-leakage ~/.claude/skills/
```

## Usage

```
/error-leakage                            # interactive
/error-leakage <dir>                      # scan project
```
