[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Action = 'help',

    [Parameter(Mandatory = $false)]
    [string]$Description = ''
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

switch ($Action) {
    'help' {
        Write-Output @"
BLITZPLAN - Lightweight Design Coach
────────────────────────────────────
Usage:
  /blitzplan <description>  - Start a design session
  /blitzplan quick          - Quick mode (3 questions)
  /blitzplan full           - Full mode (5 questions)

This skill is conversation-only. No files are written.
"@
    }
    'template' {
        Write-Output @"
DESIGN TEMPLATE
────────────────
Pages:
  <route> — <purpose>

Components:
  <name> — <responsibility>

Auth:
  <method>

Data:
  <sources + access model>

Out of Scope:
  <excluded features>

Constraints:
  <deployment, performance, etc.>
"@
    }
    default {
        Write-Output "BLITZPLAN: unknown action '$Action'. Use 'help'."
    }
}
