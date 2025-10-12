<#
Generate a Certificate Signing Request (CSR) using Windows certreq.exe.

Usage examples:
  .\scripts\generate-csr.ps1 -CommonName "Notes Publisher LLC" -Organization "Notes Publisher LLC" -OutputPath .\artifacts

This will create an INF file and run:
  certreq -new .\scripts\notesapp.csr.inf .\artifacts\notesapp.csr

The resulting .csr file is what you submit to a Certificate Authority.

Notes:
- The private key is generated and stored in the CurrentUser personal store by default.
- After the CA issues the certificate you'll use `certreq -accept` to install it, then export to PFX if needed.
#>

param(
    [string]$CommonName = "Your Publisher Name",
    [string]$Organization = "Your Organization",
    [string]$OrganizationalUnit = "Development",
    [string]$City = "City",
    [string]$State = "State",
    [string]$Country = "US",
    [int]$KeyLength = 2048,
    [string]$OutputPath = ".\artifacts",
    [string]$FileBaseName = "notesapp"
)

Set-StrictMode -Version Latest

if (-not (Test-Path -Path $OutputPath)){
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$infPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "$FileBaseName.csr.inf"
$reqPath = Join-Path -Path $OutputPath -ChildPath "$FileBaseName.csr"

$subject = "CN=$CommonName, O=$Organization, OU=$OrganizationalUnit, L=$City, S=$State, C=$Country"


$inf = @'
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "__SUBJECT__"
KeySpec = 1
KeyLength = __KEYLEN__
Exportable = TRUE
MachineKeySet = FALSE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
HashAlgorithm = SHA256

[Extensions]
; Subject Alternative Name example (uncomment and edit if needed)
;2.5.29.17 = "{text}"
;_continue_ = "DNS=localhost"
'@

$inf = $inf -replace '__SUBJECT__', $subject -replace '__KEYLEN__', $KeyLength

Write-Output "Writing INF to: $infPath"
$inf | Out-File -FilePath $infPath -Encoding ASCII -Force

Write-Output "Generating CSR using certreq..."
try {
    $certreqOutput = & certreq.exe -new $infPath $reqPath 2>&1
    $exitCode = $LASTEXITCODE
    Write-Output $certreqOutput
    if ($exitCode -ne 0) {
        Write-Error "certreq failed with exit code $exitCode"
        exit $exitCode
    }
    else {
        Write-Output "CSR generated: $reqPath"
        Write-Output "INF used: $infPath"
    }
}
catch {
    Write-Error "Failed to run certreq: $_"
    exit 1
}

Write-Output "Next steps: Submit '$reqPath' to your Certificate Authority. After the CA issues a cert, run 'certreq -accept <issued.cer>' to install it, then export to PFX if needed. See SIGNING.md for full instructions."
