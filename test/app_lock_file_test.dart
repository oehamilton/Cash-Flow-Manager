import 'dart:io';

import 'package:cash_flow_manager/data/app_lock_file.dart';
import 'package:cash_flow_manager/data/database_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cfm_lock_');
    dbPath = p.join(tempDir.path, 'test.cfm.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('second acquire fails while first holds lock', () async {
    final first = AppLockFile(dbPath, instanceId: 'a');
    final second = AppLockFile(dbPath, instanceId: 'b');

    await first.acquire();
    addTearDown(first.release);
    expect(File(first.lockPath).existsSync(), isTrue);

    await expectLater(second.acquire(), throwsA(isA<DatabaseLockedException>()));

    await first.release();
    await second.acquire();
    await second.release();
  });

  test('force unlock replaces a leftover lock file', () async {
    final lockPath = '$dbPath.cfm.lock';
    await File(lockPath).writeAsString(
      '{"instanceId":"dead","pid":1,"machineName":"other-pc",'
      '"databasePath":"$dbPath","acquiredAt":"2099-01-01T00:00:00.000Z"}\n',
    );

    final locker = AppLockFile(dbPath, instanceId: 'fresh');
    await locker.acquire(force: true);
    await locker.release();
    expect(File(lockPath).existsSync(), isFalse);
  });
}
