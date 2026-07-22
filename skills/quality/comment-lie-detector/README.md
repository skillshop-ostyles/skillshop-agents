# Comment-Lie Detector - /comment-lies

## What this is for

Comments are the only part of code nobody tests. They are written once,
read many times, and silently rot. This skill extracts every comment that
makes a verifiable claim about behavior ("returns null on error", "thread-safe",
"never called with empty list", "side-effect-free") and pairs each with 30 lines
of the code it describes, so the LLM can judge whether the code does what
the comment promises.

The dominant failure mode is the load-bearing comment that lies quietly for
months until someone relies on it.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/comment-harvest.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each behavioral claim:
   - Read the `codeContext` (30 lines surrounding the comment).
   - Does the adjacent code do exactly what the comment states?
   - Classify: `consistent` / `contradicts` / `outdated` / `unverifiable`.
5. Confidence: `proven` (direct code evidence), `likely` (multiple lines agree),
   `suspected` (inference).
6. Write `comment-lie-report.md` to the working directory.

## Usage

```
/comment-lies                         # interactive, prompts for directory
/comment-lies <dir>                   # scan project directory
/comment-lies -help                   # show usage
```

Returns JSON with `claims[]`: each entry `{file, line, text, kind, codeContext}`
plus summary `counts: {scannedFiles, totalClaims, byKind}`.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/comment-lie-detector ~/.claude/skills/
```

## Audience

Both - seniors use it as evidence-based doc health check, vibe-coders learn
which comments survive scrutiny and which to delete.
