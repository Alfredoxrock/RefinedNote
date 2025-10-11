<#
sign-appx.ps1

Helper PowerShell script to produce a signed Appx/MSIX using electron-builder.
Usage:
  .\scripts\sign-appx.ps1 -PfxPath 'C:\keystore\notesapp.pfx' -PfxPassword 'password'

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PfxPath,
    [Parameter(Mandatory=$true)]
    [string]$PfxPassword
)

if (-not (Test-Path $PfxPath)) {
    Write-Error "Specified PFX path does not exist: $PfxPath"
    exit 2
}

# Export as file:// path for electron-builder
$abs = (Get-Item $PfxPath).FullName
$fileUrl = "file:///$abs" -replace "\\","/"

Write-Host "Using PFX: $abs"

# Set environment variables for this session
$env:CSC_LINK = $fileUrl
$env:CSC_KEY_PASSWORD = $PfxPassword

Write-Host "Environment variables set. Running electron-builder to create signed Appx..."

npm run build:appx

if ($LASTEXITCODE -ne 0) {
    Write-Error "electron-builder failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Build finished. Check the 'dist_appx' folder for the signed Appx/MSIX package."
