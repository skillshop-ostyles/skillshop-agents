# Manifest — AGENTS Skill-Programm

## Ziel

10 neue KI-Skills bauen, die klassische Entwickler-Schmerzen lösen, welche erst durch
LLMs automatisierbar wurden. Jeder Skill folgt dem bestehenden Muster
(`SKILL.md` + `scripts/*.ps1`, siehe `elevate/`, `project-init/`) und wird in genau
einem Sprint umgesetzt.

## Scope

| # | Skill | Trigger | Kern |
|---|---|---|---|
| 1 | intent-archaeologie | /intent | Warum existiert dieser Code? Absichten aus Git-Historie rekonstruieren |
| 2 | spec-luegendetektor | /spec-check | Widersprüche, Lücken, Ambiguitäten in Specs/Tickets finden |
| 3 | seiteneffekt-radar | /blast | Blast-Radius eines geplanten Changes vorhersagen |
| 4 | konsistenz-enforcer | /consist | Semantisch gleiche Geschäftsregeln finden, Divergenzen melden |
| 5 | totpfad-bestatter | /bury | Nachweislich toten Code mit Evidenz identifizieren |
| 6 | deps-erbschaft | /deps-audit | Jede Dependency: Zweck, Risiko, Austauschbarkeit, Exit-Plan |
| 7 | wissens-testament | /testament | Kopf-Wissen eines Entwicklers per Interview + Mining konservieren |
| 8 | repro-automat | /repro | Aus vagem Bug-Report ein minimales lauffähiges Repro bauen |
| 9 | prod-spiegel | /mirror | Code-Erwartung vs. Log-Realität abgleichen |
| 10 | migrations-chirurg | /migrate | Schema-Diff → Migration + Rollback + Validierung |

## Constraints (fix)

- Repo lokal-only: kein Remote, kein Push — niemals.
- `~/.claude/` wird von nichts in diesem Repo verändert (Schutzregel, siehe BIBEL § 2).
- Ausführendes Modell der Sprints: Sonnet. Regeln: `ops/BIBEL.md`.
- Skills sind gegenüber analysierten Fremdprojekten read-only (Ausnahmen nur mit
  expliziter User-Freigabe, geregelt in den Sprint-Files 05 und 10).

## Struktur

- `ops/BIBEL.md` — Master-Regeln, Skill-Anatomie, Sprint-/Test-Protokoll, DoD
- `ops/tracking.md` — Sprint-Status + Blocker
- `ops/sprints/sprint-NN-<skill>.md` — je Sprint die vollständige Spezifikation
- `<skill-name>/` — die fertigen Skills (entstehen sprintweise)
