# Secrets and GitHub Actions - Setup Guide

This document explains recommended secrets and how to store them in GitHub for secure CI usage.

Required secrets (example names):
- `GEMINI_API_KEY` : API key for Google Gemini (store in GitHub Secrets)
- `BITWARDEN_APIKEY` : API key for Bitwarden service (if using Bitwarden in CI)
- `SERVER_SSH_KEY` : Private SSH key for deploy (store as `SSH` secret type or as plain secret)
- `CODECOV_TOKEN` : Optional token for Codecov uploads

Storing secrets in GitHub:
1. Go to your repository on GitHub.
2. Settings -> Secrets and variables -> Actions -> New repository secret.
3. Add the secret name and value and click Add secret.

Best practices:
- Never commit secrets to the repository. Use secrets for CI only.
- Use minimal-scoped credentials (API keys scoped to necessary permissions).
- Rotate keys periodically and record rotation procedures.
- Use Bitwarden or other secret manager for team-shared credentials; in CI prefer GitHub Secrets.

Rate limiting and cost control for Gemini:
- Cache AI responses for repeated CI failures to avoid duplicate calls.
- Throttle requests: in workflows add sleeps and exponential backoff when retrying.

Local development:
- Store dev keys in your local environment variables or a `.env` file excluded by `.gitignore`.

Local repo: placeholders & session preload
- Create a per-repo placeholder secrets file: run `.\scripts\init-secrets.ps1` to write `.continue/secrets.json` with `home_env`, `workspace_env`, `github` placeholders and recommended `winget` candidates.
- Load placeholders into every interactive PowerShell session: run `.\scripts\preload-session.ps1 -InstallProfile` to append a one-line dot-source into your PowerShell profile which will load `home_*` and `workspace_*` env vars and record a masked audit entry in `.continue/secrets-audit.log`.
- The preload intentionally does NOT export secret values like `GEMINI_API_KEY` by default. It logs which keys were referenced (not values) to `.continue/secrets-audit.log` so usage can be traced without leaking secrets.
- For other shells (bash/zsh) or CI, prefer loading secrets from secure stores (GitHub Secrets, Bitwarden) or source a localized `.env` that you keep out of repo.

Best practice for secret placeholders:
- Keep placeholders in `.continue/secrets.json` to make onboarding reproducible and document required secret names.
- When automating installs (winget) include a `winget.packages` list in the file so install scripts can suggest candidates.
- Regularly review `.continue/secrets-audit.log` to confirm which sessions referenced placeholders and when.

