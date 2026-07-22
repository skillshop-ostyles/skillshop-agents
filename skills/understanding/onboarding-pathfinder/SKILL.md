---
name: onboarding-pathfinder
description: "Analyzes the topology of a codebase and generates a didactically sequenced reading tour with comprehension questions and first safe tasks. Trigger: /onboarding-pathfinder"
trigger: /onboarding-pathfinder
---
# /onboarding-pathfinder

## What this is for

New devs deserve a guided tour, not a README and "just ask". This skill
analyzes the topology of a codebase and generates a didactic reading tour with
comprehension questions and first safe tasks, so a newcomer can make their
first change without weeks of context-building.

Scans a codebase to produce:
- **Topology**: files grouped by category (config, entry, model, service, controller, test, etc.)
- **Reading tour**: files ordered in a didactic sequence with rationale per step
- **Comprehension questions**: auto-generated questions per file based on its role
- **First safe tasks**: ranked list of isolated, low-risk files suitable for newcomers

## What You Must Do When Invoked

1. If `-help` or `-h` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/onboard-scan.ps1 -ProjectDir "<path>" [-PassThru]`
4. LLM reads the JSON output, interprets the topology and tour, and tailors
   the onboarding guidance to the developer's background if known.
5. Output reading tour, comprehension questions, and first safe tasks.

## Usage

```
/onboarding-pathfinder                    # interactive
/onboarding-pathfinder <dir>              # analyze project
/onboarding-pathfinder -help              # show usage
```

Returns JSON with `topology`, `readingTour`, `comprehension`, and `firstSafeTasks`.
