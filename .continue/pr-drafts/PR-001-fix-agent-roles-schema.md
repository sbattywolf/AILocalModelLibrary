Title: Fix .continue/agent-roles.json schema violations and strengthen schema
Branch: fix/schema-agent-roles

Summary
-------
This draft PR proposes fixes to the sample data and schema so the schema validation Pester tests pass reliably.

Problem
-------
- Schema validation tests reported failures for `.continue/agent-roles.json` and "validates all .continue JSON files against schema-derived rules". The repository contains examples and schema constraints that are out-of-sync or lax in places (nullable arrays, category formatting, sample enum mismatches).

Changes Proposed
----------------
- Update `schemas/skills.schema.json` to: explicitly require `skills` when present, allow string arrays for `skills`, and normalize `category` enum/format rules.
- Patch sample `.continue/agent-roles.json` to conform to the corrected schema (ensure arrays are arrays, fields use expected enum values, remove stray non-string keys).
- Add a small unit Pester test under `tests/Schema.Validation.Fix.Tests.ps1` that reproduces the failure-case and asserts the file now validates.

How to apply locally
--------------------
Run these commands to create the branch, apply the changes, run tests, and push (adjust remote name as needed):

```bash
git checkout -b fix/schema-agent-roles
# edit schemas/skills.schema.json and .continue/agent-roles.json per patch files in this PR draft
git add schemas/skills.schema.json .continue/agent-roles.json tests/Schema.Validation.Fix.Tests.ps1
git commit -m "Fix/schema: normalize agent-roles sample and strengthen schema"
git push -u origin fix/schema-agent-roles
```

Notes
-----
I can open a precise patch against `schemas/skills.schema.json` and `.continue/agent-roles.json` if you want me to implement the schema changes automatically.
