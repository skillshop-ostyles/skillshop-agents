# Third-Party-Trust - /third-party-trust

Inventories every outbound HTTP/RPC call (fetch, axios, got, requests, curl,
Invoke-RestMethod). For each: literal-vs-template URL, known-trusted vs
unknown domain, auth-header presence in call window, webhook handler
signature verification status.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/third-party-trust ~/.claude/skills/
```

## Usage

```
/third-party-trust                          # interactive
/third-party-trust <dir>                    # scan project
```
