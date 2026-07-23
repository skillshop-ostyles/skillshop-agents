# Type-Confusion Bypass Detector - /bypass-detector

Traces validation paths from input source to storage/execution sink. Per
finding: what validation is applied, what sink it protects, and what edge-case
input shapes (str/int/obj/null/array) could bypass the check. LLM classifies
bypass-availability and proposes query-construction fixes.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/type-confusion-bypass-detector ~/.claude/skills/
```

## Usage

```
/bypass-detector                            # interactive
/bypass-detector <dir>                      # scan project
```
