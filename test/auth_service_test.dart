import 'dart:io';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/biometric_auth.dart';
import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:cash_flow_manager/auth/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;
  late AuthService auth;
  late FakeBiometricAuth biometric;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_auth_');
    dbPath = p.join(tempDir.path, 'vault.cfm.db');
    biometric = FakeBiometricAuth();
    auth = AuthService(
      secureStore: MemorySecureStore(),
      biometricAuth: biometric,
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

  test('create vault then unlock with password', () async {
    expect(await auth.vaultExists(), isFalse);
    await auth.createVault(password: 'password123');
    expect(auth.isUnlocked, isTrue);
    await auth.lock();
    expect(auth.isUnlocked, isFalse);

    await auth.unlockWithPassword(password: 'password123');
    expect(auth.isUnlocked, isTrue);
  });

  test('createVault creates missing parent folders', () async {
    final nestedPath = p.join(tempDir.path, 'new', 'nested', 'vault.cfm.db');
    await auth.createVault(
      password: 'password123',
      databasePath: nestedPath,
    );
    expect(await File(nestedPath).exists(), isTrue);
    expect(await File('$nestedPath.meta.json').exists(), isTrue);
  });

  test('createVault overwrite replaces an existing vault', () async {
    await auth.createVault(password: 'password123');
    await auth.lock();

    await auth.createVault(password: 'replacement1', overwrite: true);
    await auth.lock();

    await expectLater(
      auth.unlockWithPassword(password: 'password123'),
      throwsA(isA<AuthException>()),
    );
    await auth.unlockWithPassword(password: 'replacement1');
    expect(auth.isUnlocked, isTrue);
  });

  test('wrong password fails', () async {
    await auth.createVault(password: 'password123');
    await auth.lock();
    await expectLater(
      auth.unlockWithPassword(password: 'wrong-password'),
      throwsA(isA<AuthException>()),
    );
  });

  test('hello unlock after enable', () async {
    await auth.createVault(password: 'password123');
    await auth.enableHelloUnlock();
    expect(await auth.isHelloEnabled(), isTrue);
    await auth.lock();

    await auth.unlockWithHello();
    expect(auth.isUnlocked, isTrue);
    expect(biometric.authenticateCalls, greaterThanOrEqualTo(2));
  });

  test('hello unlock fails when biometric rejects', () async {
    await auth.createVault(password: 'password123');
    await auth.enableHelloUnlock();
    await auth.lock();
    biometric.succeed = false;

    await expectLater(
      auth.unlockWithHello(),
      throwsA(isA<AuthException>()),
    );
  });
}
