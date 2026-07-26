# flask-anti-pattern-detector

**Trigger:** `/flask-detector` | **Risk:** read-only | **Audience:** Senior

> Flask anti-pattern detector: scans Flask projects for hardcoded SECRET_KEY, debug-mode in production, dangerous templ...

Flask anti-pattern detector: scans Flask projects for hardcoded SECRET_KEY, debug-mode in production, dangerous template rendering (render_template_string), pickle/eval/exec on request data, unsafe session config, SQL injection via raw queries, insecure file upload, and debug toolbar enabled. LLM validates each finding and proposes modern alternatives.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/flask-anti-pattern-detector $HOME/.claude/skills/security/flask-anti-pattern-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/flask-anti-pattern-detector $HOME\.claude\skills\security\flask-anti-pattern-detector
```

## Usage

```
/flask-detector                    # interactive - prompts for target
/flask-detector <project-dir>      # scan specified project
/flask-detector -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: detector-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


