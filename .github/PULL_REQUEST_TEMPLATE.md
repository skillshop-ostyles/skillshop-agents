# Pull Request Template

## Summary

Closes #(issue)

## Type of Change

- [ ] New skill
- [ ] Skill enhancement
- [ ] Bug fix
- [ ] Documentation only
- [ ] CI / infrastructure

## Testing

- [ ] `skills/_meta/elevate/scripts/ci-local.ps1` passes
- [ ] Smoke test runs against fixture (if new skill)
- [ ] JSON output is valid and matches contract
- [ ] Console summary uses `=== TITLE ===` format

## Checklist

- [ ] No em-dashes (`--`) in any file
- [ ] All user-facing text is English
- [ ] No secrets, tokens, or absolute paths
- [ ] Comment-based help in `.ps1` (`<# .SYNOPSIS #>`)
- [ ] README.md mirrors SKILL.md trigger + description
- [ ] Cluster README.md table updated (if new skill)