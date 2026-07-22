---
name: vokabular-waechter
description: "Ubiquitous language guard: harvests identifiers from code, schema and API definitions, has the LLM cluster synonyms that name the same domain concept (customer/client/account/kunde), reports naming divergences with all locations and proposes one canonical term per concept including rename impact estimate. Never renames anything. Read-only. Trigger: /vocab"
trigger: /vocab
---

# /vocab

Customer, Client, Account, Kunde — vier Namen, ein Konzept, ein ständiges
Missverständnis. Erntet Bezeichner aus Code, Schema und API-Definitionen,
clustert Synonyme zu Domänen-Konzepten und schlägt je Cluster einen
kanonischen Namen vor.

## What this is for

- Dasselbe fachliche Ding heißt im System `customer`, `client`, `account`,
  in der DB `kunde` — Sprach-Drift erzeugt Bugs, macht Suchen unmöglich,
  vergiftet jedes Onboarding.
- **Reiner Lese-Skill. Keine automatische Umbenennung** — nur Vorschlag +
  grobe Impact-Schätzung. Abgrenzung zu `/co-change` (Sprint 04
  konsistenz-enforcer): dort geht es um duplizierte LOGIK, hier um divergente
  SPRACHE für dasselbe Konzept.

## What You Must Do When Invoked

Wenn `/vocab --help` oder `/vocab -h` (ohne weitere Argumente) aufgerufen
wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir` und optional einen Domänen-Hinweis vom User (Freitext:
worum geht es fachlich — hilft der Clusterung). Bestätigen.

### Step 2 — Ernte

```powershell
& "<SKILL_DIR>/scripts/term-harvest.ps1" -ProjectDir "<pfad>"
```

### Step 3 — Konzept-Clusterung

Terme zu Domänen-Konzepten gruppieren: Synonyme (customer/client/account),
Übersetzungspaare (kunde/customer), Abkürzungen (cust/usr/acct als Kandidaten
der Vollform clustern). Schreibvarianten (`order_item`/`orderItem`) zählen
NICHT als Divergenz — gleiche Wortwahl, nur Konvention. Domänen-Hinweis des
Users einbeziehen. Framework-/Technik-Terme (parser, handler, config,
React-Props, Django-Felder) als "technisches Vokabular" aussondern.

### Step 4 — Divergenz-Prüfung pro Cluster

Sind es WIRKLICH dasselbe Konzept? Beispiel-Fundstellen lesen (Read bei
Unsicherheit). Ehrlich unterscheiden:

- **synonym-divergenz**: gleiche Sache, verschiedene Namen — der Hauptbefund.
- **homonym-warnung**: gleicher Name, verschiedene Dinge — noch gefährlicher!
- **legitim-verschieden**: z. B. `client` = API-Client, `customer` = Käufer
  → kein Befund, aber im Glossar dokumentieren.

### Step 5 — Kanon-Vorschlag

Je Divergenz-Cluster: dominanten/präzisesten Term wählen (Frequenz +
Schema-Verankerung als Kriterien, Begründung nennen), Impact grob schätzen
(Anzahl Fundstellen der Nicht-Kanon-Terme; klein < 20 / mittel / groß > 100).

### Step 6 — Report schreiben

Datei `vocab-report.md` im aktuellen Arbeitsverzeichnis:

1. **Kurzfassung** — X Konzepte, Y mit Divergenz, Z Homonym-Warnungen.
2. **Glossar-Tabelle** — Konzept, kanonischer Vorschlag, alle Namen mit
   Frequenz.
3. **Divergenzen im Detail** — Fundstellen-Beispiele, Kanon-Begründung, Impact.
4. **Homonym-Warnungen**.
5. **Technisches Vokabular** (nur Liste).
6. **Offene Fragen** (alle `vermutet`-Clusterungen).

Evidenz-Pflicht: jede Cluster-Zuordnung mit ≥ 2 Beispiel-Fundstellen;
Homonym-Warnungen mit beiden Bedeutungs-Belegen.

### Step 7 — Zusammenfassen

Pfad des Reports nennen, Konzepte mit den meisten Synonymen zuerst.

## Usage

```
/vocab                     # interaktiv
/vocab <dir>               # Vokabular-Analyse
/vocab <dir> "<domäne>"    # mit Domänen-Hinweis
/vocab --help
```
