# TLS-Config-Drift - /ssl-drift

Harvests every TLS-version constant, cipher-suite array, cert-pinning call, mTLS flag,
cert-validation callback, and FIPS-mode setting. LLM classifies each as acceptable,
misconfigured, or downgrade-prone.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/tls-config-drift ~/.claude/skills/
```

## Usage

```
/ssl-drift                              # interactive
/ssl-drift <dir>                        # scan project
```
