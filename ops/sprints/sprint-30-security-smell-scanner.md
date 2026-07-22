# Sprint 30 — security-smell-scanner (/config-map → security/)

Regeln: `ops/BIBEL.md` gilt vollständig (Sprint 30+, englische Artefakte).
Dieser Skill ist physisch in `skills/security/`, Cross-Link in `skills/quality/README.md`.

## 1. Problem

Sicherheitslücken entstehen nicht durch einzelne Schwachstellen, sondern durch wiederkehrende Muster: unsanitisierte Inputs in SQL-Kontexten, `innerHTML`-Zuweisungen ohne Escaping, User-Input in Dateipfaden, `exec()`-Aufrufe mit String-Interpolation, hardcodierte Credentials oder deaktivierte Sicherheitsfeatures. Diese Muster sind für Menschen mühsam zu jagen — für einen statischen Analyzer mit Regex-Heuristiken und LLM-Kontext ein idealer Job.

Vorher: "wir haben einen DAST-Scanner, der Runtime-Schwachstellen findet" — aber strukturelle Anti-Patterns im Code (über Hunderte Dateien verteilt) bleiben unentdeckt, weil weder Linter noch DAST den semantischen Kontext verstehen. Nachher: vollständige Landkarte aller Security-Smell-Befunde mit Codestelle, Pattern-Typ und Konfidenz, priorisiert nach Severity.

## 2. Nutzen

- **Schnellcheck vor jedem PR**: Sicherheitssmells, die in Code-Reviews untergehen, werden automatisch erkannt.
- **Allgemeinverständlich**: ein Senior-Entwickler versteht den Befund sofort, ein Vibe-Coder bekommt eine klare Handlungsanweisung.
- **Falsch-Positiv-resistent**: Der LLM-Teil filtert Heuristik-Rauschen, indem er den semantischen Kontext prüft.

## 3. Scope / Nicht-Scope

**Scope:**
- 10 Pattern-Familien: SQL injection, XSS, command injection, path traversal, hardcoded credentials, insecure defaults, IDOR, open redirect, TOCTOU (time-of-check-time-of-use), missing input validation
- Regex-basierte Vorerkennung (Collector) + semantische Analyse (LLM)
- Report mit Evidenz (Datei:Zeile, Pattern-Klasse, Severity, Kontext-Snippet)

**Nicht-Scope:**
- KEIN Runtime-Scan (kein Netzwerk, keine laufende Applikation)
- KEINE Credentials ausgeben (Werte von Passwörtern/Tokens nie im Klartext)
- KEIN vollständiger SAST (nur die 10 Pattern-Familien, kein Datenfluss-Graph)
- KEINE automatische Reparatur (nur Detektion + Report)

## 4. Skill-Spezifikation

Ordner: `skills/security/security-smell-scanner/`

Frontmatter:

```yaml
---
name: security-smell-scanner
description: "Security smell scanner: statically detects 10 families of security anti-patterns across a codebase (SQL injection, XSS, command injection, path traversal, hardcoded credentials, insecure defaults, IDOR, open redirect, TOCTOU, missing input validation). Produces an evidence-backed report with severity, location, and contextual analysis. Read-only. Audience: Senior > Vibe. Cross-link from quality/ cluster. Trigger: /config-map"
trigger: /config-map
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stop.
2. Confirm: `-ProjectDir`.
3. Run `scripts/security-scan.ps1`.
4. LLM analysis per § 6.
5. Report `security-smell-report.md` into working directory; short-form: critical severities first.

Usage:

```
/config-map               # interactive
/config-map <dir>         # scan dir for security smells
/config-map --help
```

## 5. Collector Scripts

### scripts/security-scan.ps1

Parameters: `-ProjectDir` (mandatory), `-Extensions`/`-Exclude` (defaults mirroring Sprint 03).

Read-only. Scans all source files for 10 pattern families. Produces a JSON array of findings. No values from credentials — only `hasValue: true/false` and pattern type.

**Pattern families:**

| # | Pattern | Trigger strings | Severity | Notes |
|---|---|---|---|---|
| 1 | sql-injection | `SELECT * FROM`, `INSERT INTO`, `DELETE FROM`, `WHERE` + string concat (`+`, `$"`, `${}`, `format()`) | high | Look for SQL keywords with non-literal values |
| 2 | xss | `innerHTML =`, `outerHTML =`, `dangerouslySetInnerHTML=`, `v-html=`, `insertAdjacentHTML` | high | Direct DOM manipulation with variables |
| 3 | command-injection | `exec(`, `execSync(`, `spawn(`, `child_process`, `shell: true`, `eval(`, `system(`, `popen(`, `subprocess.` | high | Dynamic command construction |
| 4 | path-traversal | `open(`, `readFile`, `writeFile`, `unlink`, `rmdir`, `join(` + user variable | high | File operations with unsanitized input |
| 5 | hardcoded-creds | `password`, `passwd`, `api_key`, `apikey`, `secret`, `token`, `credential` in assignment | medium | Values from literals not env/config |
| 6 | insecure-defaults | `secure: false`, `ssl: false`, `tls: false`, `strict: false`, `verify: false` | high | Security features explicitly disabled |
| 7 | idor | `/:id`, `/{id}`, `req.params.id`, `request.args` without visible auth check | medium | Object-level access without authorization |
| 8 | open-redirect | `redirect(`, `res.redirect(`, `302`, `Location:`, `header(` + user variable | medium | User-controlled redirect targets |
| 9 | toctou | file existence check + subsequent file operation (`exists` → `open`, `stat` → `read`) | medium | Time-of-check-time-of-use races |
| 10 | missing-input-validation | `req.body`, `request.json`, `req.query`, `request.args`, `$_GET`, `$_POST` without prior validation pattern | medium | Trust boundary input not validated |

JSON output schema:

```json
{
  "findings": [
    {
      "id": 1,
      "pattern": "sql-injection",
      "severity": "high",
      "file": "src/users.ts",
      "line": 42,
      "evidence": "const query = `SELECT * FROM users WHERE id = ${userId}`",
      "context": "  const db = getDb();\n  const userId = req.body.id;\n  const query = `SELECT * FROM users WHERE id = ${userId}`;\n  return db.execute(query);",
      "hasSanitizer": false,
      "suggestedFix": "Use parameterized queries (e.g. db.execute('SELECT * FROM users WHERE id = ?', [req.body.id]))"
    }
  ],
  "counts": {
    "total": 5,
    "bySeverity": { "high": 2, "medium": 3 },
    "byPattern": { "sql-injection": 1, "xss": 1, "hardcoded-creds": 1, "open-redirect": 1, "missing-input-validation": 1 }
  },
  "summary": "Found 5 security smell(s): 2 high, 3 medium severity."
}
```

Error behavior: missing path → exit 1. No findings → empty array, exit 0 (report then notes "no smells detected").

## 6. LLM Analysis Steps

1. **Result ingestion**: parse `findings[]` from JSON. For each finding, present the `context` snippet to allow the LLM to validate the heuristics match.
2. **Context analysis** per finding:
   - Is the trigger a **true positive** (user data reaches a sensitive sink), **false positive** (sink protected by sanitizer/parametrization), or **uncertain**?
   - Assign confidence: `belegt` (evidence clearly shows vulnerability), `wahrscheinlich` (likely but e.g. sanitizer is external), `vermutet` (no clear data flow — mark as open question).
   - For `hardcoded-creds`: mask the value (show first 8 + last 4 chars, never full).
3. **Severity recalibration**: adjust based on:
   - Reachability (is the function exposed to external users?)
   - Existing mitigation (is there a sanitizer/waf/filter nearby?)
   - Data classification (does the flow touch PII or payment data?)
4. **Report structure**:
   - Executive summary: counts + risk level
   - Critical findings (high confidence + high severity) with full evidence
   - Medium findings (grouped by pattern)
   - Low / informational (possible improvements)
   - False positive log (matched by heuristics, dismissed by context)
   - Open questions (uncertain findings that need manual review)
5. Evidenz-Pflicht: jeder Befund trägt Konfidenz-Stufe + Datei:Zeile + Pattern.
   Credential values NEVER appear in the report — only `[REDACTED]` or masked preview.

## 7. Edge Cases

| Case | Behavior |
|---|---|
| SQL in ORM method calls (TypeORM, Prisma, Sequelize) | NOT flagged — these use parameterization by default; only raw SQL flagged |
| Template literals that look like SQL but aren't (e.g. "SELECT" as column value) | LLM context analysis filters these; Collector marks as `hasSanitizer: true` for literal-only matches |
| Hardcoded creds in comments or test files | Mark as `test: true` in finding, downgrade to medium unless real secrets |
| Authorization in middleware (separate file from route handler) | IDOR: mark as `uncertain`, let LLM resolve with `wahrscheinlich` if middleware pattern exists |
| Base64-encoded / obfuscated credentials | Collector flags encoding patterns (Base64, ROT, XOR) as `suspiciousEncoding` |
| Dynamic config keys (process.env[key]) | Same pattern as konfig-kartograf: report as `dynamicReads`, mark as uncertain |

## 8. Test Plan

Smoke: Fixture `security-smell-scanner/tests/fixture/` with:
- 1 SQL injection (template literal in query, `hasSanitizer: false`)
- 1 XSS (`innerHTML = userName`, `hasSanitizer: false`)
- 1 hardcoded cred (`password = "super_secret_1"` in source)
- 1 open redirect (`res.redirect(nextUrl)` where `nextUrl` from `req.query`)
- 1 false positive (SQL in ORM parameterized `prisma.user.findMany({ where: { id } })` → NOT flagged)

```powershell
& .\skills\security\security-smell-scanner\scripts\security-scan.ps1 -ProjectDir ".\skills\security\security-smell-scanner\tests\fixture"
```

Expected: exit 0, JSON valid, 4 findings (SQL, XSS, creds, redirect), 1 NOT flagged (ORM call). Credential value NOT in output. LLM step: critical SQL injection identified, XSS confirmed, creds masked, redirect medium.

Akzeptanz (dreamzzz-api): Complete run. Expected: plausible findings >0, no credential values in output (grep check).

Negativ: invalid path → exit != 0.

## 9. DoD Checklist

- [ ] SKILL.md complete (with credential silence clause)
- [ ] security-scan.ps1 (all 10 pattern families, context extraction, severity, `hasSanitizer` heuristic)
- [ ] Fixture created (4 true positives + 1 false positive)
- [ ] Smoke passed incl. credential-value grep check
- [ ] LLM analysis: all 4 true positives confirmed, ORM false positive dismissed, creds masked
- [ ] Acceptance run documented (≥2 findings in dreamzzz-api, zero credential leaks)
- [ ] Negative test passed
- [ ] Report satisfies BIBEL § 4 (evidence, confidence levels, "Open Questions" section)
- [ ] `ops/tracking.md` updated, commit `sprint-30: security-smell-scanner implementiert`
