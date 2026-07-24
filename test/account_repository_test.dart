import 'dart:io';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/biometric_auth.dart';
import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:cash_flow_manager/auth/secure_store.dart';
import 'package:cash_flow_manager/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;
  late AuthService auth;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_acct_');
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

  test('createPrimaryChecking inserts account and opening balance tx', () async {
    await auth.createVault(password: 'password123');
    final repo = AccountRepository(auth.session!);
    expect(repo.hasPrimaryAccount(), isFalse);

    final id = repo.createPrimaryChecking(
      PrimaryCheckingDraft(
        name: 'Main Checking',
        institution: 'Test Bank',
        openingBalanceCents: 25000,
        openingDate: DateTime(2026, 7, 1),
      ),
    );

    expect(repo.hasPrimaryAccount(), isTrue);
    expect(repo.primaryAccountId(), id);

    final accounts = auth.session!.database.select(
      'SELECT name, type, is_primary, opening_balance_cents FROM accounts',
    );
    expect(accounts, hasLength(1));
    expect(accounts.first['name'], 'Main Checking');
    expect(accounts.first['type'], 'checking');
    expect(accounts.first['is_primary'], 1);
    expect(accounts.first['opening_balance_cents'], 25000);

    final txs = auth.session!.database.select(
      'SELECT payee, amount_cents, source, is_cleared FROM transactions',
    );
    expect(txs, hasLength(1));
    expect(txs.first['payee'], 'Opening Balance');
    expect(txs.first['amount_cents'], 25000);
    expect(txs.first['source'], 'opening_balance');
    expect(txs.first['is_cleared'], 1);
  });
}
