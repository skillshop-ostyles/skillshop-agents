# spec-lie-detector

Available - **Trigger:** `/spec-check` - **Risk:** read-only

> Before you build the wrong thing: does the spec withstand the truth?

Reads a corpus of specs/tickets (text files) and finds contradictions, gaps,
ambiguities, silent assumptions and untestable statements - each finding with quote,
location, severity and a concrete clarification question for the product owner.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/intake.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows.
  On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/spec-lie-detector ~/.claude/skills/quality/spec-lie-detector
# or project-local:
cp -r skill-shop-agents/skills/quality/spec-lie-detector <your-project>/.claude/skills/quality/spec-lie-detector
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\spec-lie-detector $HOME\.claude\skills\quality\spec-lie-detector
```

## Usage

In Claude Code:

```
/spec-check                    # interactive: ask for spec directory
/spec-check <dir>              # check all text files under <dir>
/spec-check <file1> <file2>    # check explicit files
/spec-check -help             # short help
```

Details: [`SKILL.md`](SKILL.md).
