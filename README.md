# Cash Flow Manager

Local-first bank register and short-horizon cash flow forecaster for Windows 11 (Android later). Built with Flutter; data stored in a user-selectable encrypted SQLite database.

**Current version:** 0.1.0 (Phase 0.1 scaffold)

## Documentation

- **[Requirements & phased plan](docs/PLAN.md)** — approved product and development plan
- **[Feature tracker](docs/FEATURES.md)** — progress by phase/subphase
- **[Changelog](docs/CHANGELOG.md)** — notable changes per merge

## Prerequisites

- Flutter SDK (stable), on `PATH`
- Windows 11 with Visual Studio 2022 (**Desktop development with C++**) for Windows builds

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

## Development process

Work proceeds in small subphases (see `docs/PLAN.md`). Each subphase: implement → automated tests → your review → explicit approval → commit/PR to GitHub → next subphase.

## License

[GPL-3.0](LICENSE)
