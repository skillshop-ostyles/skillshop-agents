---
name: api-surface-documenter
description: "API surface documenter: extracts ALL API surface types from a codebase — REST routes, event handlers, CLI commands, library exports. Classifies stability and generates a complete reference. No Swagger decorations needed. Read-only. Audience: Both. Trigger: /api-survey"
trigger: /api-survey
---

## What this is for

Every codebase has an API surface — REST endpoints, event listeners, CLI
commands, and library exports — but it's rarely documented in one place.
Swagger/OpenAPI only covers REST. This skill finds ALL four surface types
from source code patterns alone, classifies each by stability and audience
(internal vs external), and produces a complete reference.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/api-survey.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each API:
   - **Usage pattern:** How is this API typically called? What are the
     conventions in this codebase?
   - **Breaking-change risk:** Would changing the signature/route/event-name
     break callers? Is it exported externally?
   - **Undocumented assumptions:** Are there implicit preconditions (auth
     required, rate-limited, idempotent)?
   - **Missing examples:** Is there a usage example in docs/tests? If not,
     note it.
5. Write `api-surface-reference.md` to the working directory.

## Usage

```
/api-survey                          # interactive
/api-survey <dir>                    # scan project
/api-survey -help                    # show usage
```

Returns JSON with `apis[]`:
`{file, line, apiType (rest/event/cli/lib), name, method (for rest), route/event/command, params[], hasDocs}` plus summary counts.

<｜DSML｜tool_calls>
<｜DSML｜invoke name="write">
<｜DSML｜parameter name="filePath" string="true">C:\Users\ostol\Desktop\AGENTS\skills\understanding\api-surface-documenter\README.md