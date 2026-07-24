import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the default encrypted vault location.
class VaultPaths {
  static const String defaultFileName = 'vault.cfm.db';
  static const String appFolderName = 'CashFlowManager';

  /// `%AppData%/CashFlowManager/vault.cfm.db` on Windows.
  static Future<String> defaultDatabasePath() async {
    final root = _appDataRoot();
    final dir = Directory(p.join(root, appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, defaultFileName);
  }

  static String _appDataRoot() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return appData;
      }
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, '.local', 'share');
  }
}
