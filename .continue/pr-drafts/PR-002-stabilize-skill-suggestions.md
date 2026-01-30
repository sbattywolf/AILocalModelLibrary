Title: Stabilize `skill-suggestions.json` writer and tests
Branch: fix/skill-suggestions-writer

Summary
-------
This PR draft aims to make the `skill-suggestions.json` producer deterministic and schema-compliant and to add coverage so `runs once and writes skill-suggestions.json` test cannot flake.

Problem
-------
- The Pester suite produced intermittent failures related to `skill-suggestions.json` generation; output shape or timing differences cause tests to fail under CI or different environments.

Changes Proposed
----------------
- Harden the writer to always emit the same top-level keys and consistent types (timestamp ISO8601, `topSkills` as array, `summary` as string).
- Add retries/timeouts in the test harness where the test reads the file (to avoid race conditions).
- Add a deterministic sample fixture for the test run to compare against.

How to apply locally
--------------------
```bash
git checkout -b fix/skill-suggestions-writer
# implement changes in scripts/monitor-skill-suggestions.ps1 (or the existing producer)
git add scripts/* tests/*fixtures*
git commit -m "Fix: stabilize skill-suggestions writer and add deterministic test fixture"
git push -u origin fix/skill-suggestions-writer
```

Notes
-----
I can implement the writer changes and tests automatically if you want — say the word and I'll apply a concrete patch and run Pester locally.
