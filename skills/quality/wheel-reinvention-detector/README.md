# Wheel-Reinvention Detector - /reinvented-wheels

Harvests exported short utility functions (≤40 lines) and pairs them with the
project's installed libraries. LLM judges whether each candidate duplicates a
stdlib feature or installed dependency's API and names the replacement.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/wheel-reinvention-detector ~/.claude/skills/
```

## Usage

```
/reinvented-wheels                             # interactive
/reinvented-wheels <dir>                       # scan project directory
```
