# Developer dependencies & machine setup

What to install when coding or building Cash Flow Manager on a **new Windows machine**. Keep this file updated when tooling changes.

**Last verified:** 2026-08-07 on Windows 11 x64 (Intel), Flutter 3.44.9 stable / Dart 3.12.2. Previously: 2026-07-23 on Windows 11 ARM64 (Snapdragon-class), Flutter 3.44.8.

## Windows CPU architectures (Intel / AMD / ARM)

| Host machine | `flutter run -d windows` / `flutter build windows` produces | Runs on |
|--------------|--------------------------------------------------------------|---------|
| **Windows x64** (Intel / AMD) | `windows-x64` app | Native on Intel/AMD; usually runs on ARM64 via Windows x64 emulation |
| **Windows ARM64** (Snapdragon, etc.) | `windows-arm64` app | Native on ARM64 only (not for Intel PCs) |

**Practical release guidance (Phase 5 packaging):**

1. **Default ship target:** build **x64** on an Intel/AMD Windows PC (or CI x64 runner). That covers most PCs; ARM Windows can run it under emulation.
2. **Optional native ARM64 build:** build again on an ARM64 Windows machine for best performance on Snapdragon devices.
3. Flutter does **not** reliably cross-compile Windows x64 ↔ ARM64 on one machine yet — build on the matching host (or use two builders).
4. Prefer packages that compile from source or ship **both** x64 and ARM64 binaries. Avoid plugins that embed **x64-only** prebuilt `.lib`/`.dll` when developing on ARM64 (this bit us with JNI via `flutter_secure_storage` / `path_provider_android`).

**Current stack choices that help multi-arch Windows:**

- Encrypted DB: `sqlite3` + `hooks → sqlite3mc` (native assets, not a fixed x64-only DLL we vendor)
- Secrets: `win32` Credential Manager (no Java/JNI)
- Biometrics: `local_auth` / `local_auth_windows`
- Paths: `%APPDATA%\CashFlowManager\` (no `path_provider` on Windows for now)
- File browse: `file_selector` / `file_selector_windows` (native dialog; no JNI)
- CI: GitHub Actions `windows-latest` with `subosito/flutter-action` (stable) — see `.github/workflows/ci.yml`

## Required installs (Windows desktop development)

### 1. Git

- [Git for Windows](https://git-scm.com/download/win)
- Verify: `git --version`

### 2. Flutter SDK (stable)

```powershell
git clone https://github.com/flutter/flutter.git -b stable --depth 1 $env:USERPROFILE\develop\flutter
```

Add to **User PATH**: `%USERPROFILE%\develop\flutter\bin`  
Open a **new** terminal, then:

```powershell
flutter --version
flutter doctor
flutter config --no-analytics   # optional
```

Pinned expectation: **Flutter stable ≥ 3.44** with Dart matching `pubspec.yaml` (`sdk: ^3.12.2`).

If `flutter pub get` fails with “requires SDK version ^3.12.2” while `dart --version` shows an older SDK (e.g. 3.8.x), your Flutter install is stale — run `flutter upgrade` (or reinstall stable) and open a new terminal. Do **not** lower the project SDK constraint.

### 3. Visual Studio 2022 (Windows desktop toolchain)

Install **Visual Studio 2022** Community (or Build Tools) with workload:

- **Desktop development with C++**

Include:

- MSVC v143 (or current) toolset for your host arch (x64 and/or ARM64)
- Windows 10/11 SDK (e.g. 10.0.22621.0 or newer)

Verify: `flutter doctor` shows a green **Visual Studio** line.

### 4. Windows Developer Mode (symlinks)

Required for Flutter **plugin** builds on Windows.

- Settings → System → **For developers** → **Developer Mode** = On  
- Or: `start ms-settings:developers`

### 5. GitHub CLI (optional but used by our process)

```powershell
winget install --id GitHub.cli -e
gh auth login   # HTTPS recommended for this repo
```

### 6. Editor

- Cursor / VS Code with Flutter + Dart extensions  
- Or Android Studio (not required for Windows-only work)

## Not required for Windows-only Phase 0–5

| Tool | When needed |
|------|-------------|
| Android Studio / Android SDK | Phase 6 (Android) |
| Chrome | Web only (we use Edge if needed) |
| JDK | Not required for current Windows stack (avoid pulling JNI plugins) |
| CocoaPods / Xcode | Never for this Windows/Android plan |

## Pub / project dependencies (Dart)

Installed via `flutter pub get` from [`pubspec.yaml`](../pubspec.yaml). Highlights:

| Package | Purpose |
|---------|---------|
| `sqlite3` + `hooks: sqlite3mc` | Encrypted SQLite |
| `local_auth` | Windows Hello |
| `win32` + `ffi` | Credential Manager secrets |
| `cryptography` | PBKDF2 password → DB passphrase |
| `uuid`, `path`, `cupertino_icons` | Utilities / icons |
| `flutter_lints`, `mocktail` | Dev / tests |

Bundled fonts (no install): see [`FONTS.md`](FONTS.md).

## First-time clone checklist

```powershell
# 1) Install Git, Flutter, VS 2022 C++ workload, Developer Mode, gh (above)

# 2) Clone
git clone https://github.com/oehamilton/Cash-Flow-Manager.git
cd Cash-Flow-Manager

# 3) Fetch packages
flutter pub get

# 4) Health check
flutter doctor
flutter analyze
flutter test

# 5) Run
flutter run -d windows
```

Default vault location after create:  
`%APPDATA%\CashFlowManager\vault.cfm.db`

## Build outputs

```powershell
flutter build windows --debug     # local testing
flutter build windows --release   # closer to ship
```

Artifacts land under `build\windows\<arch>\runner\...`  
(`arm64` on ARM hosts, `x64` on Intel/AMD hosts).

### Release + MSIX (Phase 5.3)

Packaging is **MSIX** (App Installer / `Add-AppxPackage`), not a classic WiX `.msi`. That is the Windows store-style package this repo ships today.

**Signing cert (once per build machine):**

```powershell
.\tool\new_code_signing_cert.ps1
```

Creates a Project8X code-signing PFX under `secrets/` (gitignored) and a public `.cer` under `packaging/` (safe to ship). See [`secrets/README.md`](../secrets/README.md).

**Build signed package:**

```powershell
.\tool\build_release.ps1                              # analyze, test, release build
.\tool\build_release.ps1 -Msix                        # signed MSIX for this host's arch
.\tool\build_release.ps1 -Msix -Architecture arm64    # native ARM64 (Surface / Snapdragon)
.\tool\build_release.ps1 -Msix -Architecture x64      # Intel/AMD
```

Uses the `msix` pub.dev package (`msix_config` in `pubspec.yaml`). The script:

- Builds a **release** Windows app for the **host** architecture (Flutter does not cross-compile Windows reliably).
- **Signs** the MSIX with the Project8X PFX (`CFM_MSIX_CERT_PATH` / `CFM_MSIX_CERT_PASSWORD`, or `secrets/…`).
- Writes `build\windows\msix\CashFlowManager-<arch>.msix` plus `Project8X-CodeSigning.cer`.
- Fails clearly if the signing cert is missing (no silent unsigned release MSIX).

**End-user install (no Developer Mode):** trust the publisher cert once (admin), then install the MSIX:

```powershell
.\tool\install_trusted_publisher.ps1
# Intel/AMD host:
Add-AppxPackage -Path .\build\windows\msix\CashFlowManager-x64.msix
# ARM64 host:
# Add-AppxPackage -Path .\build\windows\msix\CashFlowManager-arm64.msix
```

Or double-click the `.msix` after the cert is trusted. Developer Mode remains useful for **Flutter development** (plugin symlinks), not for end-user installs.

**Intel / AMD:** run `-Msix` (or `-Architecture x64`) on this class of machine for `CashFlowManager-x64.msix`.  
**Surface Pro / Windows on ARM:** run the arm64 build **on the tablet** (or any Snapdragon Windows host) for a native ARM64 binary.

## CI / second machine tips

- Record **host arch** in any release notes (`x64` vs `arm64`).
- On a new machine, re-run `flutter doctor` until Windows + VS are green before debugging app bugs.
- Prefer dependencies without Java/JNI and without x64-only precompiled plugin binaries.
- Keep this file in sync when adding plugins that touch native Windows code.

## Related docs

- [`PLAN.md`](PLAN.md) — product plan  
- [`FEATURES.md`](FEATURES.md) — phase tracker  
- [`README.md`](../README.md) — quick start  
