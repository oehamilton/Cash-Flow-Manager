import 'dart:io';

/// Opens [uri] with the OS default handler (browser, mail client, etc.).
///
/// On Windows uses `cmd /c start`. Other platforms use `Process.start` with
/// the URI when a suitable launcher is available.
Future<void> openExternalUri(String uri) async {
  if (Platform.isWindows) {
    await Process.start('cmd', ['/c', 'start', '', uri]);
    return;
  }
  if (Platform.isLinux) {
    await Process.start('xdg-open', [uri]);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', [uri]);
    return;
  }
  throw UnsupportedError('openExternalUri is not supported on this platform');
}

typedef OpenExternal = Future<void> Function(String uri);
