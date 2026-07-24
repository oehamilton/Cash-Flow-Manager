import 'dart:io';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/biometric_auth.dart';
import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:cash_flow_manager/auth/secure_store.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/data/database_session.dart';
import 'package:path/path.dart' as p;

import 'sample_dataset.dart';

/// Shared temp-vault fixture for unit/widget tests that need an encrypted DB.
///
/// Use with `setUp` / `tearDown`:
/// ```dart
/// final harness = TempVaultHarness();
/// setUp(harness.setUp);
/// tearDown(harness.tearDown);
/// ```
class TempVaultHarness {
  TempVaultHarness({
    this.password = defaultPassword,
    this.kdfIterations = 1000,
    this.helloSupported = false,
  });

  static const defaultPassword = 'test-password-123';

  final String password;
  final int kdfIterations;
  final bool helloSupported;

  late Directory directory;
  late String databasePath;
  late FakeBiometricAuth biometric;
  late AuthService auth;

  DatabaseSession get session {
    final current = auth.session;
    if (current == null) {
      throw StateError('Vault is locked; call createUnlockedVault first');
    }
    return current;
  }

  Future<void> setUp() async {
    directory = await Directory.systemTemp.createTemp('cfm_harness_');
    databasePath = p.join(directory.path, 'vault.cfm.db');
    biometric = FakeBiometricAuth(supported: helloSupported);
    auth = AuthService(
      secureStore: MemorySecureStore(),
      biometricAuth: biometric,
      kdf: PasswordKdf(iterations: kdfIterations),
      resolveDatabasePath: () async => databasePath,
    );
  }

  Future<void> tearDown() async {
    await auth.lock();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Creates and unlocks an empty vault (no accounts).
  Future<DatabaseSession> createUnlockedVault({bool forceUnlock = false}) {
    return auth.createVault(
      password: password,
      databasePath: databasePath,
      forceUnlock: forceUnlock,
    );
  }

  /// Creates vault + primary checking (and optional sample register rows).
  Future<SampleDatasetResult> seed({
    bool withSampleTransactions = true,
    PrimaryCheckingDraft? primary,
  }) async {
    await createUnlockedVault();
    return SampleDataset.seed(
      session: session,
      primary: primary,
      withSampleTransactions: withSampleTransactions,
    );
  }
}

