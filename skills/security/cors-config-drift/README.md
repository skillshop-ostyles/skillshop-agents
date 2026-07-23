# CORS-Config-Drift - /cors-drift

Harvests every `Access-Control-Allow-Origin` header, `cors()` middleware call,
`@cross_origin` decorator, and options-handler with CORS config. LLM classifies each
per-route posture as safe, permissive, or fatally insecure (credentials + wildcard).

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/cors-config-drift ~/.claude/skills/
```

## Usage

```
/cors-drift                              # interactive
/cors-drift <dir>                        # scan project
```
