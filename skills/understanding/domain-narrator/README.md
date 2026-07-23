# Domain Narrator — /explain

Reads all public symbols in a codebase, clusters them by call-graph density into business domains, and writes plain-English descriptions of what each domain does. Includes extracted business rules per cluster.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/domain-narrator ~/.claude/skills/
```

## Usage

```
/explain                           # interactive
/explain <dir>                     # scan project
```
