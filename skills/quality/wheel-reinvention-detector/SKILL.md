---
name: wheel-reinvention-detector
description: "Wheel reinvention detector: harvests exported short utility functions (≤40 lines, no class state) and pairs each with the project's installed libraries (package.json, requirements.txt) plus language stdlib hints. LLM judges whether each candidate semantically duplicates an existing stdlib or library API, names the replacement, and notes behavioral differences. Read-only. Audience: Both. Trigger: /reinvented-wheels"
trigger: /reinvented-wheels
---

## What this is for

Every codebase hides hand-rolled versions of `Array.prototype.flat`,
`lodash.groupBy`, `path.Combine`, or `retry-with-backoff`. Each one is
untested surface area a maintained library already solved. The collector
extracts short exported utility functions and pairs them with the project's
installed dependencies; the LLM recognizes semantic equivalence and names
the replacement.

Single lint rules exist for narrow cases (`unicorn/prefer-native`). No general
"did you mean to use the library you installed" detector exists before this.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/util-harvest.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each candidate short utility:
   - Read the function body.
   - Is this semantically equivalent to a stdlib feature of the language
     version, or to an API of an installed library?
   - Name the exact replacement (function or method).
   - Note behavioral differences: edge cases the custom version catches or
     misses compared to the library equivalent.
5. Classify: `reinvented-stdlib` / `reinvented-library` / `custom-domain`
   (legitimate, do not replace).
6. Write `reinvented-wheels-report.md` to the working directory.

## Usage

```
/reinvented-wheels                             # interactive
/reinvented-wheels <dir>                       # scan project directory
/reinvented-wheels -help                       # show usage
```

Returns JSON with `candidates[]` (short util functions), `installedLibs[]`,
`semanticHints{}`, plus summary counts.
