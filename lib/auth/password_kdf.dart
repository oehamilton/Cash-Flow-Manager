import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Derives the database passphrase from the app password.
class PasswordKdf {
  PasswordKdf({
    this.iterations = 120000,
    Random? random,
  }) : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;

  static const int saltLength = 16;

  Uint8List generateSalt() {
    final bytes = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Future<String> derivePassphrase({
    required String password,
    required List<int> salt,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return base64UrlEncode(bytes);
  }
}
