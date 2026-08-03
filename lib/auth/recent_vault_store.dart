import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'vault_paths.dart';

/// One recently used vault for unlock/settings quick switching.
class RecentVaultEntry {
  const RecentVaultEntry({
    required this.path,
    required this.label,
    required this.lastOpenedAt,
  });

  final String path;
  final String label;
  final DateTime lastOpenedAt;

  Map<String, Object?> toJson() => {
        'path': path,
        'label': label,
        'lastOpenedAt': lastOpenedAt.toUtc().toIso8601String(),
      };

  static RecentVaultEntry fromJson(Map<String, Object?> json) {
    final path = json['path'] as String? ?? '';
    final label = (json['label'] as String?)?.trim();
    final rawAt = json['lastOpenedAt'] as String?;
    return RecentVaultEntry(
      path: p.normalize(path),
      label: (label == null || label.isEmpty)
          ? RecentVaultStore.defaultLabelForPath(path)
          : label,
      lastOpenedAt: rawAt == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(rawAt).toUtc(),
    );
  }
}

/// Persists a short list of recent vaults outside the encrypted DB.
class RecentVaultStore {
  static const maxEntries = 12;
  static const fileName = 'recent_vaults.json';

  static Future<File> _file() async {
    final root = VaultPaths.appDataRoot();
    final dir = Directory(p.join(root, VaultPaths.appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, fileName));
  }

  static Future<List<RecentVaultEntry>> list() async {
    final file = await _file();
    if (!await file.exists()) {
      return const [];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return const [];
      }
      final entries = <RecentVaultEntry>[];
      for (final item in decoded) {
        if (item is Map) {
          final entry = RecentVaultEntry.fromJson(
            Map<String, Object?>.from(item),
          );
          if (entry.path.isNotEmpty) {
            entries.add(entry);
          }
        }
      }
      entries.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
      return entries;
    } on Object {
      return const [];
    }
  }

  /// Adds or bumps [databasePath] to the top of the recent list.
  static Future<void> record(
    String databasePath, {
    String? label,
    DateTime? asOf,
  }) async {
    final normalized = p.normalize(databasePath);
    if (normalized.isEmpty) {
      return;
    }
    final now = (asOf ?? DateTime.now()).toUtc();
    final existing = await list();
    RecentVaultEntry? previous;
    for (final entry in existing) {
      if (entry.path == normalized) {
        previous = entry;
        break;
      }
    }
    final nextLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : previous?.label ?? defaultLabelForPath(normalized);

    final next = <RecentVaultEntry>[
      RecentVaultEntry(
        path: normalized,
        label: nextLabel,
        lastOpenedAt: now,
      ),
      for (final entry in existing)
        if (entry.path != normalized) entry,
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    await _write(next);
  }

  static Future<void> rename(String databasePath, String label) async {
    final normalized = p.normalize(databasePath);
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Label is required');
    }
    final existing = await list();
    final next = <RecentVaultEntry>[];
    var found = false;
    for (final entry in existing) {
      if (entry.path == normalized) {
        found = true;
        next.add(
          RecentVaultEntry(
            path: entry.path,
            label: trimmed,
            lastOpenedAt: entry.lastOpenedAt,
          ),
        );
      } else {
        next.add(entry);
      }
    }
    if (!found) {
      next.insert(
        0,
        RecentVaultEntry(
          path: normalized,
          label: trimmed,
          lastOpenedAt: DateTime.now().toUtc(),
        ),
      );
    }
    await _write(next);
  }

  /// Removes from the recent list only — does not delete vault files.
  static Future<void> remove(String databasePath) async {
    final normalized = p.normalize(databasePath);
    final existing = await list();
    await _write([
      for (final entry in existing)
        if (entry.path != normalized) entry,
    ]);
  }

  static String defaultLabelForPath(String databasePath) {
    final parent = p.basename(p.dirname(p.normalize(databasePath)));
    if (parent.isNotEmpty &&
        parent != '.' &&
        parent != VaultPaths.appFolderName &&
        parent != VaultPaths.restoredFolderName) {
      return parent;
    }
    final base = p.basenameWithoutExtension(databasePath);
    if (base.isEmpty) {
      return 'Vault';
    }
    return base;
  }

  static Future<void> _write(List<RecentVaultEntry> entries) async {
    final file = await _file();
    final payload = jsonEncode([
      for (final entry in entries) entry.toJson(),
    ]);
    await file.writeAsString('$payload\n');
  }
}
