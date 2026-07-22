# Invariant Miner - /invariants

Mines hidden invariants from code structure statically. Each pattern signal
(array[0], division-by-computed, JSON.parse-trust) becomes a candidate
invariant that LLM judges as guaranteed-by-construction vs fragile.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/invariant-miner ~/.claude/skills/
```

## Usage

```
/invariants                       # interactive
/invariants <dir>                 # scan project directory
```
