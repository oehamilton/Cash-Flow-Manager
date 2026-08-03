# Install the Project8X public code-signing certificate into Local Machine
# Trusted People so users can sideload Cash Flow Manager MSIX packages without
# enabling Developer Mode.
#
# Usage (run elevated / will request elevation):
#   .\tool\install_trusted_publisher.ps1
#   .\tool\install_trusted_publisher.ps1 -CerPath .\packaging\Project8X-CodeSigning.cer
#
# After this one-time step:
#   Add-AppxPackage -Path .\build\windows\msix\CashFlowManager-arm64.msix
#   # or double-click the .msix

param(
    [string]$CerPath = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $CerPath) {
    $candidates = @(
        (Join-Path $root 'packaging\Project8X-CodeSigning.cer'),
        (Join-Path $root 'build\windows\msix\Project8X-CodeSigning.cer')
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $CerPath = $c
            break
        }
    }
}

if (-not $CerPath -or -not (Test-Path $CerPath)) {
    Write-Error @"
Public certificate not found. Expected one of:
  packaging\Project8X-CodeSigning.cer
  build\windows\msix\Project8X-CodeSigning.cer
Or pass -CerPath. Generate with: .\tool\new_code_signing_cert.ps1
"@
    exit 1
}

$CerPath = (Resolve-Path $CerPath).Path

if (-not (Test-IsAdmin)) {
    Write-Host 'Elevation required to install into Local Machine Trusted People...' -ForegroundColor Yellow
    $script = Join-Path $PSScriptRoot 'install_trusted_publisher.ps1'
    $argList = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $script
        '-CerPath', $CerPath
    )
    $proc = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait -PassThru
    exit $proc.ExitCode
}

Write-Host "== Importing $CerPath into LocalMachine\TrustedPeople ==" -ForegroundColor Cyan
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CerPath)
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPeople,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
try {
    $existing = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
    if ($existing) {
        Write-Host "Already trusted: $($cert.Subject) [$($cert.Thumbprint)]" -ForegroundColor Green
    } else {
        $store.Add($cert)
        Write-Host "Trusted: $($cert.Subject) [$($cert.Thumbprint)]" -ForegroundColor Green
    }
} finally {
    $store.Close()
}

Write-Host @"

Certificate installed. You do not need Developer Mode to install a matching
Project8X-signed MSIX. Next:

  Add-AppxPackage -Path .\build\windows\msix\CashFlowManager-arm64.msix
  # or double-click the .msix in Explorer

"@ -ForegroundColor DarkGray
