---
name: prompt-quality-auditor
description: "Prompt quality auditor: audit every prompt for clarity, safety, and injection resistance. Read-only. Trigger: /prompt-quality"
trigger: /prompt-quality
---
# /prompt-quality

Prompts are the most critical code you never review. This skill finds quality issues before they cause bad outputs.

## What this is for

- Prompts without output format specification (model guesses format)
- Missing safety instructions (model complies with harmful requests)
- User input directly in prompt without sanitization (injection)
- **Read-only skill.** No prompt modifications.

## What You Must Do When Invoked

If `/prompt-quality -help` or `/prompt-quality -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/prompt-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Classification

Read each prompt:

- **Structured**: has output format spec + constraints
- **Semi-structured**: has some guidance
- **Open-ended**: no constraints on output
- **Injection-susceptible**: user input directly in prompt

### Step 4 - Write report

File `prompt-quality-report.md` in current working directory:

1. **Summary** - prompts by classification.
2. **Prompt table** - injection-susceptible first. Per prompt: file, line, type, has format spec, has safety instructions, risk, recommendation.
3. **Open questions**.

### Step 5 - Summarize

State report path, highlight prompts that could produce harmful or unreliable outputs.

## Usage

```
/prompt-quality               # interactive
/prompt-quality <dir>         # scan project
/prompt-quality -help
```
