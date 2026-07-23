# Tech-Debt Narrator - /tech-debt

Finds suppress comments, TODOs, empty catches, workarounds, legacy imports, and type-loosening patterns. Clusters them into logical groups and narrates repayment strategies with effort estimates.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/tech-debt-narrator ~/.claude/skills/
```

## Usage

```
/tech-debt                           # interactive
/tech-debt <dir>                     # scan project
```

Returns JSON with `debts[]` (file, line, type, text, ageDays, severity) and `counts{}`.
