# Cash Flow Manager

Local-first bank register and short-horizon cash flow forecaster for Windows 11 (Android later). Built with Flutter; data stored in a user-selectable encrypted SQLite database.

**Current version:** 6.3.0 (Phase 6 Transfers & Payees)

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

Prefer an **x64** (Intel/AMD) host for the default ship build; ARM64 hosts produce native ARM64 binaries (see [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md)).

```powershell
# Release folder under build\windows\<arch>\runner\Release
.\tool\build_release.ps1

# Also produce an MSIX installer under build\windows\msix\
.\tool\build_release.ps1 -Msix
```

Or manually:

```powershell
flutter build windows --release
# Use arm64 on ARM hosts; x64 is the default ship target
dart run msix:create --build-windows false --architecture x64 --install-certificate false
```

Sideload the `.msix` (Developer Mode / trusted certificate as required by Windows). Store publishing needs Partner Center identity — not configured here.

## Development process

Work proceeds in small subphases (see `docs/PLAN.md`). Each subphase: implement → automated tests → your review → explicit approval → commit/PR to GitHub → next subphase.

## License

[GPL-3.0](LICENSE)
