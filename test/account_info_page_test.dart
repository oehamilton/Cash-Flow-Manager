import 'package:cash_flow_manager/auth/auth_service.dart';
import 'package:cash_flow_manager/auth/biometric_auth.dart';
import 'package:cash_flow_manager/auth/password_kdf.dart';
import 'package:cash_flow_manager/auth/secure_store.dart';
import 'package:cash_flow_manager/features/accounts/account_info_page.dart';
import 'package:cash_flow_manager/features/accounts/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Accounts copy mentions tapping for details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountsPage(auth: null)),
    );
    expect(find.byKey(const Key('accounts_empty')), findsOneWidget);
    expect(find.textContaining('Tap an account'), findsOneWidget);
  });

  testWidgets('AccountInfoPage shows locked state without session', (
    tester,
  ) async {
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      biometricAuth: FakeBiometricAuth(supported: false),
      kdf: PasswordKdf(iterations: 1000),
      resolveDatabasePath: () async => 'unused.cfm.db',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountInfoPage(
          auth: auth,
          accountId: 'missing',
          onClose: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('page_account_info')), findsOneWidget);
    expect(find.byKey(const Key('account_info_back')), findsOneWidget);
    expect(find.text('Vault is locked'), findsOneWidget);
  });
}
