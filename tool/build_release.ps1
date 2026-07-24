# Build a Windows release (and optionally an MSIX installer) for Cash Flow Manager.
#
# Usage:
#   .\tool\build_release.ps1              # release exe folder only
#   .\tool\build_release.ps1 -Msix        # release + MSIX under build\windows\msix
#
# Prefer an Intel/AMD (x64) host for the default ship build; ARM64 hosts produce
# windows-arm64 artifacts (see docs/DEPENDENCIES.md).

param(
    [switch]$Msix,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

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

$archDirs = Get-ChildItem -Path 'build\windows' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @('x64', 'arm64') }
foreach ($arch in $archDirs) {
    $runner = Join-Path $arch.FullName 'runner\Release'
    if (Test-Path $runner) {
        Write-Host "Release folder ($($arch.Name)): $runner" -ForegroundColor Green
    }
}

if ($Msix) {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    Write-Host "== dart run msix:create (architecture=$arch) ==" -ForegroundColor Cyan
    # Windows build already done above; avoid a second full compile.
    dart run msix:create --build-windows false --architecture $arch --install-certificate false
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $msixOut = 'build\windows\msix'
    if (Test-Path $msixOut) {
        Get-ChildItem $msixOut -Filter '*.msix' | ForEach-Object {
            Write-Host "MSIX: $($_.FullName)" -ForegroundColor Green
        }
    }
}

Write-Host 'Done.' -ForegroundColor Green
