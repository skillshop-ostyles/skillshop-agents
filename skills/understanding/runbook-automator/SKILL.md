---
name: runbook-automator
description: "Runbook automator: generates a deployment runbook from docker-compose.yml, package.json scripts, CI/CD config, healthcheck endpoints, Dockerfile, and README shell commands. Collector scans all five surfaces; LLM assembles a structured runbook with setup, dev workflow, deployment, healthcheck, crash recovery, CI/CD description, and troubleshooting. Read-only. Audience: Both. Trigger: /runbook"
trigger: /runbook
---

## What this is for

Deployment runbooks are always out of date. This skill regenerates one from the live source of truth: docker-compose.yml defines services/ports/volumes, package.json defines dev/build/test/lint workflow, CI config defines pipeline stages, Dockerfile defines the build, healthcheck endpoints define what liveness looks like, and README contains the tribal-knowledge shell commands.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/runbook-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. Generate a structured runbook with these sections:
   - **Setup steps:** prerequisites, docker-compose up, .env template, dependency installation
   - **Dev workflow:** how to run dev server, run tests, lint, typecheck, build
   - **Deployment procedure:** pipeline stages, build artifact, deploy commands, rollback
   - **Healthcheck procedure:** endpoint URLs, expected status codes, what each endpoint validates
   - **Crash recovery:** container restart policy, healthcheck failure action, log locations, dump locations
   - **CI/CD pipeline description:** trigger events, job dependency graph, what each job does
   - **Troubleshooting:** extracted README commands for common operations, port conflicts, volume issues
5. Write `runbook.md` to the working directory.

## Usage

```
/runbook                           # interactive
/runbook <dir>                     # scan project
/runbook -help                     # show usage
```

Returns JSON with `services[]`, `scripts[]`, `ci[]`, `docker{}`, `endpoints[]`, `healthcheckPaths[]`, `readmeCommands[]` plus summary counts.
