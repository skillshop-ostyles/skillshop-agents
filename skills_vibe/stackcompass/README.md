# stackcompass

**Trigger:** `/stackcompass` | **Risk:** read-only (conversation only) | **Audience:** Vibe

> Tech-stack advisor: understand your project context, compare 2-3 stack options with trade-offs, get an action plan. For vibe coders.

You have an idea. You're not sure which tech stack fits. Stackcompass asks 5-7 questions about your project, team, and constraints — then presents 2-3 concrete stack options with trade-offs, risks, and a step-by-step action plan.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/stackcompass $HOME/.claude/skills_vibe/stackcompass
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/stackcompass $HOME\.claude\skills_vibe\stackcompass
```

## Usage

```
/stackcompass               # interactive wizard
/stackcompass quick         # quick session, fewer questions
/stackcompass save          # save report as stackcompass-report.md
/stackcompass -help         # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- Conversation only — no target project required
