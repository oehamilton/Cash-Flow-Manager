import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'database_exceptions.dart';

/// Exclusive single-writer lock beside the database file.
///
/// Lock path: `<dbPath>.cfm.lock`
class AppLockFile {
  AppLockFile(this.databasePath, {String? instanceId, DateTime Function()? clock})
      : instanceId = instanceId ?? const Uuid().v4(),
        _clock = clock ?? DateTime.now;

  final String databasePath;
  final String instanceId;
  final DateTime Function() _clock;

  File? _heldFile;
  RandomAccessFile? _raf;

  String get lockPath => '$databasePath.cfm.lock';

  /// Acquire exclusive lock. Throws [DatabaseLockedException] if held elsewhere.
  ///
  /// When [force] is true, an existing lock file is removed first (dangerous).
  Future<void> acquire({
    bool force = false,
    Duration staleAfter = const Duration(hours: 24),
  }) async {
    if (_raf != null) {
      return;
    }

    final file = File(lockPath);
    await file.parent.create(recursive: true);

    if (await file.exists()) {
      await _clearExistingLock(
        file,
        force: force,
        staleAfter: staleAfter,
      );
    }

    final raf = await file.open(mode: FileMode.write);
    try {
      raf.lockSync(FileLock.exclusive);
    } on FileSystemException {
      await raf.close();
      throw DatabaseLockedException(
        'Could not obtain exclusive lock on $lockPath',
        lockPath: lockPath,
      );
    }

    final payload = LockPayload(
      instanceId: instanceId,
      pid: pid,
      machineName: Platform.localHostname,
      databasePath: p.normalize(databasePath),
      acquiredAt: _clock().toUtc(),
    );
    raf.setPositionSync(0);
    raf.truncateSync(0);
    raf.writeStringSync('${jsonEncode(payload.toJson())}\n');
    raf.flushSync();

    _heldFile = file;
    _raf = raf;
  }

  Future<void> _clearExistingLock(
    File file, {
    required bool force,
    required Duration staleAfter,
  }) async {
    if (force) {
      await _deleteLockFile(file, lockedMessage: 'Force unlock could not remove $lockPath');
      return;
    }

    final existing = await _readLock(file);
    if (existing == null) {
      // Unreadable / empty while present — treat as held if delete fails.
      await _deleteLockFile(
        file,
        lockedMessage:
            'Database lock exists and could not be cleared ($lockPath).',
      );
      return;
    }

    final age = _clock().toUtc().difference(existing.acquiredAt);
    final staleByAge = age > staleAfter;
    final staleByPid = existing.isSameMachine &&
        !await _pidLooksAlive(existing.pid);

    if (!staleByAge && !staleByPid) {
      throw DatabaseLockedException(
        'Database is already open on ${existing.machineName} '
        '(pid ${existing.pid}). Close the other app or use force unlock.',
        lockPath: lockPath,
      );
    }

    await _deleteLockFile(
      file,
      lockedMessage:
          'Stale lock could not be removed because it is still in use ($lockPath).',
    );
  }

  Future<void> _deleteLockFile(
    File file, {
    required String lockedMessage,
  }) async {
    try {
      await file.delete();
    } on PathAccessException {
      throw DatabaseLockedException(lockedMessage, lockPath: lockPath);
    } on FileSystemException catch (e) {
      // errno 32 sharing violation on Windows
      if (e.osError?.errorCode == 32) {
        throw DatabaseLockedException(lockedMessage, lockPath: lockPath);
      }
      rethrow;
    }
  }

  Future<void> release() async {
    final raf = _raf;
    final file = _heldFile;
    _raf = null;
    _heldFile = null;

    if (raf != null) {
      try {
        raf.unlockSync();
      } on FileSystemException {
        // Best effort.
      }
      await raf.close();
    }
    if (file != null && await file.exists()) {
      try {
        final payload = await _readLock(file);
        if (payload == null || payload.instanceId == instanceId) {
          await file.delete();
        }
      } on FileSystemException {
        // Best effort.
      }
    }
  }

  static Future<LockPayload?> _readLock(File file) async {
    try {
      final text = (await file.readAsString()).trim();
      if (text.isEmpty) {
        return null;
      }
      return LockPayload.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Returns true if the PID appears to be running, or if we cannot tell.
  static Future<bool> _pidLooksAlive(int processId) async {
    if (!Platform.isWindows) {
      return true;
    }
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'PID eq $processId',
        '/NH',
      ]);
      final out = (result.stdout as String).toLowerCase();
      if (out.contains('no tasks') || out.trim().isEmpty) {
        return false;
      }
      return RegExp('\\b$processId\\b').hasMatch(out);
    } on Object {
      return true;
    }
  }
}

class LockPayload {
  LockPayload({
    required this.instanceId,
    required this.pid,
    required this.machineName,
    required this.databasePath,
    required this.acquiredAt,
  });

  final String instanceId;
  final int pid;
  final String machineName;
  final String databasePath;
  final DateTime acquiredAt;

  bool get isSameMachine =>
      machineName.toLowerCase() == Platform.localHostname.toLowerCase();

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'pid': pid,
        'machineName': machineName,
        'databasePath': databasePath,
        'acquiredAt': acquiredAt.toIso8601String(),
      };

  factory LockPayload.fromJson(Map<String, dynamic> json) {
    return LockPayload(
      instanceId: json['instanceId'] as String,
      pid: json['pid'] as int,
      machineName: json['machineName'] as String? ?? '',
      databasePath: json['databasePath'] as String? ?? '',
      acquiredAt: DateTime.parse(json['acquiredAt'] as String),
    );
  }
}
