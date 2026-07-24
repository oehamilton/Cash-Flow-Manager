# Feature tracker

Living checklist aligned with [`PLAN.md`](PLAN.md). Update status on each subphase handoff.

Status values: `planned` | `in_progress` | `done` | `blocked` | `deferred`

| ID | Feature | Phase | Status | Tests |
|----|---------|-------|--------|-------|
| F-0.1 | Flutter Windows scaffold, analysis, gitignore, README, feature tracker, app version on home | 0.1 | `done` | `test/app_info_test.dart`, `test/widget_test.dart` |
| F-0.2 | Theme tokens + app shell navigation (UI direction gate) | 0.2 | `done` | `test/widget_test.dart`, `test/app_destination_test.dart` |
| F-0.2b | Optional theme revision | 0.2b | `deferred` | |
| F-0.3 | Encrypted DB (sqlite3mc), schema v1, exclusive lock file | 0.3 | `done` | `test/database_opener_test.dart`, `test/app_lock_file_test.dart` |
| F-0.4 | App password unlock + Windows Hello | 0.4 | `done` | `test/auth_service_test.dart`, `test/password_kdf_test.dart`, `test/widget_test.dart` (settings) |
| F-0.5 | First-run wizard → primary checking + opening balance | 0.5 | `done` | `test/setup_coordinator_test.dart`, `test/account_repository_test.dart`, `test/money_test.dart`, `test/vault_files_test.dart` |
| F-0.5b | Open / switch to a different vault database (Settings or open dialog) | 0.5b / 5.x | `planned` | |
| F-0.6 | Test harness baseline / sample coverage expansion | 0.6 | `done` | `test/harness_smoke_test.dart`, `test/support/*`, `.github/workflows/ci.yml` |
| F-0.7 | Audit log table + access-event logging (schema v2) | 0.7 | `planned` | |
| F-1.1 | Account CRUD + primary flag rules (+ audit writes) | 1.1 | `planned` | |
| F-1.2 | Accounts list + debt list | 1.2 | `planned` | |
| F-1.3 | Account info screen | 1.3 | `planned` | |
| F-1.4 | Open register for selected account; cold start → primary | 1.4 | `planned` | |
| F-2.1 | Transaction CRUD + payee autocomplete (+ audit writes) | 2.1 | `planned` | |
| F-2.2 | Running balance + virtualized list | 2.2 | `planned` | |
| F-2.3 | Clear / reconcile + statement ending balance (+ audit) | 2.3 | `planned` | |
| F-2.4 | Sticky register header metrics | 2.4 | `planned` | |
| F-2.5 | Cleared vs uncleared row styles | 2.5 | `planned` | |
| F-2.6 | Optional register UI / search / keyboard polish | 2.6 | `deferred` | |
| F-3.1 | Recurrence rule CRUD | 3.1 | `planned` | |
| F-3.2 | Materialize ~2 months of instances | 3.2 | `planned` | |
| F-3.3 | Manual future txs + forecast row colors | 3.3 | `planned` | |
| F-3.4 | Edit generated until cleared | 3.4 | `planned` | |
| F-3.5 | 4-week / 8-week trough metrics | 3.5 | `planned` | |
| F-3.6 | Optional forecast visuals pass | 3.6 | `deferred` | |
| F-4.1 | Interest / principal fields on txs | 4.1 | `planned` | |
| F-4.2 | 12-month account chart | 4.2 | `planned` | |
| F-4.3 | Extra-payment hint | 4.3 | `planned` | |
| F-5.1 | Polish, empty states, idle lock, Activity log viewer | 5.1 | `planned` | |
| F-5.2 | Backup / export | 5.2 | `planned` | |
| F-5.3 | Windows exe / MSIX packaging | 5.3 | `planned` | |
| F-5.4 | Full regression + Windows 11 checklist | 5.4 | `planned` | |
| F-6 | Android + sync safety | 6 | `planned` | |
