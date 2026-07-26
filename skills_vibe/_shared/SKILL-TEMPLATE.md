---
name: "{{SKILL_NAME}}"
description: "{{ONE_LINE_DESCRIPTION}}"
trigger: "/{{SKILL_NAME}}"
vibe: true
---

# /{{SKILL_NAME}}

## TL;DR

{{ONE_PARAGRAPH_SUMMARY}}

## Usage

- `/{{SKILL_NAME}}` — interactive wizard
- `/{{SKILL_NAME}} quick` — run all checks at once
- `/{{SKILL_NAME}} <sub>` — single check

## DIALOG PROTOCOL — STRICT

YOU MUST follow the decision tree in DIALOG.md.

### Rules
1. Every prompt MUST show numbered options `[N]` + `[0] Exit`
2. Every result MUST include diagnosis + explanation + implementation steps
3. Before any fix: show diff + ask confirmation `[y/n]`

## PROTECTION RULE — never ~/.claude/

Read-only by default. No writes without explicit user consent per operation.

## Checks

{{PER_CHECK_DETAILS}}

## Coaching per Finding

Each finding MUST include three levels:

| Level | What | Example |
|-------|------|---------|
| **Diagnosis** | What the script found | ... |
| **Explanation** | Why it matters | ... |
| **Implementation** | Steps to fix | ... |

## Confidence Levels

Assign per finding: **proven** (script evidence), **likely** (strong signal, needs review), **suspected** (weak signal).
