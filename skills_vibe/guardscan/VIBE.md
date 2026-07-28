# /guardscan — Schütze deine App

## Was ist das?

Guardscan findet die 7 häufigsten Sicherheitslücken in AI-generierten Next.js/React-Apps. Jeder Fund zeigt dir einen echten Sicherheitsvorfall und genau was du tun musst.

## Wie benutze ich es?

- `/guardscan` — ich zeig dir die HIGH Impact Funde zuerst (RLS + Secrets + Client Auth)
- `/guardscan high` — nur HIGH Impact
- `/guardscan quick` — alle 7 Checks

## Was wird geprüft?

**🔴 HIGH Impact (sofort fixen):**
1. **RLS Check** — Supabase-Tabellen ohne Row Level Security → jeder User sieht alle Daten
2. **Secrets Leak** — API-Keys, Tokens, Passwörter im Source → 14% aller AI-Projekte betroffen
3. **Client Auth** — Auth-Prüfung nur im Browser → kann im Client umgangen werden

**🟠 MEDIUM Impact (vor Produktion fixen):**
4. **CSRF** — Formulare ohne Schutz → Angreifer können Aktionen im Namen des Users ausführen
5. **Auth Middleware** — API-Routen ohne Auth → jeder endpoint ist offen
6. **Security Headers** — Fehlende CSP/HSTS → XSS, Clickjacking, MITM

**🟡 LOW Impact (nice to have):**
7. **Env Validation** — `process.env.X` ohne Fallback → stille Produktions-Fehler

## Was passiert mit meinem Code?

- **Ohne Fix:** nichts — ich lese nur
- **Mit Fix:** ich zeig dir jede Änderung vorher + verweise auf reale Incidents

## Warum sollte ich das nutzen?

Weil 87% aller AI-generierten Projekte Sicherheitslücken haben. Guardscan fängt die 7 häufigsten, bevor deine App in Produktion geht.
