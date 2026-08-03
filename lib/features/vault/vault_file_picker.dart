import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../../auth/vault_paths.dart';

/// Shared file-open picker for an existing Cash Flow Manager vault.
Future<String?> pickExistingVaultPath({String? initialDirectory}) async {
  const typeGroup = XTypeGroup(
    label: 'Cash Flow Manager vault',
    extensions: <String>['cfm.db', 'db'],
  );
  final file = await openFile(
    acceptedTypeGroups: const [typeGroup],
    initialDirectory: initialDirectory,
    confirmButtonText: 'Open vault',
  );
  return file?.path;
}

/// Initial directory hint from the active vault pointer (if any).
Future<String?> activeVaultInitialDirectory() async {
  final path = await VaultPaths.activeDatabasePath();
  final dir = p.dirname(path);
  return dir.isEmpty ? null : dir;
}
