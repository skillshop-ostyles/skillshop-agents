Push-Location $PSScriptRoot
if (Test-Path '.git') { Remove-Item -Recurse -Force '.git' }
git init 2>$null
git config user.name "Test Dev"
git config user.email "dev@test.com"
git add src/; git commit -m "initial api fixture" 2>$null
Pop-Location
Write-Output "Fixture git repo ready"