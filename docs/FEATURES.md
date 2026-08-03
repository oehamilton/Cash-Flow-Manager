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
| F-0.7 | Audit log table + access-event logging (schema v2) | 0.7 | `done` | `test/audit_log_test.dart` |
| F-1.1 | Account CRUD + primary flag rules (+ audit writes) | 1.1 | `done` | `test/account_repository_test.dart` |
| F-1.2 | Accounts list + debt list | 1.2 | `done` | `test/accounts_lists_test.dart` |
| F-1.3 | Account info screen | 1.3 | `done` | `test/account_info_page_test.dart`, `test/account_repository_test.dart` |
| F-1.4 | Open register for selected account; cold start → primary | 1.4 | `done` | `test/register_page_test.dart` |
| F-2.1 | Transaction CRUD + payee autocomplete (+ audit writes) | 2.1 | `done` | `test/transaction_repository_test.dart` |
| F-2.2 | Running balance + credit/debit columns + virtualized list | 2.2 | `done` | `test/register_running_balance_test.dart` |
| F-2.3 | Clear / reconcile + statement ending balance (+ audit) | 2.3 | `done` | `test/transaction_clear_reconcile_test.dart` |
| F-2.4 | Sticky register header metrics | 2.4 | `done` | `test/register_metrics_test.dart` |
| F-2.5 | Cleared vs uncleared row styles | 2.5 | `done` | `test/register_row_style_test.dart` |
| F-2.6 | Register UI / search / keyboard polish | 2.6 | `done` | `test/register_filter_test.dart` |
| F-3.1 | Recurrence rule CRUD | 3.1 | `done` | `test/recurrence_rule_repository_test.dart` |
| F-3.2 | Materialize ~2 months of instances | 3.2 | `done` | `test/recurrence_materializer_test.dart` |
| F-3.3 | Manual future txs + forecast row colors | 3.3 | `done` | `test/register_row_style_test.dart`, `test/transaction_repository_test.dart` |
| F-3.4 | Edit generated until cleared | 3.4 | `done` | `test/recurrence_edit_generated_test.dart` |
| F-3.5 | 4-week / 8-week trough metrics | 3.5 | `done` | `test/register_metrics_test.dart` |
| F-3.6 | Optional forecast visuals pass | 3.6 | `deferred` | |
| F-4.1 | Interest / principal fields on txs | 4.1 | `done` | `test/transaction_interest_principal_test.dart` |
| F-4.2 | 12-month account chart | 4.2 | `done` | `test/account_history_test.dart` |
| F-4.3 | Extra-payment hint + checking min-balance buffer | 4.3 | `done` | `test/extra_payment_hint_test.dart`, `test/register_row_style_test.dart`, `test/audit_log_test.dart` |
| F-5.1 | Polish, empty states, idle lock, Activity log viewer (+ search, retention, paging, dollar→cents search), About (Project8X) | 5.1 | `done` | `test/activity_log_test.dart`, `test/audit_retention_search_test.dart`, `test/idle_lock_controller_test.dart`, `test/app_settings_repository_test.dart`, `test/about_dialog_test.dart` |
| F-5.2 | Backup / export | 5.2 | `done` | `test/vault_backup_service_test.dart`, `test/register_csv_exporter_test.dart` |
| F-5.3 | Windows exe / signed MSIX (x64 + arm64); trusted Project8X cert install without Developer Mode | 5.3 | `in_progress` | `tool/build_release.ps1`, `tool/new_code_signing_cert.ps1`, `tool/install_trusted_publisher.ps1`, `msix_config` in `pubspec.yaml` |
| F-5.4 | Full regression + Windows 11 checklist | 5.4 | `deferred` (parked) | |
| F-6.1 | Linked transfers (account-as-payee, paired edit/delete) | 6.1 | `done` | `test/transfer_amounts_test.dart`, `test/transfer_repository_test.dart` |
| F-6.2 | Payee directory + autocomplete (left-rail Payees) | 6.2 | `done` | `test/payee_repository_test.dart`, `test/app_destination_test.dart`, `test/payees_nav_test.dart` |
| F-6.3 | Recurring transfers + jump-to-other-leg | 6.3 | `done` | `test/recurrence_transfer_materializer_test.dart`, `test/recurrence_skip_deleted_test.dart` |
| F-7 | Android + sync safety | 7 | `planned` | |
