import '../../auth/auth_service.dart';
import '../../auth/vault_location_store.dart';
import '../../data/account_repository.dart';

/// How the wizard should treat the chosen vault path.
enum VaultSetupAction {
  /// Path is empty — create a new vault.
  create,

  /// Unlock an existing complete vault.
  open,

  /// Delete existing vault files and create a new one.
  overwrite,
}

/// Orchestrates first-run vault + primary checking creation.
class SetupCoordinator {
  SetupCoordinator(this.auth);

  final AuthService auth;

  /// Fresh install: save path, create or open vault, optionally create primary.
  Future<void> completeFreshSetup({
    required String databasePath,
    required String password,
    required bool enableHello,
    required bool forceUnlock,
    required VaultSetupAction action,
    PrimaryCheckingDraft? primary,
  }) async {
    await VaultLocationStore.save(databasePath);

    switch (action) {
      case VaultSetupAction.open:
        await auth.unlockWithPassword(
          password: password,
          databasePath: databasePath,
          forceUnlock: forceUnlock,
        );
        return;
      case VaultSetupAction.create:
      case VaultSetupAction.overwrite:
        if (primary == null) {
          throw AuthException('Primary checking details are required');
        }
        await auth.createVault(
          password: password,
          databasePath: databasePath,
          enableHello: enableHello,
          forceUnlock: forceUnlock,
          overwrite: action == VaultSetupAction.overwrite,
        );
        final session = auth.session;
        if (session == null) {
          throw AuthException('Vault session missing after create');
        }
        AccountRepository(session).createPrimaryChecking(primary);
    }
  }

  /// Vault already unlocked but missing a primary account.
  Future<void> completePrimaryOnly(PrimaryCheckingDraft primary) async {
    final session = auth.session;
    if (session == null) {
      throw AuthException('Unlock the vault before finishing setup');
    }
    AccountRepository(session).createPrimaryChecking(primary);
  }

  bool needsPrimaryAccount() {
    final session = auth.session;
    if (session == null) {
      return false;
    }
    return !AccountRepository(session).hasPrimaryAccount();
  }
}
