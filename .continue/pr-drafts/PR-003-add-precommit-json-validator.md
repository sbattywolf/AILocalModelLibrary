Title: Add pre-commit JSON validator and CI lint step
Branch: feat/precommit-json-validate

Summary
-------
Add a lightweight pre-commit hook and CI lint step that validates `.continue/*.json` files against `schemas/skills.schema.json` to prevent committing malformed example data.

Changes Proposed
----------------
- Add `.githooks/pre-commit` script that runs `pwsh -File scripts/validate-json.ps1 .continue`.
- Add `scripts/validate-json.ps1` that locates JSON files and validates them against the schema using `Newtonsoft.Json.Schema` or `pester`-style validations (PowerShell native approach).
- Add a CI job step (example for GitHub Actions) under `.github/workflows/validate-json.yml` that runs the validator.

How to apply locally
--------------------
```bash
git checkout -b feat/precommit-json-validate
# Add scripts/validate-json.ps1 and .githooks/pre-commit
git add scripts/validate-json.ps1 .githooks/pre-commit .github/workflows/validate-json.yml
git commit -m "feat: add pre-commit JSON validator for .continue files"
git push -u origin feat/precommit-json-validate
```

Notes
-----
I can implement `scripts/validate-json.ps1` for you; do you prefer a pure-PowerShell implementation (no extra packages) or to use `dotnet`/`Newtonsoft.Json.Schema` for stricter validation? If unsure, I'll implement a pure-PowerShell validation that uses `ConvertFrom-Json` and a small set of rule checks and make it extensible.
