# Update CI / automation secrets

This document shows how to update repository secrets for CI (GitHub Actions) when you rotate a Personal Access Token (PAT) or other credentials.

1) Prepare the new token

- Generate a new PAT with the required scopes (see `docs/TOKEN_ROTATION.md`).

2) Set the new secret for the repository (recommended)

Replace `owner/repo` with your repository and `MY_REPO_PAT` with the secret name you prefer.

```powershell
# set a repository secret
gh secret set MY_REPO_PAT --body "<NEW_TOKEN>" --repo owner/repo

# verify it exists (lists names only)
gh secret list --repo owner/repo
```

3) Set an organization secret (optional)

If you need the secret available to multiple repositories and you have permissions:

```powershell
# create/update an organization secret and grant it to select repositories
gh secret set MY_ORG_PAT --body "<NEW_TOKEN>" --org my-org

# for fine-grained handling you may need to configure repository access in the web UI
```

4) Update workflows that reference the secret

- Ensure GitHub Actions workflows reference the new secret name (if you changed it) via `secrets.MY_REPO_PAT`.

5) Rotate with minimal downtime

- Best practice:
  1. Add the new secret with a new name (e.g., `MY_REPO_PAT_V2`).
  2. Update workflows and CI references to the new secret.
  3. Verify CI runs succeed.
  4. Remove old secret `MY_REPO_PAT`.

6) Remove old secrets

```powershell
# remove a repository secret
gh secret delete MY_REPO_PAT --repo owner/repo
```

7) Notes

- `gh secret set` accepts input from stdin as well: `echo <NEW_TOKEN> | gh secret set MY_REPO_PAT --repo owner/repo --body -`
- If your CI uses other systems (CircleCI, Jenkins), follow those platforms' secret rotation procedures.
