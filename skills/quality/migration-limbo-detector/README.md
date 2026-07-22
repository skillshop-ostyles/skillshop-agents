# Migration-Limbo Detector - /migration-limbo

Detects half-finished migrations: pattern schisms like axios+fetch, moment+date-fns,
jest+vitest, require+import, redux+zustand in the same repo. Reconstructs timeline
via git log per side, identifies which side is the target, ranks files by impact.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/migration-limbo-detector ~/.claude/skills/
```

## Usage

```
/migration-limbo                              # interactive, prompts for directory
/migration-limbo <dir>                        # scan project directory
/migration-limbo <dir> -CustomPairs "react,preact;mocha,vitest"
```
