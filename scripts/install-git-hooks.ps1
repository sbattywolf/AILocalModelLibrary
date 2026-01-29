# Set git to use the repository-local .githooks directory for hooks
try {
  git config core.hooksPath .githooks
  Write-Host 'Configured git core.hooksPath to .githooks'
} catch {
  Write-Host "Failed to set core.hooksPath: $_"
  exit 1
}
