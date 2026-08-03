# Cash Flow Manager

Local-first bank register and short-horizon cash flow forecaster for Windows 11 (Android later). Built with Flutter; data stored in a user-selectable encrypted SQLite database.

**Current version:** 6.4.0 (Phase 6 Transfers & Payees + multi-vault)

Data files use SQLite3MultipleCiphers encryption (`hooks.sqlite3.source: sqlite3mc`). Never commit `*.cfm.db` or `*.cfm.lock` files.

**Windows notes:** Flutter plugin builds need Developer Mode (symlinks). Hello secrets use Windows Credential Manager (`win32`) — not `flutter_secure_storage` — to avoid a broken JNI/x64 JDK link on Windows ARM64.

## Documentation

- **[Requirements & phased plan](docs/PLAN.md)** — approved product and development plan
- **[Feature tracker](docs/FEATURES.md)** — progress by phase/subphase
- **[Dependencies & machine setup](docs/DEPENDENCIES.md)** — install list for a new PC (Intel/ARM notes)
- **[Changelog](docs/CHANGELOG.md)** — notable changes per merge
- **[Fonts](docs/FONTS.md)** — bundled UI typefaces (OFL)

## Prerequisites

See **[docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)** for the full install list. Short version:

- Flutter SDK (stable) on `PATH`
- Visual Studio 2022 with **Desktop development with C++**
- Windows **Developer Mode** (plugin symlinks)
- Git; optional GitHub CLI (`gh`)

```bash
flutter doctor
```

## Run (Windows)

```bash
flutter pub get
flutter run -d windows
```

## Test

```bash
flutter test
flutter analyze
```

Same checks locally (Windows):

```powershell
.\tool\ci_local.ps1
```

CI runs `flutter analyze` + `flutter test` on every push/PR (`.github/workflows/ci.yml`). Shared fixtures live under `test/support/`.

## Release build (Windows)

Build on a machine that matches the install target: **x64** for Intel/AMD PCs, **arm64** on a Surface Pro / Snapdragon host for a native ARM installer (see [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md)).

```powershell
# One-time on the build machine: Project8X signing cert (PFX stays in secrets/)
.\tool\new_code_signing_cert.ps1

# Release folder under build\windows\<arch>\runner\Release
.\tool\build_release.ps1

# Signed MSIX for this host (CashFlowManager-arm64.msix on Surface / ARM)
.\tool\build_release.ps1 -Msix

# Explicit native ARM64 package (must run on an ARM64 Windows host)
.\tool\build_release.ps1 -Msix -Architecture arm64
```

**End users (no Developer Mode):** trust the publisher once, then install:

```powershell
.\tool\install_trusted_publisher.ps1
Add-AppxPackage -Path build\windows\msix\CashFlowManager-arm64.msix
```

Store / paid CA signing is a later upgrade. Partner Center identity is not configured here.

## Development process

Work proceeds in small subphases (see `docs/PLAN.md`). Each subphase: implement → automated tests → your review → explicit approval → commit/PR to GitHub → next subphase.

## License

[GPL-3.0](LICENSE)
