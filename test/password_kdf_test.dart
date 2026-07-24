import 'dart:convert';

import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derivePassphrase is deterministic for same password and salt', () async {
    final kdf = PasswordKdf(iterations: 1000);
    final salt = utf8.encode('fixed-salt-16b!');
    final a = await kdf.derivePassphrase(password: 'secret-pass', salt: salt);
    final b = await kdf.derivePassphrase(password: 'secret-pass', salt: salt);
    expect(a, b);
    expect(a, isNot(equals(await kdf.derivePassphrase(password: 'other', salt: salt))));
  });

  test('generateSalt returns expected length', () {
    final salt = PasswordKdf().generateSalt();
    expect(salt.length, PasswordKdf.saltLength);
  });
}
