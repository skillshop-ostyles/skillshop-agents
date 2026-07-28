# polish

**Trigger:** `/polish` | **Risk:** read-only / write-on-approval | **Audience:** Vibe

> AI residue removal coach: console.log, any types, missing fallbacks, magic strings, dead imports, AI hallucination patterns.

AI-generated code leaves traces. Polish finds and fixes them — 6 checks in 1 minute. Interactive coaching wizard with fix mode.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/polish $HOME/.claude/skills_vibe/polish
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/polish $HOME\.claude\skills_vibe\polish
```

## Usage

```
/polish                     # interactive coaching wizard
/polish quick               # all 6 checks at once
/polish consolelog          # debug residue only
/polish anytype             # type escapes only
/polish nofallback          # missing fallbacks only
/polish magic               # magic values only
/polish deadimport          # dead imports only
/polish aismell             # AI smell detector only
/polish -help               # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code
