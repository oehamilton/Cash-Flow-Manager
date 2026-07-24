# Run the same checks as .github/workflows/ci.yml on a local Windows machine.
$ErrorActionPreference = 'Stop'

flutter --version
flutter pub get
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test --reporter expanded
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'CI local checks passed.'
