# SSRF Detector — /ssrf-detector

Inventories every outbound HTTP call (fetch, axios, got, http, requests,
HttpClient, Invoke-RestMethod), traces whether the URL is user-controlled
(`req.body` / `req.query` / `req.params`), and grades URL-pre-fetch
validation (scheme check, hostname allowlist, metadata-IP blocking).

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/ssrf-detector ~/.claude/skills/
```

## Usage

```
/ssrf-detector                          # interactive
/ssrf-detector <dir>                    # scan project
```
