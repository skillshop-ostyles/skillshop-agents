# Rate-Limit-Shape Analyzer - /rate-shape

Inventories rate-limit decorators per-route (express-rate-limit, flask-limiter,
DRF throttle, Spring). Per endpoint, classifies whether it has a decorator,
what the limits are, and whether mutating endpoints that should be limited are.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/rate-limit-shape-analyzer ~/.claude/skills/
```

## Usage

```
/rate-shape                              # interactive
/rate-shape <dir>                        # scan project
```
