# Build a Windows release (and optionally a signed MSIX installer) for Cash Flow Manager.
#
# Usage:
#   .\tool\build_release.ps1                         # release exe folder only
#   .\tool\build_release.ps1 -Msix                   # release + signed MSIX (host arch)
#   .\tool\build_release.ps1 -Msix -Architecture arm64   # native ARM64 (Surface / Snapdragon)
#   .\tool\build_release.ps1 -Msix -Architecture x64     # Intel/AMD
#
# MSIX signing requires a Project8X PFX (see tool/new_code_signing_cert.ps1).
# End users trust the public .cer once (tool/install_trusted_publisher.ps1), then
# install without Developer Mode.
#
# Flutter Windows does not reliably cross-compile: build arm64 on an ARM64 host
# (e.g. Surface Pro with Snapdragon) and x64 on an Intel/AMD PC.
# See docs/DEPENDENCIES.md.

param(
    [switch]$Msix,
    [switch]$SkipTests,
    [ValidateSet('auto', 'arm64', 'x64')]
    [string]$Architecture = 'auto'
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

function Resolve-TargetArchitecture {
    param([string]$Requested)
    if ($Requested -ne 'auto') {
        return $Requested
    }
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        return 'arm64'
    }
    return 'x64'
}

function Resolve-MsixSigningCert {
    $certPath = $env:CFM_MSIX_CERT_PATH
    if (-not $certPath) {
        $certPath = Join-Path (Get-Location) 'secrets\Project8X-CodeSigning.pfx'
    }
    if (-not (Test-Path $certPath)) {
        Write-Error @"
MSIX signing certificate not found at:
  $certPath
Create one with:  .\tool\new_code_signing_cert.ps1
Or set CFM_MSIX_CERT_PATH / CFM_MSIX_CERT_PASSWORD.
"@
        exit 1
    }

    $password = $env:CFM_MSIX_CERT_PASSWORD
    if (-not $password) {
        $passwordFile = Join-Path (Split-Path -Parent $certPath) 'Project8X-CodeSigning.password.txt'
        if (Test-Path $passwordFile) {
            $password = (Get-Content -Path $passwordFile -Raw).Trim()
        }
    }
    if (-not $password) {
        Write-Error @"
MSIX certificate password not set. Set CFM_MSIX_CERT_PASSWORD or create
secrets\Project8X-CodeSigning.password.txt (via new_code_signing_cert.ps1).
"@
        exit 1
    }

    return @{
        Path     = (Resolve-Path $certPath).Path
        Password = $password
    }
}

function Get-CertificatePublisherDn {
    param([string]$PfxPath, [string]$Password)
    $secure = ConvertTo-SecureString -String $Password -Force -AsPlainText
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $PfxPath,
        $secure,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    )
    return $cert.Subject
}

$targetArch = Resolve-TargetArchitecture -Requested $Architecture
$hostArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }

if ($targetArch -ne $hostArch) {
    Write-Host @"
WARNING: Requested architecture '$targetArch' differs from this host ($hostArch).
Flutter Windows builds for the host architecture; the MSIX --architecture flag
must match the binaries under build\windows\$hostArch. Prefer building on a
$hostArch machine, or omit -Architecture to use auto-detect.
"@ -ForegroundColor Yellow
    if ($Msix) {
        Write-Error "Refusing MSIX with mismatched -Architecture ($targetArch) on $hostArch host."
        exit 1
    }
}

Write-Host "== Target architecture: $targetArch (host: $hostArch) ==" -ForegroundColor Cyan

Write-Host '== flutter pub get ==' -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipTests) {
    Write-Host '== flutter analyze ==' -ForegroundColor Cyan
    flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '== flutter test ==' -ForegroundColor Cyan
    flutter test --concurrency=1
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host '== flutter build windows --release ==' -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$releaseDir = "build\windows\$hostArch\runner\Release"
if (Test-Path $releaseDir) {
    Write-Host "Release folder ($hostArch): $releaseDir" -ForegroundColor Green
} else {
    # Fallback: scan for whichever arch Flutter wrote.
    $archDirs = Get-ChildItem -Path 'build\windows' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('x64', 'arm64') }
    foreach ($arch in $archDirs) {
        $runner = Join-Path $arch.FullName 'runner\Release'
        if (Test-Path $runner) {
            Write-Host "Release folder ($($arch.Name)): $runner" -ForegroundColor Green
            $hostArch = $arch.Name
            $releaseDir = $runner
        }
    }
}

if ($Msix) {
    $signing = Resolve-MsixSigningCert
    $publisher = Get-CertificatePublisherDn -PfxPath $signing.Path -Password $signing.Password
    $msixArch = $hostArch
    $outputName = "CashFlowManager-$msixArch"
    $msixOut = 'build\windows\msix'

    Write-Host "== dart run msix:create (architecture=$msixArch, signed, output=$outputName) ==" -ForegroundColor Cyan
    Write-Host "Using cert: $($signing.Path)" -ForegroundColor DarkGray
    Write-Host "Publisher:  $publisher" -ForegroundColor DarkGray

    # Windows build already done above; avoid a second full compile.
    # install-certificate false: do not mutate the build machine trust store;
    # end users run tool/install_trusted_publisher.ps1 once instead.
    dart run msix:create `
        --build-windows false `
        --architecture $msixArch `
        --output-name $outputName `
        --certificate-path $signing.Path `
        --certificate-password $signing.Password `
        --publisher $publisher `
        --install-certificate false
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    New-Item -ItemType Directory -Force -Path $msixOut | Out-Null
    $publicCer = 'packaging\Project8X-CodeSigning.cer'
    if (-not (Test-Path $publicCer)) {
        # Export public cert from the PFX used for this build.
        $secure = ConvertTo-SecureString -String $signing.Password -Force -AsPlainText
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
            $signing.Path,
            $secure,
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        )
        New-Item -ItemType Directory -Force -Path 'packaging' | Out-Null
        $bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes((Join-Path (Get-Location) $publicCer), $bytes)
    }
    Copy-Item -Path $publicCer -Destination (Join-Path $msixOut 'Project8X-CodeSigning.cer') -Force

    if (Test-Path $msixOut) {
        Get-ChildItem $msixOut -Filter 'CashFlowManager-*.msix' | ForEach-Object {
            Write-Host "MSIX: $($_.FullName)" -ForegroundColor Green
        }
        Write-Host "Public cert: $(Join-Path $msixOut 'Project8X-CodeSigning.cer')" -ForegroundColor Green
        Write-Host @"

End-user install (no Developer Mode):
  1. .\tool\install_trusted_publisher.ps1
  2. Add-AppxPackage -Path .\$msixOut\$outputName.msix
     (or double-click the .msix)
"@ -ForegroundColor DarkGray
    }
}

Write-Host 'Done.' -ForegroundColor Green
