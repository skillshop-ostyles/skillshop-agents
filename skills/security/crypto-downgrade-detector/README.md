# Crypto-Downgrade-Detector - /crypto-downgrade

Harvests every weak-algorithm usage (MD5, SHA1, DES, 3DES, RC4, ECB, CBC, deprecated createCipher),
modern alternatives (subtle.encrypt, bcrypt, argon2, scrypt, PBKDF2), JWT signing-config,
cert/key-generation calls, and patch/version-based crypto weakeners. LLM classifies each
as downgradeable, deprecated, or acceptable and recommends minimum upgrade.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/crypto-downgrade-detector ~/.claude/skills/
```

## Usage

```
/crypto-downgrade                              # interactive
/crypto-downgrade <dir>                        # scan project
```
