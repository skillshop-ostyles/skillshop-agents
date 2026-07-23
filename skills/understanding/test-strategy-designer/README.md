# Test-Strategy Designer - /test-strategy

Classifies every test file as Unit, Integration, or E2E per framework imports +
setup patterns. Builds the test pyramid profile (ideal 60/30/10), detects
untested modules, and identifies overly expensive tests.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/test-strategy-designer ~/.claude/skills/
```

## Usage

```
/test-strategy                           # interactive
/test-strategy <dir>                     # scan project
```

## Output

- `testPyramid{unit, integration, e2e, total}` — distribution vs 60/30/10 ideal
- `untestedModules[]` — source modules with no corresponding test file
- `assertionStats{}` — assertion count per test file
- `mockComplexity{}` — mock/stub count per test file
