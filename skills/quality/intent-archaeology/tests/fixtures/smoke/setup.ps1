Push-Location $PSScriptRoot
if (Test-Path '.git') { Remove-Item -Recurse -Force '.git' }
git init 2>$null
git config user.name "Test Dev"
git config user.email "dev@test.com"
Set-Content -Path "main.ts" -Value "export function add(a: number, b: number): number {
  return a + b;
}"
git add main.ts; git commit -m "feat: add add function" 2>$null
Start-Sleep -Milliseconds 200
Set-Content -Path "main.ts" -Value "export function add(a: number, b: number): number {
  return a + b;
}

export function multiply(a: number, b: number): number {
  return a * b;
}"
git add main.ts; git commit -m "feat: add multiply function

Fixes #42" 2>$null
Start-Sleep -Milliseconds 200
Set-Content -Path "main.ts" -Value "export function add(a: number, b: number): number {
  if (a < 0 || b < 0) throw new Error('negative');
  return a + b;
}

export function multiply(a: number, b: number): number {
  return a * b;
}

export function subtract(a: number, b: number): number {
  return a - b;
}"
git add main.ts; git commit -m "fix: add input validation for add

PROJ-123: prevent negative numbers" 2>$null
Pop-Location
Write-Output "Fixture git repo ready: 3 commits"