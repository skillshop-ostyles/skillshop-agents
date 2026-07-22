# security-smell-scanner — /config-map

Statically detect 10 families of security anti-patterns across a codebase:
SQL injection, XSS, command injection, path traversal, hardcoded credentials,
insecure defaults, IDOR, open redirect, TOCTOU, and missing input validation.

## Quick Install

```bash
# Clone the repo (if not already)
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git

# Copy the skill to your Claude skills directory
cp -r skill-shop-agents/skills/security/security-smell-scanner ~/.claude/skills/
```

## How It Works

1. **Collector** (`scripts/security-scan.ps1`) — regex-based heuristic scan over all
   source files. Finds candidate smells, extracts context snippets, assigns initial
   severity based on pattern type.
2. **LLM analysis** — validates each candidate by reading the context block.
   Filters false positives (e.g. parameterized ORM calls that look like SQL),
   adjusts severity based on reachability, and masks credential values.

## Usage with Claude

```
/config-map                           # interactive
/config-map /path/to/your/project     # scan directory
/config-map --help
```

## Output

- `security-smell-report.md` — full report with executive summary, critical findings,
  medium findings, false positive log, and open questions.
- Console summary with counts broken down by severity and pattern.

## Audience

**Senior > Vibe** — structured enough for a senior to use as a systematic
review tool, explanatory enough for a vibe-coder to learn from each finding.

This skill is a **cross-link** between the `security/` cluster (where it
physically lives) and the `quality/` cluster (where it thematically belongs
alongside other code-smell detectors).
