import 'package:cash_flow_manager/app_shell/app_destination.dart';
import 'package:cash_flow_manager/app_shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell rail includes Payees destination', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(initialDestination: AppDestination.payees),
      ),
    );
    await tester.pump();

    expect(find.text('Payees'), findsWidgets);
    expect(find.byKey(const Key('page_payees')), findsOneWidget);
    expect(find.byKey(const Key('payees_page_title')), findsOneWidget);
  });
}
