# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in an AGENTS collector script or
workflow, please report it privately **before** disclosing it publicly.

**Do not open a public GitHub issue.**

Send details to the maintainers via opening a draft security advisory at:
https://github.com/skillshop-ostyles/skillshop-agents/security/advisories/new

We aim to acknowledge receipt within 48 hours and provide a fix timeline
within 5 business days.

## Scope

- Collector scripts (`scripts/*.ps1`) that read user project files.
- SKILL.md instructions that may produce insecure agent behavior.
- Output contracts that may leak sensitive data.

## Out of Scope

- The target project being analyzed (skills are read-only auditors).
- LLM provider API security (OpenAI, Anthropic, etc.).
