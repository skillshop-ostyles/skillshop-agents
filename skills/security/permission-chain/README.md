# Permission-Chain - /permission-chain

Extracts role definitions, role check sites, middleware mounts, and mutating routes.
Surfaces transitive chains, divergent-role-naming, and unprotected mutating routes
where the only protection is middleware inheritance.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/permission-chain ~/.claude/skills/
```

## Usage

```
/permission-chain                           # interactive
/permission-chain <dir>                     # scan project
```
