# crypto-downgrade-detector

**Trigger:** `/crypto-downgrade` | **Risk:** read-only | **Audience:** Senior

> Crypto downgrade detector: harvests every weak-algorithm usage (MD5, SHA1, DES, 3DES, RC4, ECB, CBC, deprecated creat...

Crypto downgrade detector: harvests every weak-algorithm usage (MD5, SHA1, DES, 3DES, RC4, ECB, CBC, deprecated createCipher), modern alternatives (subtle.encrypt, bcrypt, argon2, scrypt, PBKDF2), JWT signing-config (hardcoded-secret vs asymmetric key), cert/key-generation calls, and patch/version-based crypto weakeners (ALLOW_WEAK, --harmony, legacy-crypto). LLM analyses each finding as downgradeable, deprecated, or acceptable and recommends minimum upgrade.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/security/crypto-downgrade-detector $HOME/.claude/skills/security/crypto-downgrade-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/security/crypto-downgrade-detector $HOME\.claude\skills\security\crypto-downgrade-detector
```

## Usage

```
/crypto-downgrade                    # interactive - prompts for target
/crypto-downgrade <project-dir>      # scan specified project
/crypto-downgrade -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: downgrade-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


