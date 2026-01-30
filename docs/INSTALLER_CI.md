# Installer CI Usage

This document shows how to run `install-ollama-aider.ps1` non-interactively in CI and automation.

Key points
- Use the `-PersistScriptsToPath` switch to make the install add the user `Scripts` folder to the persistent User PATH without interactive prompts.
- Always use `-WhatIf` when validating intent locally before running for real.
 - To allow automatic bootstrap of a compatible Python, run the installer with `-AutoInstallMiniforge`.
   This will download and run the Miniforge installer in user-mode and re-probe for a usable Python. The installer honors `-WhatIf`.
 - The installer attempts to verify the Miniforge binary using an available SHA256 checksum file (common suffixes like `.sha256`, `.sha256.txt`, or `SHA256SUMS`). If a checksum is found it will be validated; a mismatch aborts the install. If no checksum is available the installer will abort to avoid running unsigned binaries.

GitHub Actions example (runs as a non-elevated step on Windows runners):

```yaml
- name: Install Aider (non-interactive)
  shell: pwsh
  run: |
    # validate what would happen
    .\scripts\install-ollama-aider.ps1 -PersistScriptsToPath -WhatIf
    # run non-interactively (will persist user PATH)
    .\scripts\install-ollama-aider.ps1 -PersistScriptsToPath
```

Notes
- On GitHub-hosted Windows runners the User PATH persistence is ephemeral for that runner instance; this flag is most useful for self-hosted runners or when running setup on developer machines.
- Use `-WhatIf` first to confirm the action will not change persistent state unexpectedly.
- If the installer needs to fallback to Miniforge/Conda to obtain a compatible Python distribution, consider running a separate Miniforge installer step (planned enhancement).
