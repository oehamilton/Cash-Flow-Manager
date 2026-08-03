import 'package:path/path.dart' as p;

import 'vault_files.dart';
import 'vault_location_store.dart';

/// Activates a different vault file as the app's current database.
class VaultSwitchService {
  /// Ensures [databasePath] is a complete vault; returns the normalized path.
  static Future<String> ensureComplete(String databasePath) async {
    final normalized = p.normalize(databasePath);
    final presence = await VaultFiles.presence(normalized);
    switch (presence) {
      case VaultPresence.complete:
        return normalized;
      case VaultPresence.none:
        throw VaultSwitchException(
          'No vault found at this path. Choose a .cfm.db that has its '
          '.meta.json beside it.',
        );
      case VaultPresence.incomplete:
        throw VaultSwitchException(
          'Vault is incomplete (missing database or .meta.json). '
          'Restore from a full backup, or create a new vault.',
        );
    }
  }

  /// Validates [databasePath] is a complete vault, then saves it as active.
  ///
  /// Returns the normalized path. Does not lock/unlock sessions — callers
  /// should lock any open session before or after this call.
  static Future<String> activate(String databasePath) async {
    final normalized = await ensureComplete(databasePath);
    await VaultLocationStore.save(normalized);
    return normalized;
  }
}

class VaultSwitchException implements Exception {
  VaultSwitchException(this.message);
  final String message;

  @override
  String toString() => 'VaultSwitchException: $message';
}
