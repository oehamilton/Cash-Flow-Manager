import 'dart:io';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/biometric_auth.dart';
import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:cash_flow_manager/auth/secure_store.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:cash_flow_manager/features/wizard/setup_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;
  late AuthService auth;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_setup_');
    dbPath = p.join(tempDir.path, 'vault.cfm.db');
    auth = AuthService(
      secureStore: MemorySecureStore(),
      biometricAuth: FakeBiometricAuth(supported: false),
      kdf: PasswordKdf(iterations: 1000),
      resolveDatabasePath: () async => dbPath,
    );
  });

  tearDown(() async {
    await auth.lock();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('completeFreshSetup creates vault and primary account', () async {
    final coordinator = SetupCoordinator(auth);
    await coordinator.completeFreshSetup(
      databasePath: dbPath,
      password: 'password123',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.create,
      primary: PrimaryCheckingDraft(
        name: 'Household Checking',
        openingBalanceCents: 10000,
        openingDate: DateTime(2026, 7, 23),
      ),
    );

    expect(auth.isUnlocked, isTrue);
    expect(AccountRepository(auth.session!).hasPrimaryAccount(), isTrue);
    expect(await File(dbPath).exists(), isTrue);
  });

  test('completeFreshSetup creates nested folders for custom path', () async {
    final nestedPath =
        p.join(tempDir.path, 'custom', 'place', 'vault.cfm.db');
    final coordinator = SetupCoordinator(auth);
    await coordinator.completeFreshSetup(
      databasePath: nestedPath,
      password: 'password123',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.create,
      primary: PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 0,
        openingDate: DateTime(2026, 7, 23),
      ),
    );

    expect(await File(nestedPath).exists(), isTrue);
    expect(auth.isUnlocked, isTrue);
  });

  test('open existing vault unlocks without recreating', () async {
    final coordinator = SetupCoordinator(auth);
    await coordinator.completeFreshSetup(
      databasePath: dbPath,
      password: 'password123',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.create,
      primary: PrimaryCheckingDraft(
        name: 'Checking',
        openingBalanceCents: 500,
        openingDate: DateTime(2026, 7, 23),
      ),
    );
    await auth.lock();

    await coordinator.completeFreshSetup(
      databasePath: dbPath,
      password: 'password123',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.open,
    );

    expect(auth.isUnlocked, isTrue);
    expect(AccountRepository(auth.session!).hasPrimaryAccount(), isTrue);
  });

  test('overwrite replaces existing vault', () async {
    final coordinator = SetupCoordinator(auth);
    await coordinator.completeFreshSetup(
      databasePath: dbPath,
      password: 'old-password',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.create,
      primary: PrimaryCheckingDraft(
        name: 'Old Checking',
        openingBalanceCents: 1,
        openingDate: DateTime(2026, 1, 1),
      ),
    );
    await auth.lock();

    await coordinator.completeFreshSetup(
      databasePath: dbPath,
      password: 'new-password',
      enableHello: false,
      forceUnlock: false,
      action: VaultSetupAction.overwrite,
      primary: PrimaryCheckingDraft(
        name: 'New Checking',
        openingBalanceCents: 9999,
        openingDate: DateTime(2026, 7, 23),
      ),
    );

    expect(auth.isUnlocked, isTrue);
    final rows = auth.session!.database.select(
      'SELECT name, opening_balance_cents FROM accounts WHERE is_primary = 1',
    );
    expect(rows.single['name'], 'New Checking');
    expect(rows.single['opening_balance_cents'], 9999);

    await auth.lock();
    await expectLater(
      auth.unlockWithPassword(password: 'old-password'),
      throwsA(isA<AuthException>()),
    );
    await auth.unlockWithPassword(password: 'new-password');
    expect(auth.isUnlocked, isTrue);
  });
}
