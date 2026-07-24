import 'dart:io';

import '../data/database_exceptions.dart';
import '../data/database_session.dart';
import 'biometric_auth.dart';
import 'password_kdf.dart';
import 'secure_store.dart';
import 'vault_files.dart';
import 'vault_meta.dart';
import 'vault_paths.dart';

/// Creates and unlocks the encrypted vault with password and optional Hello.
class AuthService {
  AuthService({
    SecureStore? secureStore,
    BiometricAuth? biometricAuth,
    PasswordKdf? kdf,
    Future<String> Function()? resolveDatabasePath,
  })  : _secureStore = secureStore ?? createPlatformSecureStore(),
        _biometric = biometricAuth ?? LocalBiometricAuth(),
        _kdf = kdf ?? PasswordKdf(),
        _resolveDatabasePath =
            resolveDatabasePath ?? VaultPaths.activeDatabasePath;

  static const _helloPassphraseKey = 'cfm_hello_db_passphrase';

  final SecureStore _secureStore;
  final BiometricAuth _biometric;
  final PasswordKdf _kdf;
  final Future<String> Function() _resolveDatabasePath;

  DatabaseSession? _session;
  String? _sessionPassphrase;

  DatabaseSession? get session => _session;
  bool get isUnlocked => _session != null;

  Future<String> databasePath() => _resolveDatabasePath();

  Future<bool> vaultExists() async {
    final path = await databasePath();
    return vaultExistsAt(path);
  }

  Future<bool> vaultExistsAt(String path) => VaultFiles.isComplete(path);

  Future<VaultPresence> vaultPresenceAt(String path) =>
      VaultFiles.presence(path);

  Future<bool> isHelloEnabled() async {
    final path = await databasePath();
    final meta = await VaultMeta.load(path);
    return meta?.helloEnabled ?? false;
  }

  Future<bool> isHelloAvailable() async {
    final supported = await _biometric.isDeviceSupported();
    final canCheck = await _biometric.canCheckBiometrics();
    return supported || canCheck;
  }

  /// First-time vault creation (full account wizard is Phase 0.5).
  ///
  /// When [databasePath] is provided, that file is used (parent folders are
  /// created). Otherwise the active path from [VaultPaths] is used.
  ///
  /// When [overwrite] is true, an existing vault at the path is deleted first.
  Future<DatabaseSession> createVault({
    required String password,
    String? databasePath,
    bool enableHello = false,
    bool forceUnlock = false,
    bool overwrite = false,
  }) async {
    if (password.length < 8) {
      throw AuthException('Password must be at least 8 characters');
    }

    final path = databasePath ?? await this.databasePath();
    await VaultPaths.ensureParentDirectory(path);

    final presence = await VaultFiles.presence(path);
    if (presence != VaultPresence.none) {
      if (!overwrite) {
        throw AuthException(
          'A vault already exists at this path. Open it or choose overwrite.',
        );
      }
      await VaultFiles.deleteVault(path);
    }

    final salt = _kdf.generateSalt();
    final passphrase = await _kdf.derivePassphrase(
      password: password,
      salt: salt,
    );

    final meta = VaultMeta(
      salt: salt,
      helloEnabled: false,
      createdAt: DateTime.now().toUtc(),
    );
    await meta.save(path);

    final session = await DatabaseSession.open(
      databasePath: path,
      passphrase: passphrase,
      forceUnlock: forceUnlock,
    );
    _session = session;
    _sessionPassphrase = passphrase;

    if (enableHello) {
      await enableHelloUnlock();
    }

    return session;
  }

  Future<DatabaseSession> unlockWithPassword({
    required String password,
    String? databasePath,
    bool forceUnlock = false,
  }) async {
    final path = databasePath ?? await this.databasePath();
    final meta = await VaultMeta.load(path);
    if (meta == null || !await File(path).exists()) {
      throw AuthException('No vault found. Create a password to get started.');
    }

    final passphrase = await _kdf.derivePassphrase(
      password: password,
      salt: meta.salt,
    );

    try {
      final session = await DatabaseSession.open(
        databasePath: path,
        passphrase: passphrase,
        forceUnlock: forceUnlock,
      );
      _session = session;
      _sessionPassphrase = passphrase;
      return session;
    } on DatabaseKeyException {
      throw AuthException('Incorrect password');
    }
  }

  Future<DatabaseSession> unlockWithHello({bool forceUnlock = false}) async {
    if (!await isHelloEnabled()) {
      throw AuthException('Windows Hello is not enabled for this vault');
    }

    final ok = await _biometric.authenticate(
      reason: 'Unlock Cash Flow Manager',
    );
    if (!ok) {
      throw AuthException('Windows Hello authentication failed');
    }

    final passphrase = await _secureStore.read(_helloPassphraseKey);
    if (passphrase == null || passphrase.isEmpty) {
      throw AuthException(
        'Hello unlock data missing. Unlock with your password and re-enable Hello.',
      );
    }

    try {
      final path = await databasePath();
      final session = await DatabaseSession.open(
        databasePath: path,
        passphrase: passphrase,
        forceUnlock: forceUnlock,
      );
      _session = session;
      _sessionPassphrase = passphrase;
      return session;
    } on DatabaseKeyException {
      throw AuthException(
        'Stored Hello credentials are invalid. Unlock with password and re-enable Hello.',
      );
    }
  }

  /// Call after a successful password unlock (or during create).
  Future<void> enableHelloUnlock() async {
    final passphrase = _sessionPassphrase;
    if (passphrase == null || _session == null) {
      throw AuthException('Unlock with your password before enabling Hello');
    }
    if (!await isHelloAvailable()) {
      throw AuthException('Windows Hello is not available on this device');
    }

    final ok = await _biometric.authenticate(
      reason: 'Enable Windows Hello unlock for Cash Flow Manager',
    );
    if (!ok) {
      throw AuthException('Windows Hello authentication failed');
    }

    await _secureStore.write(_helloPassphraseKey, passphrase);
    final path = await databasePath();
    final meta = await VaultMeta.load(path);
    if (meta == null) {
      throw AuthException('Vault metadata missing');
    }
    await meta.copyWith(helloEnabled: true).save(path);
  }

  Future<void> disableHelloUnlock() async {
    await _secureStore.delete(_helloPassphraseKey);
    final path = await databasePath();
    final meta = await VaultMeta.load(path);
    if (meta != null) {
      await meta.copyWith(helloEnabled: false).save(path);
    }
  }

  Future<void> lock() async {
    final session = _session;
    _session = null;
    _sessionPassphrase = null;
    if (session != null) {
      await session.close();
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
