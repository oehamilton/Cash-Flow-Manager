# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [6.4.1] — 2026-08-04

### Changed

- 8-week trough is the low in weeks 4–8 only (not the full 8-week span); 4-week remains today→week 4
- Register trough chips show the date each low occurs
- Register sorts same-day deposits before deductions so running/trough balances apply income first

## [6.4.0] — 2026-08-03

### Changed

- Payees is a left-rail destination (not nested under Settings)
- Register header includes an account dropdown to switch registers
- Recurring editor uses the same account/payee autocomplete as the register (account payee = transfer)
- Register defaults to Open rows; All scrolls to the last cleared / first open boundary; Open/Clr jump to top
- Register search accepts dates/weeks/months (`2026-08-03`, `8/3/2026`, `2026-08`, `Aug 2026`, `this week`, `week of 8/3/2026`, `2026-W32`, …) in addition to payee/memo

### Added

- Activity log retention (default 1 year; 90 days / 1 year / 2 years / Forever) with prune on unlock
- Activity log search (summary, category, action, device; dollar amounts match cents) and paging (25 per page)
- About dialog (Project8X) from Settings and the left-rail brand/version
- ARM64 MSIX packaging path for Surface / Snapdragon (`build_release.ps1 -Msix -Architecture arm64`)
- Project8X code-signed MSIX + `install_trusted_publisher.ps1` so end users install without Developer Mode
- Open / switch active vault from Settings or Unlock (F-0.5b); Hello credentials scoped per vault path
- Restore vault from backup (copy into Documents\\CashFlowManager\\Restored, then switch)
- Create new vault under Documents/CashFlowManager/<Name> for separate books (Personal vs Business)
- Recent vaults list on Unlock and Settings (labels, rename, remove from list)

### Fixed

- Deleting a recurring register occurrence (including transfers) records a skip so rematerialize does not recreate it (schema v5)

## [6.3.0] — 2026-07-24

### Added

- Phase 6.1 linked transfers: choose an account as payee to post paired register legs; edit syncs both; delete removes both; clear stays per-leg
- Phase 6.2 payee directory in Settings (notes/contact, rename, merge) + autocomplete with accounts/managed/history
- Phase 6.3 recurring transfers via `linked_account_id` + jump-to-other-account from transfer rows
- Schema v4: `payees` table, `transactions.payee_id`, transfer_pair index

## [5.3.0] — 2026-07-24

### Added

- Phase 5.3 Windows release packaging: `msix` config + `tool/build_release.ps1` (exe folder and optional MSIX) — parked pending resume of ship work

## [5.2.0] — 2026-07-24

### Added

- Phase 5.2 encrypted vault backup (database + meta) from Settings
- Optional CSV register export for a selected account (dollar amounts with two decimals)

## [5.1.0] — 2026-07-24

### Added

- Phase 5.1 Activity log viewer in Settings (read-only audit trail, shows device)
- Idle lock timeout setting (Never / 5 / 15 / 30 / 60 minutes; default 15)
- Archive account confirmation dialog

## [4.3.0] — 2026-07-24

### Added

- Phase 4.3 extra-payment hint from primary 4-week trough + APR-sorted debts
- Checking `min_balance_cents` cash buffer (schema v3): suggested extra = 4-wk trough − buffer; burnt-orange register/trough warnings when below it
- Red target icon on suggested debt (replaces "· target" text)

### Changed

- Debt/loan/card registers: positive balance = amount owed; negative = credit (they owe you)
- Extra-payment suggestion is `max(0, 4-wk trough − min balance)`

## [4.2.0] — 2026-07-24

### Added

- Phase 4.2 12-month account history chart (balance + interest paid)

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
