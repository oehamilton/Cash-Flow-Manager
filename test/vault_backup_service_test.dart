import 'dart:io';

import 'package:cash_flow_manager/auth/vault_backup_service.dart';
import 'package:cash_flow_manager/auth/vault_files.dart';
import 'package:cash_flow_manager/auth/vault_meta.dart';
import 'package:cash_flow_manager/auth/vault_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_vault.dart';

void main() {
  final harness = TempVaultHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  test('suggestedFileName uses vault-YYYYMMDD.cfm.db', () {
    expect(
      VaultBackupService.suggestedFileName(asOf: DateTime(2026, 7, 24)),
      'vault-20260724.cfm.db',
    );
  });

  test('backupEncryptedVault copies db and meta, skips lock', () async {
    await harness.createUnlockedVault();
    final source = harness.databasePath;
    expect(await VaultFiles.isComplete(source), isTrue);

    final destDir = await Directory.systemTemp.createTemp('cfm_backup_dest_');
    addTearDown(() async {
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
    });
    final dest = p.join(destDir.path, 'copy.cfm.db');

    await VaultBackupService.backupEncryptedVault(
      sourceDatabasePath: source,
      destDatabasePath: dest,
    );

    expect(await File(dest).exists(), isTrue);
    expect(await File(VaultMeta.pathForDatabase(dest)).exists(), isTrue);
    expect(await File('$dest.cfm.lock').exists(), isFalse);
    expect(await VaultFiles.isComplete(dest), isTrue);
    expect(await File(dest).length(), await File(source).length());
  });

  test('restoreEncryptedVault copies into a new Documents-style path', () async {
    await harness.createUnlockedVault();
    final source = harness.databasePath;

    final destRoot = await Directory.systemTemp.createTemp('cfm_restore_docs_');
    addTearDown(() async {
      if (await destRoot.exists()) {
        await destRoot.delete(recursive: true);
      }
    });
    VaultPaths.debugDocumentsRootOverride = () => destRoot.path;
    addTearDown(() => VaultPaths.debugDocumentsRootOverride = null);

    final dest = VaultPaths.suggestedRestoreDatabasePath(
      asOf: DateTime(2026, 8, 3),
    );
    expect(dest, contains('Restored'));
    expect(p.basename(dest), 'vault-restored-20260803.cfm.db');

    final restored = await VaultBackupService.restoreEncryptedVault(
      sourceDatabasePath: source,
      destDatabasePath: dest,
    );
    expect(restored, p.normalize(dest));
    expect(await VaultFiles.isComplete(dest), isTrue);
    // Backup source untouched.
    expect(await VaultFiles.isComplete(source), isTrue);
  });
}
