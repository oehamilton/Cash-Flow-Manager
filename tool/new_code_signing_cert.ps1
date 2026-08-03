# Create a Project8X code-signing certificate for MSIX packages.
#
# Usage:
#   .\tool\new_code_signing_cert.ps1
#   .\tool\new_code_signing_cert.ps1 -Force   # overwrite existing PFX
#
# Outputs:
#   secrets/Project8X-CodeSigning.pfx
#   secrets/Project8X-CodeSigning.password.txt
#   packaging/Project8X-CodeSigning.cer   (public; safe to ship)
#
# Subject CN must match msix_config publisher (CN=Project8X).

param(
    [switch]$Force,
    [string]$Subject = 'CN=Project8X',
    [int]$ValidYears = 5
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$secretsDir = Join-Path $root 'secrets'
$packagingDir = Join-Path $root 'packaging'
$pfxPath = Join-Path $secretsDir 'Project8X-CodeSigning.pfx'
$passwordPath = Join-Path $secretsDir 'Project8X-CodeSigning.password.txt'
$cerPath = Join-Path $packagingDir 'Project8X-CodeSigning.cer'

New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
New-Item -ItemType Directory -Force -Path $packagingDir | Out-Null

if ((Test-Path $pfxPath) -and -not $Force) {
    Write-Error "PFX already exists at $pfxPath. Re-run with -Force to replace it (breaks trust of the old public .cer)."
    exit 1
}

# Random password for the PFX (stored locally only).
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 24
$rng.GetBytes($bytes)
$passwordPlain = [Convert]::ToBase64String($bytes)
$securePassword = ConvertTo-SecureString -String $passwordPlain -Force -AsPlainText

Write-Host "== Creating self-signed code-signing cert ($Subject) ==" -ForegroundColor Cyan
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $Subject `
    -FriendlyName 'Project8X Code Signing' `
    -KeyUsage DigitalSignature `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -HashAlgorithm SHA256 `
    -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotAfter (Get-Date).AddYears($ValidYears) `
    -TextExtension @(
        '2.5.29.37={text}1.3.6.1.5.5.7.3.3', # Code Signing EKU
        '2.5.29.19={text}false'              # basicConstraints CA=false
    )

try {
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
    Export-Certificate -Cert $cert -FilePath $cerPath -Type CERT | Out-Null
    Set-Content -Path $passwordPath -Value $passwordPlain -Encoding ascii -NoNewline
} finally {
    # Remove from CurrentUser\My so the private key lives only in the PFX file.
    Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue
}

Write-Host "PFX:      $pfxPath" -ForegroundColor Green
Write-Host "Password: $passwordPath" -ForegroundColor Green
Write-Host "Public:   $cerPath" -ForegroundColor Green
Write-Host "Publisher DN (for msix): $($cert.Subject)" -ForegroundColor DarkGray
Write-Host 'Done. Keep the PFX and password private; ship only the .cer to end users.' -ForegroundColor Green
