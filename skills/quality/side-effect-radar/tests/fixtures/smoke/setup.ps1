Push-Location $PSScriptRoot
if (Test-Path '.git') { Remove-Item -Recurse -Force '.git' }
git init 2>$null
git config user.name "Test Dev"
git config user.email "dev@test.com"
Set-Content -Path "src\math.ts" -Value "export function add(a: number, b: number): number {
  return a + b;
}"
Set-Content -Path "src\calc.ts" -Value "import { add } from './math';
export function total(items: number[]): number {
  return items.reduce((s, n) => add(s, n), 0);
}"
git add src/math.ts src/calc.ts; git commit -m "initial math + calc" 2>$null
Start-Sleep -Milliseconds 200
Set-Content -Path "src\math.ts" -Value "export function add(a: number, b: number): number {
  if (typeof a !== 'number') throw new Error('invalid');
  return a + b;
}
export function multiply(a: number, b: number): number {
  return a * b;
}"
Set-Content -Path "src\calc.ts" -Value "import { add, multiply } from './math';
export function total(items: number[]): number {
  return items.reduce((s, n) => add(s, n), 0);
}
export function discounted(items: number[], discount: number): number {
  return multiply(total(items), 1 - discount);
}"
git add src/math.ts src/calc.ts; git commit -m "add multiply + discounted" 2>$null
Start-Sleep -Milliseconds 200
Set-Content -Path "README.md" -Value "# Calc Project"
git add README.md; git commit -m "add readme" 2>$null
Pop-Location
Write-Output "Fixture git repo ready: 3 commits"