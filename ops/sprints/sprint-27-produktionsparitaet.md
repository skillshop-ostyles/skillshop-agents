# Sprint 27 — shop-produktionsparitaet

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Härtungs-Nachsprint
auf User-Wunsch: der lokale Dev-Server soll sich exakt so verhalten wie ein echter
Remote-Static-Host (Referenz: GitHub Pages). Da der Shop eine API hat (kein reines
statisches Hosting), heißt das konkret: Produktions-Auslieferungsverhalten, ohne den
fixen `localhost-only`-Constraint (SHOP-BIBEL § 2.4) anzutasten.

## 1. Ziel

Der Server liefert Assets/Antworten so aus, wie ein echter deployter Host es täte —
Kompression, Cache-Validierung, Security-Header, korrekte Fehlerseiten, keine
Dev-Artefakte (Fingerprint-Header, Stacktrace-Leaks) — bleibt aber ausschließlich
auf `127.0.0.1` erreichbar.

## 2. Änderungen

1. **Gzip-Kompression** (`compression`-Middleware, global) — reale Static-Hosts
   (Fastly/GitHub Pages, Nginx, CDNs) komprimieren immer. Neue Runtime-Dependency,
   dokumentiert in SHOP-BIBEL § 2.1 (Dependency-Insel bleibt `shop/`, kein Bruch
   des Prinzips, nur Erweiterung der erlaubten Liste).
2. **Cache-Control/ETag/Last-Modified** auf `express.static` (`maxAge: '10m'`,
   `etag`, `lastModified`) — Browser cachen 10 Minuten, danach 304-Revalidierung
   über ETag statt Volltransfer. Entspricht dem beobachteten GitHub-Pages-Verhalten
   (Fastly setzt dort `max-age=600`).
3. **Security-Header** (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
   `Referrer-Policy: no-referrer`) + `app.disable('x-powered-by')` — kein
   Express-Fingerprint, wie ihn auch ein echter Host nicht preisgäbe.
4. **Echte 404-Behandlung**: `public/404.html` (gleiches Layout, Header/Footer über
   `renderHeader()`), ausgeliefert mit Status 404 für unbekannte Pfade;
   `/api/*`-Routen ohne Treffer liefern stattdessen JSON `404 {"error": "..."}`
   statt Express' generischer Text-Fehlerseite.
5. **Zentraler Error-Handler** (4-Arg-Middleware am Ende der Kette): loggt serverseitig,
   antwortet immer mit generischem `500 {"error": "Interner Serverfehler"}` — keine
   Stacktraces nach außen, unabhängig von `NODE_ENV`.
6. **`NODE_ENV=production`-Default** in `main()` (nur beim echten Serverstart via
   `npm start`/`node src/server.js`, nicht in Tests, die `createApp()` direkt
   aufrufen) — deaktiviert Express' Verbose-Fehleransichten.

## 3. Entscheidungen und Funde während der Umsetzung

1. **`npm test` war bereits vor diesem Sprint kaputt** auf der installierten
   Node-Version (v24.12.0): `node --test test/` wirft `MODULE_NOT_FOUND`, weil
   diese Node-Version das Verzeichnisargument anders auflöst. Fund beim
   Verifizieren dieses Sprints, nicht durch den Sprint verursacht. Fix (chirurgisch,
   eine Zeile): `package.json`-Script auf `node --test` (Default-Discovery, findet
   `test/` per Konvention) geändert. Erneut geprüft: identische 88 Tests, 88 grün.
2. **Kompression per Hand vs. `compression`-Paket**: kurz erwogen, Gzip ohne neue
   Dependency selbst zu bauen (Node-`zlib` ist eingebaut). Verworfen — eine
   Buffering-Middleware für Streaming/Content-Length-Korrektheit selbst zu bauen
   ist genau die Art Overengineering-Risiko, die die Karpathy-Regeln vermeiden
   sollen; `compression` ist der Standard-Baustein genau für diesen Zweck, bleibt
   innerhalb der Dependency-Insel `shop/`. Deshalb: neue Dependency statt
   Marschall-Code, transparent in SHOP-BIBEL dokumentiert.
3. **`res.sendFile` für 404.html trägt keine `maxAge`** (anderer Code-Pfad als
   `express.static`) — bewusst so belassen: Fehlerseiten sollen nicht lange
   gecacht werden, das entspricht ebenfalls dem Verhalten echter Hosts.

## 4. Verifikation

- `npm run lint` → 0 Fehler.
- `npm test` (nach Script-Fix) → 88/88 grün, keine Regression.
- `curl -D -` gegen `/index.html`: `Content-Encoding: gzip`, `Cache-Control: public,
  max-age=600`, `ETag`, Security-Header vorhanden, kein `X-Powered-By`.
- `curl -D -` gegen unbekannten Pfad: `404`, HTML-Fehlerseite mit Security-Headern.
- `curl -D -` gegen unbekannte `/api/*`-Route: `404`, JSON `{"error": "..."}`.
- Browser (Claude-in-Chrome): Landing lädt fehlerfrei (Gzip transparent für den
  Browser), keine Konsolenfehler; `/nichts-hier` zeigt die gestaltete 404-Seite
  mit Header/Footer, kein Konsolenfehler.
- Server-Neustart via `node src/server.js` → läuft weiter auf `127.0.0.1:4711`
  (Bindung unverändert, kein externer Zugriff möglich).

## 5. Nicht in diesem Sprint (bewusst)

- Keine externe Erreichbarkeit (Tunnel/0.0.0.0-Bind) — widerspräche SHOP-BIBEL § 2.4,
  war nicht die vom User gewählte Option.
- Kein Asset-Hashing/Build-Schritt — SHOP-BIBEL § 2.1 verbietet Build-Schritte;
  GitHub Pages hasht i.d.R. auch nicht ohne Jekyll-Asset-Pipeline.
- HTTP/2 oder TLS lokal — für `127.0.0.1`-Dev-Zwecke kein Mehrwert, nicht verlangt.

## DoD

- [x] Alle Änderungen chirurgisch, auf das Ziel zurückführbar
- [x] Neue Dependency dokumentiert (SHOP-BIBEL § 2.1)
- [x] Tests grün (88/88), Lint sauber
- [x] Browser-Verifikation (Landing + 404) ohne Konsolenfehler
- [x] `ops/tracking.md` aktualisiert
