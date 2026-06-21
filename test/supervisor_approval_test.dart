// Hermetic widget test for the supervisor step-up approval dialog (the
// supervisor-only flow): a supervisor approves, a non-supervisor is rejected,
// and a bad credential shows an error. Uses a fake HTTP transport (no network).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elkasir_pos/services/api/api_client.dart';
import 'package:elkasir_pos/services/api/api_providers.dart';
import 'package:elkasir_pos/services/api/token_store.dart';
import 'package:elkasir_pos/shared/widgets/supervisor_approval_dialog.dart';

http.Response _resp(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: const {
      'content-type': 'application/json',
    });

// A successful POST /auth/staff/login carrying a staff user of the given role.
http.Response _staffLogin(String role, String name) => _resp({
  'success': true,
  'message': 'ok',
  'data': {
    'user': {
      'id': 's1',
      'name': name,
      'role': role,
      'storeId': 'st',
      'actor': 'staff',
    },
    'accessToken': 'a',
    'refreshToken': 'r',
    'expiresIn': 900,
  },
}, 200);

class _Holder {
  String? result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<_Holder> openAndApprove(
    WidgetTester tester,
    MockClient mock, {
    required String user,
    required String pass,
  }) async {
    final holder = _Holder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              baseUrl: 'http://test/api/v1',
              tokens: TokenStore(),
              client: mock,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  holder.result = await showSupervisorApprovalDialog(
                    context,
                    title: 'Persetujuan Supervisor',
                    message: 'Butuh persetujuan.',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), user);
    await tester.enterText(find.byType(TextField).at(1), pass);
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    return holder;
  }

  testWidgets('supervisor credential is approved and returns the name', (
    tester,
  ) async {
    final mock = MockClient((_) async => _staffLogin('supervisor', 'Siti'));
    final h = await openAndApprove(tester, mock, user: 'siti', pass: 'super123');
    expect(h.result, 'Siti', reason: 'approval returns the supervisor name');
    expect(find.byType(AlertDialog), findsNothing, reason: 'dialog closes');
  });

  testWidgets('non-supervisor staff is rejected', (tester) async {
    final mock = MockClient((_) async => _staffLogin('cashier', 'Budi'));
    final h = await openAndApprove(tester, mock, user: 'budi', pass: 'kasir123');
    expect(h.result, isNull, reason: 'cashier cannot approve');
    expect(find.text('Akun ini bukan supervisor.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'dialog stays open');
  });

  testWidgets('invalid credential shows an error', (tester) async {
    final mock = MockClient(
      (_) async => _resp({
        'success': false,
        'message': 'Username atau password salah',
        'errors': [
          {'code': 'unauthorized'},
        ],
      }, 401),
    );
    final h = await openAndApprove(tester, mock, user: 'x', pass: 'y');
    expect(h.result, isNull);
    expect(find.text('Kredensial tidak valid.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
