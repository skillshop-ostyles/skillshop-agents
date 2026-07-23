---
name: config-surface-documenter
description: "Extracts the full configuration surface from code (env vars, config files, CLI flags) and generates a human-readable reference with descriptions, types, defaults, and effects. Read-only. Audience: Both. Trigger: /config-docs"
trigger: /config-docs
---

## What this is for

Every env var, config file, and CLI flag lives in code - but none is documented. New developers hunt through code to find what PORT defaults to. This skill extracts the entire configuration surface and generates a reference manual.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/config-doc-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. Per config key:
   - What does this key control? Describe in one sentence.
   - What is the effect of changing the value?
   - Is this safety-critical (secret, production flag)?
   - Is there a recommended default for production vs development?
   - Is the key orphaned (defined but never read)?
5. Write `config-reference.md` to the working directory.

## Usage

```
/config-docs                            # interactive
/config-docs <dir>                      # scan project
/config-docs -help                      # show usage
```

Returns JSON with `configKeys[]` each having `{name, source, type, defaultValue, usageSites[], isSecret}`.
