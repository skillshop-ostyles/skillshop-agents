# setup.ps1 - prepares a git fixture for clone-drift-tracker.
# Run from the smoke/ directory you want to populate:
#   powershell -File setup.ps1
# Result: a small git repo with two commits - the first identical validator
#         in two files, the second fixing a bug in only one of them.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# Remove any existing .git
if (Test-Path -LiteralPath (Join-Path $here '.git')) {
    Remove-Item -Recurse -Force (Join-Path $here '.git')
}

git -C $here init --quiet 2>&1 | Out-Null
git -C $here config user.email 'alice@test.com' 2>&1 | Out-Null
git -C $here config user.name 'alice' 2>&1 | Out-Null

# Write commit 1: identical validator in two files.
@'
export function isValidUsername(name: string): boolean {
    const trimmed = name.trim();
    return trimmed.length >= 3;
}
'@ | Set-Content -LiteralPath (Join-Path $here 'userValidator.ts') -NoNewline -Encoding UTF8

@'
export function isValidUsername(name: string): boolean {
    const trimmed = name.trim();
    return trimmed.length >= 3;
}
'@ | Set-Content -LiteralPath (Join-Path $here 'profileValidator.ts') -NoNewline -Encoding UTF8

git -C $here add . 2>&1 | Out-Null
git -C $here commit -m 'Add username validators identical across files' --quiet 2>&1 | Out-Null

# Write commit 2: bugfix in only one of them (empty string check).
@'
export function isValidUsername(name: string): boolean {
    const trimmed = name.trim();
    if (trimmed === '') return false;
    return trimmed.length >= 3;
}
'@ | Set-Content -LiteralPath (Join-Path $here 'userValidator.ts') -NoNewline -Encoding UTF8

git -C $here add userValidator.ts 2>&1 | Out-Null
git -C $here commit -m 'Guard empty string before length check (userValidator only)' --quiet 2>&1 | Out-Null

Write-Output "Clone-drift fixture created. Two commits:"
git -C $here log --oneline 2>&1 | ForEach-Object { Write-Output "  $_" }
