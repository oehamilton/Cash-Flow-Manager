import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Thin key/value store for secrets.
abstract class SecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// Windows Credential Manager backed store (no JNI / Java dependency).
class WindowsCredentialStore implements SecureStore {
  WindowsCredentialStore({this.targetPrefix = 'CashFlowManager'});

  final String targetPrefix;

  String _target(String key) => '$targetPrefix/$key';

  @override
  Future<void> write(String key, String value) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsCredentialStore is Windows-only');
    }
    using((arena) {
      final bytes = utf8.encode(value);
      final blob = bytes.toNative(allocator: arena);
      final targetName = arena.pwstr(_target(key));
      final userName = arena.pwstr('CashFlowManager');

      final credential = arena<CREDENTIAL>();
      credential.ref
        ..Type = CRED_TYPE_GENERIC
        ..TargetName = targetName
        ..Persist = CRED_PERSIST_LOCAL_MACHINE
        ..UserName = userName
        ..CredentialBlob = blob
        ..CredentialBlobSize = bytes.length;

      final result = CredWrite(credential, 0);
      if (!result.value) {
        throw WindowsException(result.error.toHRESULT());
      }
    });
  }

  @override
  Future<String?> read(String key) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsCredentialStore is Windows-only');
    }
    return using((arena) {
      final credPointer = arena<Pointer<CREDENTIAL>>();
      final targetName = arena.pcwstr(_target(key));
      final result = CredRead(targetName, CRED_TYPE_GENERIC, credPointer);
      if (!result.value) {
        // ERROR_NOT_FOUND
        if (result.error == ERROR_NOT_FOUND) {
          return null;
        }
        throw WindowsException(result.error.toHRESULT());
      }
      try {
        final cred = credPointer.value.ref;
        final blob = cred.CredentialBlob.asTypedList(cred.CredentialBlobSize);
        return utf8.decode(blob);
      } finally {
        CredFree(credPointer.value);
      }
    });
  }

  @override
  Future<void> delete(String key) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsCredentialStore is Windows-only');
    }
    using((arena) {
      final targetName = arena.pcwstr(_target(key));
      final result = CredDelete(targetName, CRED_TYPE_GENERIC);
      if (!result.value && result.error != ERROR_NOT_FOUND) {
        throw WindowsException(result.error.toHRESULT());
      }
    });
  }
}

/// Default platform store for this app (Windows Credential Manager).
SecureStore createPlatformSecureStore() {
  if (Platform.isWindows) {
    return WindowsCredentialStore();
  }
  return MemorySecureStore();
}

/// In-memory store for unit tests.
class MemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
