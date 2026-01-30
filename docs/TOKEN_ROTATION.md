# Token rotation & PAT guidance

This document describes how to rotate/revoke Personal Access Tokens (PATs) used for local `gh` CLI auth and CI automation, plus recommended scopes.

1) Quick context

- You may have multiple tokens available (keyring, environment variable). Use `gh auth status` to see which is active and its scopes.

2) Recommended scopes for this repo

- `repo` (or `public_repo` for public repos)
- `read:org` (if you need organization-level GraphQL fields)
- `workflow` (for workflow dispatch or managing workflows)
- `gist` only if you use gist features

3) Rotate a user PAT (manual, recommended)

- Create a new PAT:

  1. Open: https://github.com/settings/tokens
  2. Click "Generate new token" (classic) or use the new fine-grained tokens as appropriate.
  3. Select the scopes above and generate the token.
  4. Copy the token (store it safely; you won't be able to view it again).

- Configure `gh` to use the new token locally (one option):

  ```powershell
  echo <NEW_TOKEN> | gh auth login --with-token
  # Or refine scopes with:
  gh auth refresh -h github.com -s repo,read:org,workflow
  ```

- Confirm with:

  ```powershell
  gh auth status
  ```

4) Revoke the old PAT

- Use the web UI:

  1. Visit https://github.com/settings/tokens
  2. Find the old token and Delete/Revoke it.

- Optionally, if the token is used as a secret in Actions or other systems, rotate those references first, then revoke the old token.

5) Update CI / automation

- If Actions or other automation used the old token, update the repository secret via the web UI or `gh secret`:

  ```powershell
  gh secret set MY_REPO_PAT --body "<NEW_TOKEN>" --repo owner/repo
  ```

6) Remove tokens from local environment

- Check for `GITHUB_TOKEN` or other token env vars in your shell profile, CI runner, or local tools and remove them if they are stale.

  ```powershell
  # remove for current shell session
  Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
  ```

7) Verification

- Run `gh auth status` and `gh pr edit <PR>` to confirm operations that previously failed now work.

8) Notes

- If you need help revoking a token via API, I can prepare `gh api` commands but you'll need the token owner session.
