import 'dart:io';
import 'dart:typed_data';

import 'package:cash_flow_manager/auth/vault_files.dart';
import 'package:cash_flow_manager/auth/vault_meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_vault_files_');
    dbPath = p.join(tempDir.path, 'vault.cfm.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('presence none/complete/incomplete', () async {
    expect(await VaultFiles.presence(dbPath), VaultPresence.none);

    await File(dbPath).writeAsString('db');
    expect(await VaultFiles.presence(dbPath), VaultPresence.incomplete);

    await VaultMeta(
      salt: Uint8List.fromList(List.filled(16, 1)),
      helloEnabled: false,
      createdAt: DateTime.utc(2026, 7, 23),
    ).save(dbPath);
    expect(await VaultFiles.presence(dbPath), VaultPresence.complete);
  });

  test('deleteVault removes db, meta, and lock', () async {
    await File(dbPath).writeAsString('db');
    await File(VaultMeta.pathForDatabase(dbPath)).writeAsString('{}');
    await File('$dbPath.cfm.lock').writeAsString('lock');

    await VaultFiles.deleteVault(dbPath);

    expect(await File(dbPath).exists(), isFalse);
    expect(await File(VaultMeta.pathForDatabase(dbPath)).exists(), isFalse);
    expect(await File('$dbPath.cfm.lock').exists(), isFalse);
  });
}
