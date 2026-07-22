# Clone-Drift Tracker - /clone-drift

Detects code blocks that USED to be clones and have since drifted apart. Mines git history
to find functions whose body hash matches at `HEAD~N` but differs at HEAD - one side got
a bugfix or migration the twin did not. Read-only.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/clone-drift-tracker ~/.claude/skills/
```

## Usage

```
/clone-drift                            # interactive
/clone-drift <dir>                      # against HEAD~100
/clone-drift <dir> -PastRef "v1.4.0"
```
