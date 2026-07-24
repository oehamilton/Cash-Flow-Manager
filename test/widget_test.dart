import 'package:cash_flow_manager/app_shell/app_shell.dart';
import 'package:cash_flow_manager/core/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shell opens on Register with brand and version', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          helloAvailable: true,
          onLock: () async {},
          onToggleHello: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('app_nav_rail')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_brand')), findsOneWidget);
    expect(find.text(AppInfo.versionLabel), findsOneWidget);
    expect(find.byKey(const Key('page_register')), findsOneWidget);
    expect(find.byKey(const Key('register_empty')), findsOneWidget);
  });

  testWidgets('Navigating to Accounts shows accounts page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppShell()),
    );

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page_accounts')), findsOneWidget);
    expect(find.byKey(const Key('accounts_add_button')), findsOneWidget);
  });

  testWidgets('Settings shows lock control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          helloAvailable: true,
          helloEnabled: false,
          onLock: () async {},
          onToggleHello: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page_settings')), findsOneWidget);
    expect(find.byKey(const Key('lock_button')), findsOneWidget);
    expect(find.byKey(const Key('hello_toggle')), findsOneWidget);
  });
}
