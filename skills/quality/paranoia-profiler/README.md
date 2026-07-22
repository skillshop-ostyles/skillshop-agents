# Paranoia Profiler - /paranoia

Catalogs every defensive guard (null/undefined/empty/typeof/try-catch/instanceof).
LLM judges each guard for impossibility (paranoid zone) or under-defense
(naive zone on external inputs). Both extremes flagged in the same report.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/paranoia-profiler ~/.claude/skills/
```

## Usage

```
/paranoia                         # interactive
/paranoia <dir>                   # scan project directory
```
