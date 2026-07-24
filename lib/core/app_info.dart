/// Application identity shown in UI and About.
///
/// Keep [version] aligned with the `version:` field in `pubspec.yaml`
/// (the part before `+`).
class AppInfo {
  const AppInfo._();

  static const String name = 'Cash Flow Manager';
  static const String version = '1.1.0';
  static const String buildNumber = '1';

  static String get versionLabel => 'v$version';
}
