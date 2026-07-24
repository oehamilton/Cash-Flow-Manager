import 'package:cash_flow_manager/core/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppInfo exposes stable name and version label', () {
    expect(AppInfo.name, 'Cash Flow Manager');
    expect(AppInfo.version, isNotEmpty);
    expect(AppInfo.versionLabel, 'v${AppInfo.version}');
  });
}
