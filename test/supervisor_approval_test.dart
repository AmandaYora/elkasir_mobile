// Hermetic widget test for the supervisor approve-in-place PIN dialog:
// a valid PIN returns the supervisor name and closes the dialog; a wrong PIN
// shows an error and keeps it open. Uses a fake HTTP transport (no network).
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

// A successful POST /pos/approvals/verify-pin returning the matched supervisor.
http.Response _verifyOk(String name) => _resp({
  'success': true,
  'message': 'ok',
  'data': {'approvedById': 's1', 'approvedByName': name},
}, 200);

class _Holder {
  SupervisorApproval? result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<_Holder> openAndApprove(
    WidgetTester tester,
    MockClient mock, {
    required String pin,
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
    await tester.enterText(find.byType(TextField).first, pin);
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    return holder;
  }

  testWidgets('valid PIN is approved and returns the supervisor name', (
    tester,
  ) async {
    final mock = MockClient((_) async => _verifyOk('Siti'));
    final h = await openAndApprove(tester, mock, pin: '4321');
    expect(h.result?.name, 'Siti', reason: 'approval returns the supervisor name');
    expect(h.result?.pin, '4321',
        reason: 'approval carries the verified PIN for server-side binding');
    expect(find.byType(AlertDialog), findsNothing, reason: 'dialog closes');
  });

  testWidgets('wrong PIN shows an error and keeps the dialog open', (
    tester,
  ) async {
    final mock = MockClient(
      (_) async => _resp({
        'success': false,
        'message': 'PIN supervisor tidak valid.',
        'errors': [
          {'code': 'unauthorized'},
        ],
      }, 401),
    );
    final h = await openAndApprove(tester, mock, pin: '0000');
    expect(h.result, isNull, reason: 'invalid PIN does not approve');
    expect(find.text('PIN supervisor salah.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'dialog stays open');
  });

  testWidgets('a too-short PIN is rejected client-side without a call', (
    tester,
  ) async {
    var called = false;
    final mock = MockClient((_) async {
      called = true;
      return _verifyOk('Siti');
    });
    final h = await openAndApprove(tester, mock, pin: '12');
    expect(called, isFalse, reason: 'no API call for a < 4 digit PIN');
    expect(h.result, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
