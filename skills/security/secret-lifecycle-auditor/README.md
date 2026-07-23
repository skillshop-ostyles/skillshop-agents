# Secret-Lifecycle Auditor - /secret-lifecycle

Inventories every secret-shaped key across .env, k8s manifests, Vault configs,
IAM refs, terraform. Per secret: age from git log -S, masked value (first-8/last-4),
reachability against installed dependencies, type guess from key prefix. LLM
judges rotation cadence and emits a prioritized rotate-now / rotate-soon / remove-dead list.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/secret-lifecycle-auditor ~/.claude/skills/
```

## Usage

```
/secret-lifecycle                          # interactive
/secret-lifecycle <dir>                    # scan project
/secret-lifecycle <dir> -SecretFilePatterns ".env,*.tf"
```
