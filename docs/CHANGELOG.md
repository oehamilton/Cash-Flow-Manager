# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [4.1.0] — 2026-07-24

### Added

- Phase 4.1 interest/principal split fields on loan and credit-card transactions

## [3.5.0] — 2026-07-24

### Added

- Phase 3.5 header 4-week and 8-week forecast trough lows

## [3.4.0] — 2026-07-24

### Added

- Phase 3.4 edit recurring-generated rows until cleared (`is_user_overridden`)

## [3.3.0] — 2026-07-24

### Added

- Phase 3.3 manual future transactions and distinct forecast row colors

## [3.2.0] — 2026-07-24

### Added

- Phase 3.2 materialize ~2 months of recurrence instances (idempotent keys)

## [3.1.0] — 2026-07-24

### Added

- Phase 3.1 recurrence rule CRUD (frequencies; instances in 3.2)

## [2.6.0] — 2026-07-24

### Added

- Phase 2.6 register search/filter, keyboard shortcuts, and density polish

## [2.5.0] — 2026-07-24

### Added

- Phase 2.5 cleared vs uncleared register row styles (future-date preview tint)

## [2.4.0] — 2026-07-24

### Added

- Phase 2.4 sticky register header (reconciled, today, 4/8-wk trough placeholders)

## [2.3.0] — 2026-07-24

### Added

- Phase 2.3 clear/unclear, protect cleared edits, statement ending-balance reconcile

## [2.2.0] — 2026-07-24

### Added

- Phase 2.2 register Payment / Deposit / Balance columns with running balance

## [2.1.0] — 2026-07-24

### Added

- Phase 2.1 transaction CRUD on Register with payee autocomplete and audit writes

## [1.4.0] — 2026-07-24

### Added

- Phase 1.4 open Register for any account; cold start opens primary checking

## [1.3.0] — 2026-07-24

### Added

- Phase 1.3 account info screen (metadata, credentials, debt fields; chart placeholder)

## [1.2.0] — 2026-07-24

### Added

- Phase 1.2 Accounts list and Debts list (balance / APR / min payment) with Add account

## [1.1.0] — 2026-07-23

### Added

- Phase 1.1 account CRUD (all types), primary rules, archive/delete, audit writes

## [0.7.0] — 2026-07-23

### Added

- Phase 0.7 schema v2 `audit_log` + access-event logging (create/unlock/lock/Hello/force; failed unlocks via pending sidecar)

## [0.6.0] — 2026-07-23

### Added

- Phase 0.6 test harness (`TempVaultHarness`, `SampleDataset`) and GitHub Actions CI

## [0.5.0] — 2026-07-23

### Added

- Phase 0.5 setup wizard (location, security, primary checking + opening balance)
- Browse dialog for vault file path; auto-create missing parent folders
- Open existing vault or true overwrite when path already has a database
- Planned: open/switch to a different vault database (F-0.5b)

### Fixed

- Wizard opens the shell after creating a vault (was stuck until relaunch)
- Creating a vault in a new folder no longer fails on missing `.meta.json` path

## [0.4.0] — 2026-07-23

### Added

- App password unlock, Windows Hello opt-in, lock from Settings
- Windows Credential Manager secrets via `win32` (avoids JNI on ARM64)
- `docs/DEPENDENCIES.md` machine setup and Intel/ARM build notes

## [0.3.0] — 2026-07-23

### Added

- Encrypted SQLite (sqlite3mc), schema v1, exclusive `.cfm.lock` single-writer lock
- `DatabaseSession` open/migrate/close API for later unlock and wizard phases

## [0.2.0] — 2026-07-23

### Added

- Theme tokens (Rajdhani / IBM Plex Mono), NavigationRail shell, placeholder destinations
- Register row color tokens reserved for Phase 3

## [0.1.0] — 2026-07-23

### Added

- Flutter Windows scaffold (`cash_flow_manager`), feature tracker, home screen with app version
- Dark teal scaffold palette preview and dark Windows title bar
- Baseline unit/widget tests (`test/app_info_test.dart`, `test/widget_test.dart`)
