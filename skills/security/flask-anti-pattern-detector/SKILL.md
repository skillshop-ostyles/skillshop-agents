---
name: flask-anti-pattern-detector
description: "Flask anti-pattern detector: scans Flask projects for hardcoded SECRET_KEY, debug-mode in production, dangerous template rendering (render_template_string), pickle/eval/exec on request data, unsafe session config, SQL injection via raw queries, insecure file upload, and debug toolbar enabled. LLM validates each finding and proposes modern alternatives. Read-only. Audience: Senior. Trigger: /flask-detector"
trigger: /flask-detector
---

## What this is for

Flask's flexibility makes it easy to introduce security anti-patterns:
hardcoded secrets, debug mode in production, unsafe template rendering
that enables SSTI, pickle deserialization of request data, eval/exec on
user input, session manipulation without strict lifetime controls, raw
SQL queries with string interpolation, unvalidated file uploads, and
debug toolbars left enabled. `security-smell-scanner` flags generic
vulnerabilities; this skill inventories every instance per pattern and
classifies severity.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/flask-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - **Is this safe?** Evaluate the context: is the hardcoded key in a
     dev config only? Is `render_template_string` called with a static
     template and user data passed as context (safe) or with user input
     concatenated into the template string (SSTI)?
   - **What is the modern alternative?** Propose the specific fix:
     `os.environ.get('SECRET_KEY')` instead of a literal;
     `render_template` instead of `render_template_string` with user
     input; `flask-talisman` CSP headers; proper session config with
     `PERMANENT_SESSION_LIFETIME`; prepared statements / ORM instead
     of raw SQL; `werkzeug.utils.secure_filename` for uploads.
   - **Severity scale:** eval/exec > pickle > SSTI > hardcoded secret >
     debug-mode > sql-injection > session > unsafe-upload > debug-toolbar.
5. Write `flask-detector-report.md` to the working directory.

## Usage

```
/flask-detector                            # interactive
/flask-detector <dir>                      # scan project
/flask-detector -help                      # show usage
```

Returns JSON with `findings[]`:
`{file, line, patternType, code, severity}` plus summary counts and
`projectIsFlask` boolean.
