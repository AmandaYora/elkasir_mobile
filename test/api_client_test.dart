// Unit tests for the API layer using an in-memory fake HTTP transport
// (package:http MockClient) — fast, hermetic, no real network.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elkasir_pos/models/pos_models.dart';
import 'package:elkasir_pos/services/api/api_client.dart';
import 'package:elkasir_pos/services/api/api_exception.dart';
import 'package:elkasir_pos/services/api/cash_movements_api.dart';
import 'package:elkasir_pos/services/api/products_api.dart';
import 'package:elkasir_pos/services/api/token_store.dart';

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: const {
      'content-type': 'application/json',
    });

ApiClient _client(MockClient mock) =>
    ApiClient(baseUrl: 'http://test/api/v1', tokens: TokenStore(), client: mock);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('unwraps the success envelope and returns data', () async {
    final client = _client(
      MockClient((_) async => _json({
            'success': true,
            'message': 'ok',
            'data': {'a': 1},
          }, 200)),
    );
    expect(await client.get('/x', auth: false), {'a': 1});
  });

  test('maps a non-2xx error to ApiException with the server message', () async {
    final client = _client(
      MockClient((_) async => _json({
            'success': false,
            'message': 'Validasi gagal',
            'errors': [
              {'code': 'validation_error'},
            ],
          }, 400)),
    );
    await expectLater(
      () => client.get('/x', auth: false),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'Validasi gagal')
            .having((e) => e.code, 'code', 'validation_error'),
      ),
    );
  });

  test('connection failures surface as a network ApiException', () async {
    final client = _client(MockClient((_) async => throw http.ClientException('boom')));
    await expectLater(
      () => client.get('/x', auth: false),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
    );
  });

  test('ProductsApi maps catalog rows to Product', () async {
    final client = _client(
      MockClient((_) async => _json({
            'success': true,
            'message': 'ok',
            'data': [
              {
                'id': 'p1',
                'name': 'Kopi Hitam',
                'sku': 'K-1',
                'category': 'Minuman',
                'price': 16000,
                'cost': 6000,
                'stock': 25,
                'status': 'active',
              },
            ],
          }, 200)),
    );
    final list = await ProductsApi(client).list();
    expect(list.single.name, 'Kopi Hitam');
    expect(list.single.price, 16000);
    expect(list.single.status, ProductStatus.active);
  });

  test('CashMovementsApi signs expense negative for display', () async {
    final client = _client(
      MockClient((_) async => _json({
            'success': true,
            'message': 'ok',
            'data': {
              'id': 'cm1',
              'type': 'expense',
              'amount': 45000,
              'notes': 'Beli galon',
              'createdAt': '2026-06-20T10:00:00Z',
            },
          }, 200)),
    );
    final mv = await CashMovementsApi(client).create(
      type: CashMovementType.operationalExpense,
      amount: 45000,
      createdBy: 'Kasir',
    );
    expect(mv.type, CashMovementType.operationalExpense);
    expect(mv.amount, -45000);
  });
}
