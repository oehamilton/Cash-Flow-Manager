import 'package:cash_flow_manager/core/app_info.dart';
import 'package:cash_flow_manager/features/about/about_dialog.dart';
import 'package:cash_flow_manager/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About dialog shows company, support, and version', (
    tester,
  ) async {
    final opened = <String>[];
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAboutAppDialog(
                context,
                openExternal: (uri) async => opened.add(uri),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_dialog')), findsOneWidget);
    expect(find.byKey(const Key('about_app_name')), findsOneWidget);
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.text(AppInfo.versionLabel), findsOneWidget);
    expect(find.text('A ${AppInfo.companyName} product'), findsOneWidget);
    expect(find.text(AppInfo.supportEmail), findsOneWidget);
    expect(find.byKey(const Key('about_blurb')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('about_open_website')));
    await tester.tap(find.byKey(const Key('about_open_website')));
    await tester.pump();
    expect(opened, contains(AppInfo.websiteUrl));

    await tester.ensureVisible(find.byKey(const Key('about_close')));
    await tester.tap(find.byKey(const Key('about_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about_dialog')), findsNothing);
  });

  testWidgets('Settings shows About entry that opens dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            helloEnabled: false,
            helloAvailable: true,
            lockTimeoutMinutes: 15,
            onLock: () async {},
            onToggleHello: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('settings_about_preview')), findsOneWidget);
    expect(find.byKey(const Key('settings_about_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_about_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_dialog')), findsOneWidget);
    expect(find.text(AppInfo.supportEmail), findsWidgets);
  });
}
