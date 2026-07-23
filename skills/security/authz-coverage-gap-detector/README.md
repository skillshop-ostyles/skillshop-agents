# AuthZ Coverage Gap Detector - /authz-coverage

Finds mutating endpoints that lack explicit authorization checks, relying solely on middleware inheritance. Highlights routes where middleware failure leaves gaps.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/authz-coverage-gap-detector ~/.claude/skills/
```

## Usage

```
/authz-coverage                            # interactive
/authz-coverage <dir>                      # scan project
```
