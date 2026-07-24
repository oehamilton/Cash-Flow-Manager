import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Non-secret vault metadata stored beside the database file.
class VaultMeta {
  VaultMeta({
    required this.salt,
    required this.helloEnabled,
    required this.createdAt,
  });

  final Uint8List salt;
  final bool helloEnabled;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'helloEnabled': helloEnabled,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory VaultMeta.fromJson(Map<String, dynamic> json) {
    return VaultMeta(
      salt: Uint8List.fromList(base64Decode(json['salt'] as String)),
      helloEnabled: json['helloEnabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  VaultMeta copyWith({bool? helloEnabled}) {
    return VaultMeta(
      salt: salt,
      helloEnabled: helloEnabled ?? this.helloEnabled,
      createdAt: createdAt,
    );
  }

  static String pathForDatabase(String databasePath) => '$databasePath.meta.json';

  static Future<VaultMeta?> load(String databasePath) async {
    final file = File(pathForDatabase(databasePath));
    if (!await file.exists()) {
      return null;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return VaultMeta.fromJson(json);
  }

  Future<void> save(String databasePath) async {
    final file = File(pathForDatabase(databasePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));
  }
}
