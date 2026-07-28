# blitzplan

**Trigger:** `/blitzplan` | **Risk:** read-only (conversation only) | **Audience:** Vibe

> Lightweight design coach: 3-5 questions, a clear spec, no code until you approve. Inspired by superpowers, built for vibe coders.

Before you prompt code: blitzplan helps you clarify scope, tech stack, and auth model in 3-5 questions. No code until you approve the design.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/blitzplan $HOME/.claude/skills_vibe/blitzplan
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/blitzplan $HOME\.claude\skills_vibe\blitzplan
```

## Usage

```
/blitzplan <description>    # start a design session
/blitzplan quick            # 3 questions, ready in 2 minutes
/blitzplan full             # up to 5 questions, more depth
/blitzplan -help            # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- Conversation only — no target project required
