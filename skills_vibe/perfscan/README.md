# perfscan

**Trigger:** `/perfscan` | **Risk:** read-only | **Audience:** Vibe

> Performance coach: 7 impact-prioritized checks for React/Next.js apps. Interactive wizard + batch mode.

Perfscan analyzes your React/Next.js project for 7 common performance issues — unnecessary re-renders, layout shifts, missing key props, oversized images, client-side bloat, bundle size, useEffect anti-patterns. Impact-prioritized findings with coaching.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills_vibe/perfscan $HOME/.claude/skills_vibe/perfscan
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills_vibe/perfscan $HOME\.claude\skills_vibe\perfscan
```

## Usage

```
/perfscan                   # interactive wizard
/perfscan quick             # all 7 checks at once
/perfscan useeffect         # useEffect anti-patterns
/perfscan render            # re-render issues
/perfscan layoutshift       # layout shift detection
/perfscan keyprops          # missing key props
/perfscan images            # oversized images
/perfscan client            # client-side bloat
/perfscan bundle            # bundle size
/perfscan -help             # show full usage and stop
```

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)
User-friendly guide: [`VIBE.md`](VIBE.md) (German)
Dialog protocol: [`DIALOG.md`](DIALOG.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code
