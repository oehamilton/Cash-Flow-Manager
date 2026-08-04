/// Application identity shown in UI and About.
///
/// Keep [version] aligned with the `version:` field in `pubspec.yaml`
/// (the part before `+`).
class AppInfo {
  const AppInfo._();

  static const String name = 'Cash Flow Manager';
  static const String version = '6.4.2';
  static const String buildNumber = '1';

  static String get versionLabel => 'v$version';

  /// Short product description for About.
  static const String productLine =
      'A local-first Windows cash flow and bank register app from Project8X.';

  static const String companyName = 'Project8X';
  static const String companyBlurb =
      'Comprehensive technology solutions designed to optimize your contact '
      'center operations, enhance customer experiences, and drive business '
      'growth through innovative technology implementations.';

  static const String supportEmail = 'support@project8x.com';
  static const String websiteUrl = 'https://www.project8x.com/';
  static const String contactUrl = 'https://www.project8x.com/ContactUs';

  static String get supportMailto => 'mailto:$supportEmail';
}
