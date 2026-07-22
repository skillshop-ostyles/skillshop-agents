Push-Location $PSScriptRoot
if (Test-Path '.git') { Remove-Item -Recurse -Force '.git' }
git init 2>$null
git config user.name "Alice Author"
git config user.email "alice@test.com"
Set-Content -Path "src\core.ts" -Value "export function compute(value: number): number {
  return value * 2;
}"
New-Item -ItemType Directory -Force -Path "src" | Out-Null
Move-Item -Path "src\core.ts" -Destination "src\core.ts" -Force
git add src/core.ts; git commit -m "feat: add compute" 2>$null
Start-Sleep -Milliseconds 200
Set-Content -Path "src\core.ts" -Value "export function compute(value: number): number {
  return value * 2;
}

export function validate(input: string): boolean {
  return input.length > 0;
}"
git add src/core.ts; git commit -m "feat: add validate" 2>$null
Start-Sleep -Milliseconds 200
git config user.name "Bob Committer"
git config user.email "bob@test.com"
Set-Content -Path "src\utils.ts" -Value "export function format(s: string): string {
  return s.trim().toLowerCase();
}"
git add src/utils.ts; git commit -m "feat: add format utility" 2>$null
Start-Sleep -Milliseconds 200
git config user.name "Alice Author"
git config user.email "alice@test.com"
Set-Content -Path "src\utils.ts" -Value "export function format(s: string): string {
  return s.trim().toLowerCase();
}

export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}"
git add src/utils.ts; git commit -m "feat: add capitalize" 2>$null
Pop-Location
Write-Output "Fixture git repo ready: 4 commits, 2 authors"