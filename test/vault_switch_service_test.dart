import 'dart:io';
import 'dart:typed_data';

import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/vault_location_store.dart';
import 'package:cash_flow_manager/auth/vault_meta.dart';
import 'package:cash_flow_manager/auth/vault_paths.dart';
import 'package:cash_flow_manager/auth/vault_switch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_vault_switch_');
    VaultPaths.debugAppDataRootOverride = () => tempDir.path;
  });

  tearDown(() async {
    VaultPaths.debugAppDataRootOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createCompleteVault(String name) async {
    final dbPath = p.join(tempDir.path, name, 'vault.cfm.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    await File(dbPath).writeAsBytes([1, 2, 3]);
    await VaultMeta(
      salt: Uint8List.fromList(List.filled(16, 7)),
      helloEnabled: false,
      createdAt: DateTime.utc(2026, 8, 3),
    ).save(dbPath);
    return dbPath;
  }

  test('activate saves complete vault as active pointer', () async {
    final path = await createCompleteVault('personal');
    final activated = await VaultSwitchService.activate(path);
    expect(activated, p.normalize(path));
    expect(await VaultLocationStore.load(), p.normalize(path));
    expect(await VaultPaths.activeDatabasePath(), p.normalize(path));
  });

  test('activate rejects missing vault', () async {
    final missing = p.join(tempDir.path, 'missing', 'vault.cfm.db');
    expect(
      () => VaultSwitchService.activate(missing),
      throwsA(isA<VaultSwitchException>()),
    );
  });

  test('activate rejects incomplete vault', () async {
    final dbPath = p.join(tempDir.path, 'broken', 'vault.cfm.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    await File(dbPath).writeAsBytes([1]);
    expect(
      () => VaultSwitchService.activate(dbPath),
      throwsA(isA<VaultSwitchException>()),
    );
  });

  test('helloPassphraseKeyForPath differs by vault path', () {
    final a = helloPassphraseKeyForPath(r'C:\vaults\personal\vault.cfm.db');
    final b = helloPassphraseKeyForPath(r'C:\vaults\business\vault.cfm.db');
    expect(a, isNot(b));
    expect(a, startsWith('cfm_hello_'));
  });

  test('suggestedNewVaultDatabasePath uses Documents folder name', () {
    VaultPaths.debugDocumentsRootOverride = () => r'C:\Docs\CashFlowManager';
    expect(
      VaultPaths.suggestedNewVaultDatabasePath(folderName: 'Business'),
      p.join(r'C:\Docs\CashFlowManager', 'Business', 'vault.cfm.db'),
    );
    expect(
      VaultPaths.sanitizeVaultFolderName(r'Acme/Corp'),
      'Acme_Corp',
    );
  });
}
