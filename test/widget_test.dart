import 'package:cash_flow_manager/app.dart';
import 'package:cash_flow_manager/core/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shell opens on Register with brand and version', (tester) async {
    await tester.pumpWidget(const CashFlowApp());

    expect(find.byKey(const Key('app_nav_rail')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_brand')), findsOneWidget);
    expect(find.text(AppInfo.versionLabel), findsOneWidget);
    expect(find.byKey(const Key('page_register')), findsOneWidget);
    expect(find.text('Register'), findsWidgets);
  });

  testWidgets('Navigating to Accounts shows accounts placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const CashFlowApp());

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page_accounts')), findsOneWidget);
    expect(find.textContaining('Phase 1'), findsOneWidget);
  });
}
