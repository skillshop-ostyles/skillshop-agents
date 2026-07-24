# ssrf-detector

**Trigger:** `/ssrf-detector` | **Risk:** read-only | **Audience:** Senior

> SSRF detector: finds every outbound HTTP call (fetch, axios, got, http, requests, HttpClient, Invoke-RestMethod) wher...

SSRF detector: finds every outbound HTTP call (fetch, axios, got, http, requests, HttpClient, Invoke-RestMethod) where the URL is user-controlled (req.body/req.query/req.params) and grades URL-pre-fetch validation (URL-parse, hostname allowlist, metadata-IP blocking). LLM per-URL-flow classifies user-control, pre-validation quality, and metadata-service exploitation risk (169.254.169.254).

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/ssrf-detector $HOME/.claude/skills/security/ssrf-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/ssrf-detector $HOME\.claude\skills\security\ssrf-detector
```

## Usage

```
/ssrf-detector                    # interactive - prompts for target
/ssrf-detector <project-dir>      # scan specified project
/ssrf-detector -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: detector-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


