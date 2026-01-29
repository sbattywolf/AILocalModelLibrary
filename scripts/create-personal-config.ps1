<#
Creates a personal config from the repository template and places it in
`.private/config.json` (or optionally in %APPDATA% for persistence).

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-personal-config.ps1

This script will not commit anything. It sets restrictive ACLs on the created
file to limit access to the current user.
#>
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$template = Join-Path $repoRoot 'config.template.json'
$privateDir = Join-Path $repoRoot '.private'
$destFile = Join-Path $privateDir 'config.json'

if (-not (Test-Path $template)) { Write-Error "Template not found at $template"; exit 2 }
if (-not (Test-Path $privateDir)) { New-Item -ItemType Directory -Path $privateDir | Out-Null; Write-Host "Created $privateDir" }

# Copy template to destination if it doesn't exist
if (Test-Path $destFile) {
  Write-Host "Personal config already exists at $destFile — not overwriting."
  exit 0
}

Copy-Item -Path $template -Destination $destFile
Write-Host "Copied template to $destFile"

# Set ACL to current user only
try {
  $acct = [System.Security.Principal.NTAccount]::new($env:USERNAME)
  $acl = Get-Acl $destFile
  $acl.SetAccessRuleProtection($true,$false)
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($acct,'FullControl','Allow')
  $acl.SetAccessRule($rule)
  Set-Acl -Path $destFile -AclObject $acl
  Write-Host 'Set file ACL to current user only.'
} catch {
  Write-Host "Failed to set ACL: $_"
}

Write-Host 'Personal config ready in .private/config.json. Do not commit this file.'
exit 0
