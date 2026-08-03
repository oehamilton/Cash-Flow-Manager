import 'dart:io';

import 'package:cash_flow_manager/auth/recent_vault_store.dart';
import 'package:cash_flow_manager/auth/vault_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_recent_vaults_');
    VaultPaths.debugAppDataRootOverride = () => tempDir.path;
  });

  tearDown(() async {
    VaultPaths.debugAppDataRootOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('record bumps and preserves custom label', () async {
    final personal = p.join(tempDir.path, 'Personal', 'vault.cfm.db');
    final business = p.join(tempDir.path, 'Business', 'vault.cfm.db');

    await RecentVaultStore.record(
      personal,
      asOf: DateTime.utc(2026, 8, 1),
    );
    await RecentVaultStore.record(
      business,
      asOf: DateTime.utc(2026, 8, 2),
    );
    await RecentVaultStore.rename(personal, 'Home books');
    await RecentVaultStore.record(
      personal,
      asOf: DateTime.utc(2026, 8, 3),
    );

    final list = await RecentVaultStore.list();
    expect(list, hasLength(2));
    expect(list.first.path, p.normalize(personal));
    expect(list.first.label, 'Home books');
    expect(list.last.label, 'Business');
  });

  test('remove drops list entry only', () async {
    final path = p.join(tempDir.path, 'Business', 'vault.cfm.db');
    await RecentVaultStore.record(path);
    await RecentVaultStore.remove(path);
    expect(await RecentVaultStore.list(), isEmpty);
  });

  test('defaultLabelForPath uses parent folder name', () {
    expect(
      RecentVaultStore.defaultLabelForPath(
        p.join(r'C:\Users\a\Documents\CashFlowManager', 'Business', 'vault.cfm.db'),
      ),
      'Business',
    );
  });
}
