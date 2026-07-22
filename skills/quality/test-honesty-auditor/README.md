# Test-Honesty Auditor - /test-honesty

## What this is for

A green test suite means nothing if the tests cannot fail. This skill audits
test files for the failure modes that turn coverage into theater: tests
without assertions, tautological assertions (`expect(true).toBe(true)`), tests
that assert on mocks they themselves configured (proving the mock, not the
code), try/catch swallowing assertion errors, and disabled/skipped tests that
are rotting since months.

The collector is a fast static scan; the LLM is what judges for each
candidate whether the test could ever fail and what it actually pins down.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/test-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each suspicious test:
   - Read the `body` (600 chars of test source).
   - Could this test ever fail? If yes, what behavior does it pin down?
   - Classify: `honest` / `cannot-fail` / `tests-the-mock` / `tautological`
     / `rotting-skip` / `try-around-assert`.
5. Confidence: `proven` (clearly cannot fail), `likely` (suspicious context),
   `suspected` (judgment call).
6. Propose a minimal fix per finding.
7. Write `test-honesty-report.md` to the working directory.

## Usage

```
/test-honesty                         # interactive, prompts for directory
/test-honesty <dir>                   # scan project test directories
/test-honesty -help                   # show usage
```

Returns JSON with `tests[]` per test case:
`{file, line, name, runner, assertionCount, disabled, tryAroundAssert,
tautologySuspicion, disabledSinceDays?, body}` plus summary counts.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/test-honesty-auditor ~/.claude/skills/
```

## Audience

Both - seniors use it after a green-build that surprised them; vibe-coders use
it to learn which tests give real signal.

## Report Format

`test-honesty-report.md` with:
- Executive summary (total tests scanned, % honest vs cannot-fail, oldest skip)
- Critical findings (proven cannot-fail - the green tick is theater)
- Medium findings (suspicious mock-assertion, swallowing assertion errors)
- Low findings (tautologies, very short tests with no clear intent)
- Skip age histogram (skip markers older than 30/90/365 days)
