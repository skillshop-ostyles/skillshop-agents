param([string]$TargetDir)

if (-not $TargetDir) { $TargetDir = Join-Path $PSScriptRoot "fixtures\smoke" }

# Clean if exists
if (Test-Path $TargetDir) { Remove-Item -LiteralPath $TargetDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$TargetDir\src" | Out-Null

# Commit 1: 2 routes + 1 DTO (3 fields, 1 optional)
@"
export interface CreateOrderDto {
  customerId: string;
  items: number[];
  total?: number;
}

export function calculateTotal(items: number[]): number {
  return items.reduce((s, i) => s + i, 0);
}
"@ | Set-Content -Path "$TargetDir\src\api.ts" -Encoding utf8

@"
import { Router } from 'express';
const router = Router();

router.post('/orders', (req, res) => {
  res.json({ id: '123' });
});

router.get('/orders/:id', (req, res) => {
  res.json({ id: req.params.id });
});
"@ | Set-Content -Path "$TargetDir\src\routes.ts" -Encoding utf8

# Init git and commit
$cwd = Get-Location
Set-Location $TargetDir
git init 2>&1 | Out-Null
git config user.email "test@test.com"
git config user.name "Test"
git add -A 2>&1 | Out-Null
git commit -m "initial: 2 routes + DTO with 3 fields" 2>&1 | Out-Null

# Commit 2: 1 route removed, 1 DTO field removed (items), 1 optional field added (couponCode), 1 field optional->required (total)
@"
export interface CreateOrderDto {
  customerId: string;
  total: number;
  couponCode?: string;
}
"@ | Set-Content -Path "$TargetDir\src\api.ts" -Encoding utf8

@"
import { Router } from 'express';
const router = Router();

router.post('/orders', (req, res) => {
  res.json({ id: '123' });
});
"@ | Set-Content -Path "$TargetDir\src\routes.ts" -Encoding utf8

git add -A 2>&1 | Out-Null
git commit -m "breaking: removed GET /orders/:id, removed field, added optional field" 2>&1 | Out-Null

Set-Location $cwd
Write-Output "Fixture created at: $TargetDir"
