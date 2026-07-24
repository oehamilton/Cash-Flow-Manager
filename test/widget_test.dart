import 'package:cash_flow_manager/app.dart';
import 'package:cash_flow_manager/core/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home page shows app name and version', (tester) async {
    await tester.pumpWidget(const CashFlowApp());

    expect(find.byKey(const Key('app_name')), findsOneWidget);
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.byKey(const Key('app_version')), findsOneWidget);
    expect(find.text(AppInfo.versionLabel), findsOneWidget);
  });
}
