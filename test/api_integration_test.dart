// Live integration test for the POS backend layer. Exercises the real
// ApiClient / AuthApi / ProductsApi against a running Elkasir API.
//
// Prerequisites (handled by the test runner harness):
//   - API running at API_BASE_URL (default http://localhost:8081/api/v1)
//   - a staff account STAFF_USER/STAFF_PASS (default kasiruji/kasir123)
//   - at least one active product in the catalog
//
// Run: flutter test test/api_integration_test.dart
//   (override with --dart-define=API_BASE_URL=... etc.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elkasir_pos/models/pos_models.dart';
import 'package:elkasir_pos/services/api/api_client.dart';
import 'package:elkasir_pos/services/api/api_exception.dart';
import 'package:elkasir_pos/services/api/auth_api.dart';
import 'package:elkasir_pos/services/api/cash_movements_api.dart';
import 'package:elkasir_pos/services/api/products_api.dart';
import 'package:elkasir_pos/services/api/shifts_api.dart';
import 'package:elkasir_pos/services/api/token_store.dart';
import 'package:elkasir_pos/services/api/transactions_api.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8081/api/v1',
);
const _user = String.fromEnvironment('STAFF_USER', defaultValue: 'kasiruji');
const _pass = String.fromEnvironment('STAFF_PASS', defaultValue: 'kasir123');
const _supUser = String.fromEnvironment('SUP_USER', defaultValue: 'supuji');
const _supPass = String.fromEnvironment('SUP_PASS', defaultValue: 'super123');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // These hit a real backend, so they are opt-in — the default `flutter test`
  // (no server) stays green. Enable with:
  //   flutter test --dart-define=RUN_LIVE_API_TESTS=true
  const runLive = bool.fromEnvironment('RUN_LIVE_API_TESTS');
  if (!runLive) {
    test(
      'live API integration (skipped)',
      () {},
      skip:
          'Run with --dart-define=RUN_LIVE_API_TESTS=true and the API up (staff + product seeded).',
    );
    return;
  }

  late TokenStore tokens;
  late ApiClient client;
  late AuthApi auth;
  late ProductsApi products;

  setUp(() {
    tokens = TokenStore();
    // flutter_test blocks real network by default; inject a genuinely real
    // HttpClient (built from the default overrides, bypassing the test zone).
    final realHttp = IOClient(_RealHttpOverrides().createHttpClient(null));
    client = ApiClient(baseUrl: _baseUrl, tokens: tokens, client: realHttp);
    auth = AuthApi(client, tokens);
    products = ProductsApi(client);
  });

  test('staff login returns a staff session and persists tokens', () async {
    final session = await auth.staffLogin(_user, _pass);
    expect(session.actor, 'staff');
    expect(session.role, anyOf('cashier', 'supervisor'));
    expect(session.name, isNotEmpty);
    expect(tokens.access, isNotNull);
    expect(tokens.refresh, isNotNull);
    expect(tokens.hasSession, isTrue);
  });

  test('wrong password is rejected with an ApiException (401)', () async {
    await expectLater(
      () => auth.staffLogin(_user, 'salah-password'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('products load from the live catalog after login', () async {
    await auth.staffLogin(_user, _pass);
    final list = await products.list();
    expect(list, isNotEmpty);
    expect(list.first.name, isNotEmpty);
    expect(list.first.price, greaterThan(0));
  });

  test('me() resolves the current staff principal from the stored token', () async {
    await auth.staffLogin(_user, _pass);
    final me = await auth.me();
    expect(me, isNotNull);
    expect(me!.actor, 'staff');
  });

  test('supervisor login carries the supervisor role', () async {
    final session = await auth.staffLogin(_supUser, _supPass);
    expect(session.actor, 'staff');
    expect(session.role, 'supervisor');
  });

  test('step-up: supervisor approves, cashier is rejected', () async {
    // Supervisor credential → name returned (approval granted).
    final approver = await auth.verifyStaff(
      _supUser,
      _supPass,
      requireSupervisor: true,
    );
    expect(approver, isNotNull);
    expect(approver, isNotEmpty);
    // Cashier credential → null (not a supervisor, approval denied).
    final rejected = await auth.verifyStaff(
      _user,
      _pass,
      requireSupervisor: true,
    );
    expect(rejected, isNull);
  });

  test('step-up: wrong supervisor password throws 401', () async {
    await expectLater(
      () => auth.verifyStaff(_supUser, 'salah-password'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('cashier flow: open shift → idempotent sale → cash movement → close', () async {
    await auth.staffLogin(_user, _pass);
    final shifts = ShiftsApi(client);
    final txns = TransactionsApi(client);
    final cash = CashMovementsApi(client);

    var shift = await shifts.current('Kasir Uji');
    shift ??= await shifts.open(initialCash: 100000, cashierName: 'Kasir Uji');
    expect(shift.status, ShiftStatus.open);

    final catalog = await products.list();
    expect(catalog, isNotEmpty);
    final p = catalog.first;

    final idem = 'itest-${DateTime.now().microsecondsSinceEpoch}';
    final sale = await txns.create(
      idempotencyKey: idem,
      items: [TransactionLine(productId: p.id, quantity: 2)],
      paymentMethod: PaymentMethod.cash,
      orderType: OrderType.takeaway,
      amountReceived: p.price * 2 + 10000,
    );
    expect(sale.code, isNotEmpty);
    expect(sale.total, p.price * 2);

    // Idempotent replay returns the same sale.
    final replay = await txns.create(
      idempotencyKey: idem,
      items: [TransactionLine(productId: p.id, quantity: 2)],
      paymentMethod: PaymentMethod.cash,
      orderType: OrderType.takeaway,
      amountReceived: p.price * 2 + 10000,
    );
    expect(replay.id, sale.id);

    final movement = await cash.create(
      type: CashMovementType.additionalCapital,
      amount: 25000,
      createdBy: 'Kasir Uji',
    );
    expect(movement.amount, 25000);

    final history = await txns.list(cashierName: 'Kasir Uji');
    expect(history.any((t) => t.id == sale.id), isTrue);

    // Close (supervisor-approved to cover any variance) — verifies the full flow.
    final closed = await shifts.close(
      shiftId: shift.id,
      actualCash: shift.initialCash,
      closeApprovedBy: 'QA Supervisor',
      cashierName: 'Kasir Uji',
    );
    expect(closed.status, ShiftStatus.closed);
  });
}

/// Default overrides → a real platform HttpClient (used to opt back into real
/// networking inside flutter_test, which otherwise stubs all HTTP).
class _RealHttpOverrides extends HttpOverrides {}
