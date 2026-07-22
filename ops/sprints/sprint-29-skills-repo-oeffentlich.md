# Sprint 29 — skills-repo-oeffentlich

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Ausgangspunkt:
Repo hat seit gestern einen privaten GitHub-Remote (`skillshop-ostyles/skill-shop-agents`,
reines Code-Backup). Jetzt: Repo-Struktur öffentlichkeitstauglich machen, damit es
später public geschaltet werden und Stars sammeln kann.

## 1. Ziel

Ein `skills/`-Ordner mit einem Unterordner je Skill, Platzhalter-Ordner für die 20
noch nicht gebauten Skills (Roadmap-Sichtbarkeit), GitHub-taugliche
Installationsanleitungen pro Skill, Root-README/LICENSE für Öffentlichkeit. Drei mit
dem User geklärte Entscheidungen: (1) alles öffentlich, MIT-Lizenz — löst die Spannung
zur SHOP-BIBEL-§-2.6-Monetarisierungs-Prämisse zugunsten von Open Source, hier nur
dokumentiert, nicht neu durchdacht; (2) die 20 offenen Skills bekommen NUR
Platzhalter-Ordner, keine Implementierung; (3) Installationsanleitungen leben in
separaten `README.md`-Dateien pro Skill, `SKILL.md` bleibt reine KI-Instruktion.

## 2. Umsetzung

1. **Struktur-Umzug** — `git mv elevate skills/elevate`, `git mv project-init
   skills/project-init` (Git-History erhalten, per `git log --follow` geprüft).
2. **Importer-Fix** (einzige Shop-Code-Änderung) — `shop/src/importer.js`,
   `scanSkillFolders()` scannt jetzt `rootDir/skills` statt `rootDir` direkt;
   `EXCLUDED_TOP_LEVEL`-Set entfällt (nicht mehr gebraucht). `installer.js` nutzt
   dieselbe Funktion, kein zweiter Fix-Ort. Test-Fixtures (`shop/test/fixture/root/`,
   `shop/test/fixture/advisor/root/`, plus drei inline in `importer.test.js`
   konstruierte Fixtures) auf die neue `skills/`-Konvention umgezogen.
3. **20 Platzhalter-Ordner** — generiert aus `shop/catalog/skills/*.json` (bereits seit
   Sprint 21 für alle 22 Skills kuratiert) + Sprint-Nummer-Zuordnung aus
   `ops/tracking.md`. Jeder Ordner: `SKILL.md` (gültiges Frontmatter, Body klar als
   "🚧 In Entwicklung" markiert, Link zur Sprint-Spec) + `README.md`
   (GitHub-Präsentation, kein Installationsblock, da nichts installierbar ist).
4. **README.md für elevate/project-init** — Terminal-Installation (bash + PowerShell),
   ehrlicher OS-Hinweis (Skripte sind PowerShell, macOS/Linux via `pwsh` bisher
   ungetestet), Hinweis auf die komfortablere Shop-Installation.
5. **Root-README.md** — Struktur-Diagramm aktualisiert, stale
   "kein Remote"-Aussage korrigiert, Status ehrlich benannt (2/22), Lizenz-Link.
6. **LICENSE** (neu, MIT, Repo-Root).
7. **Doku-Drift in lebenden Regel-Dokumenten behoben** (nicht ursprünglich geplant,
   aber beim Verifizieren gefunden): `ops/BIBEL.md` § 3 sagte noch "Jeder Skill ist ein
   eigener Ordner direkt unter `AGENTS\`" und referenzierte `elevate/SKILL.md` etc. an
   drei Stellen; `ops/manifest.md` referenzierte `elevate/`, `project-init/` und
   `<skill-name>/` ohne `skills/`-Präfix. Beides korrigiert — sonst hätte der Sprint
   selbst neue Doku-Drift erzeugt, genau das, was `doku-drift-detektor` (Sprint 12)
   später automatisiert aufspüren soll.

## 3. Entscheidungen während der Umsetzung

1. **`scanSkillFolders` bei fehlendem `skills/`-Ordner**: ursprünglich hätte ein
   fehlender `skills/`-Unterordner einen `ImportError` geworfen (1:1-Übersetzung der
   alten Logik). Beim Testlauf zeigte sich: `ops/tracking.md` nicht lesbar → alle
   in-entwicklung"-Test konstruiert einen `rootDir` ganz ohne `skills/`-Ordner (Skills
   kommen dort ausschließlich aus dem Katalog). Kein Verhaltensbug, aber die drei
   inline in `importer.test.js` konstruierten Test-Fixtures mussten ohnehin auf die
   neue Konvention (`root/skills/<name>/`) umgezogen werden — danach lief der Fehlerfall
   gar nicht mehr auf, weil `skills/` durchgängig vorhanden ist. Kein Code-Verhalten
   geändert, nur die drei Fixtures korrigiert.
2. **`installer.test.js` Zeile 94** referenzierte den alten Fixture-Pfad
   (`FIXTURE_ROOT/demo-skill-a`) direkt statt über die `FIXTURE_ROOT`-Konstante +
   Scan-Funktion — beim Testlauf gefunden (ENOENT), auf `FIXTURE_ROOT/skills/demo-skill-a`
   korrigiert.
3. **Platzhalter-Ordner sind für den Shop-Katalog nicht nötig** — die 20 offenen
   Skills waren schon vorher über `shop/catalog/skills/*.json` allein im Katalog
   sichtbar (Status aus `tracking.md`). Die neuen Ordner ändern am Shop-Verhalten
   nichts (verifiziert: `npm run import` liefert vor und nach dem Sprint identisch
   "22 Skills, 2 verfügbar, 20 in-entwicklung, 0 unkuratiert, keine Warnungen") — sie
   sind ausschließlich für GitHub-Besucher gedacht.

## 4. Verifikation

- `cd shop && npm run lint && npm test` → 92/92 grün (unverändert zur Zahl vor dem
  Sprint — reine Struktur-Verschiebung, keine neue/entfernte Test-Anzahl).
- `npm run import` gegen den echten AGENTS-Root → vor und nach dem Umzug identisch:
  22 Skills gesamt, 2 verfügbar, 20 in-entwicklung, 0 unkuratiert, 6 Bundles, keine
  Warnungen.
- Alle 20 Platzhalter-`SKILL.md`-Links gegen die tatsächlich existierenden
  `ops/sprints/sprint-NN-*.md`-Dateien geprüft (Skript-Check, 20/20 OK).
- `git status` sauber nach Commit.

## Nicht in diesem Sprint (bewusst)

- Implementierung der 20 offenen Skills — eigenes, großes Vorhaben.
- Bash-Portierung der PowerShell-Skripte.
- Auflösung der Monetarisierungs-Spannung (SHOP-BIBEL § 2.6) — nur vermerkt.
- GitHub-Pages-Hosting, CI-Workflows, Issue-Templates.
- **Repo auf public schalten** — bewusst separater, späterer Schritt mit eigener
  Freigabe im Chat, nicht automatisch Teil dieses Sprints.

## DoD

- [x] Struktur-Umzug mit erhaltener Git-History
- [x] Importer-Fix + Test-Fixtures konsistent, 92/92 grün
- [x] 20 Platzhalter-Ordner, alle Links verifiziert
- [x] README.md für beide fertigen Skills mit Terminal-Anleitung (bash + PowerShell)
- [x] Root-README.md, LICENSE
- [x] Doku-Drift in `ops/BIBEL.md`/`ops/manifest.md` behoben
- [x] `ops/tracking.md` aktualisiert
- [ ] Repo public schalten — bewusst nicht Teil dieses Sprints
