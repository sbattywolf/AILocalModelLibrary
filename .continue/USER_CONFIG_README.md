This file explains how to set required environment variables and CI secrets for this repository.

Local checks
------------
- Inventory was written to `.continue/system_inventory.json`.
- If a tool is missing from `paths` in `.continue/user_config.json`, install it and ensure it's on `PATH`.

Common commands (PowerShell)
-----------------------------

# Temporarily set an environment variable for current session
$env:GITHUB_PAT = "<your-token-here>"

# Persist an environment variable for current user (requires new shell to take effect)
setx GITHUB_PAT "<your-token-here>"

# Use GitHub CLI to create/update a repository secret (replace owner/repo)
gh secret set GH_PAT --body "<your-token-here>" --repo owner/repo

# If using Bitwarden CLI, sign in interactively and export a session token
# (Do NOT commit session tokens to the repo)
# bw login --raw

CI notes
--------
- Do NOT commit secret values to the repository. Use your CI provider's secrets store.
- For GitHub Actions, add secrets in the repository settings or use `gh secret set` as shown above.

Recommended next steps
----------------------
1. Inspect `.continue/system_inventory.json` to confirm detected paths and drivers.
2. Install or add `python` to PATH if you need to run the test suite locally.
3. Set `GITHUB_PAT` (or `GITHUB_TOKEN`) as a local env var for CLI operations, and add the same as `GH_PAT` in GitHub Actions secrets.

Scripts
-------
- `scripts/enable-secret-mode.ps1`: Toggle `secret_mode` in `.continue/user_config.json` (enable/disable or flip when no flag provided).

If you want, I can:
- populate more fields in `.continue/user_config.json` from the inventory,
- create a CI workflow fragment that validates these secrets exist before running tests.
