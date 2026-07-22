--
name: api-contract-guardian
description: "Diffs the API surface of two git states, classifies each change as breaking/additive and writes the migration note. Trigger: /api-diff"
trigger: /api-contract-guardian
--

# /api-diff

Breaking changes happen on the side - until a consumer breaks that nobody knew about.

Full specification: [`ops/sprints/sprint-17-api-vertrags-waechter.md`](../../ops/sprints/sprint-17-api-vertrags-waechter.md)
