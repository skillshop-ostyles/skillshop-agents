# Magic-Value Genealogist - /magic-values

Extracts and genealogically analyzes magic numbers and uppercase-string constants outside
tests. Groups occurrences, traces first-appearance commit + author, helps the LLM decide if
a literal should be unified into one named constant.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/magic-value-genealogist ~/.claude/skills/
```

## Usage

```
/magic-values                         # interactive, prompts for directory
/magic-values <dir>                   # scan project directory
/magic-values <dir> -MinOccurrence 3 # raise the bar
```
