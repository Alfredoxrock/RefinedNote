<#
add-pfx-secrets.ps1

Encodes a PFX file to base64 and sets two GitHub repository secrets using the GitHub CLI (gh).

Usage:
  .\scripts\add-pfx-secrets.ps1 -PfxPath 'C:\keystore\notesapp.pfx' -PfxPassword 'password'
  .\scripts\add-pfx-secrets.ps1 -PfxPath 'C:\keystore\notesapp.pfx' -PfxPassword 'password' -Repo 'owner/repo'

Requirements:
- GitHub CLI (gh) must be installed and authenticated (run `gh auth login` beforehand).
- You must have admin/write permission on the target repository to create secrets.

This script does NOT transmit the PFX outside your environment except to GitHub via gh.
It writes no temporary files containing the base64 payload (it uses in-memory strings).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PfxPath,
    [Parameter(Mandatory=$true)]
    [string]$PfxPassword,
    [string]$Repo
)

function Get-RepoFromOrigin {
    $url = git config --get remote.origin.url 2>$null
    if (-not $url) { return $null }
    # SSH format: git@github.com:owner/repo.git
    if ($url -match 'git@github.com:(.+)/(.+)(\.git)?$') {
        return "$($matches[1])/$($matches[2])"
    }
    # HTTPS format: https://github.com/owner/repo.git
    if ($url -match 'https://github.com/(.+)/(.+)(\.git)?$') {
        return "$($matches[1])/$($matches[2])"
    }
    return $null
}

if (-not (Test-Path $PfxPath)) {
    Write-Error "PFX file not found: $PfxPath"
    exit 2
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Error "GitHub CLI 'gh' not found. Install and authenticate with 'gh auth login' before running this script."
    exit 3
}

if (-not $Repo) {
    $Repo = Get-RepoFromOrigin
    if (-not $Repo) {
        Write-Error "Could not infer repository from git remote. Provide -Repo 'owner/repo' explicitly."
        exit 4
    }
}

Write-Host "Using repository: $Repo"

Write-Host "Reading PFX and encoding to base64 (in-memory)..."
$bytes = [System.IO.File]::ReadAllBytes($PfxPath)
$base64 = [System.Convert]::ToBase64String($bytes)

Write-Host "Setting repository secret PFX_BASE64 (this will store base64-encoded PFX in GitHub Secrets)."
gh secret set PFX_BASE64 --repo $Repo --body $base64
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to set PFX_BASE64"; exit $LASTEXITCODE }

Write-Host "Setting repository secret PFX_PASSWORD"
gh secret set PFX_PASSWORD --repo $Repo --body $PfxPassword
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to set PFX_PASSWORD"; exit $LASTEXITCODE }

Write-Host "Secrets set successfully. Trigger the GitHub Actions workflow (push to main or use Actions -> Run workflow)."
