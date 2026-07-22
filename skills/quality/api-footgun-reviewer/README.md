# API-Footgun Reviewer - /footguns

Reviews INTERNAL function/method signatures for misuse proneness:
boolean traps (saveFile(true, true)), same-type adjacent (send(from, to)),
inconsistent families (createUser vs createUserWithRole with different
param orders). Severity scaled by call-site count.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/api-footgun-reviewer ~/.claude/skills/
```

## Usage

```
/footguns                          # interactive
/footguns <dir>                    # scan project directory
```
