# Changelog-Narrator - /changelog

Reads the diff between two tags/commits, clusters changes into logical groups
(features, bugfixes, refactoring, dependencies), and writes a semantic changelog
with breaking changes, migration notes, and deployment risk.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/changelog-narrator ~/.claude/skills/
```

## Usage

```
/changelog                            # interactive (default HEAD~10..HEAD)
/changelog <dir>                      # scan project
/changelog <dir> -FromRef v1.0 -ToRef v1.1
```

## Output

- `CHANGELOG.md` — full semantic changelog with sections per module
- JSON with `commits[]`, `files[]`, `modules[]`, `stats{}`, `changeSummary{}`
