--
name: onboarding-pathfinder
description: "Analyzes the topology of a codebase and generates a didactically sequenced reading tour with comprehension questions and first safe tasks. Trigger: /onboarding-pathfinder"
trigger: /onboarding-pathfinder
--

# /onboarding-pathfinder

New devs deserve a guided tour, not a README and 'just ask'.

Scans a codebase to produce:
- **Topology**: files grouped by category (config, entry, model, service, controller, test, etc.)
- **Reading tour**: files ordered in a didactic sequence with rationale per step
- **Comprehension questions**: auto-generated questions per file based on its role
- **First safe tasks**: ranked list of isolated, low-risk files suitable for newcomers

## Usage

```powershell
scripts/onboard-scan.ps1 -ProjectDir <path>
```

Returns JSON with `topology`, `readingTour`, `comprehension`, and `firstSafeTasks`.
