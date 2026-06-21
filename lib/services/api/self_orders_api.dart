import '../../models/pos_models.dart';
import 'api_client.dart';

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

/// Customer self-orders arriving from table QR codes (`/self-orders`).
class SelfOrdersApi {
  SelfOrdersApi(this._client);

  final ApiClient _client;

  static SelfOrderStatus _status(dynamic s) => switch (s) {
    'preparing' => SelfOrderStatus.preparing,
    'completed' => SelfOrderStatus.completed,
    _ => SelfOrderStatus.placed,
  };

  SelfOrder _map(Map<String, dynamic> j) {
    final items = ((j['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (it) => TransactionItem(
            productName: (it['productName'] ?? '') as String,
            category: (it['category'] ?? '') as String,
            quantity: (it['quantity'] as num?)?.toInt() ?? 0,
            price: (it['price'] as num?)?.toInt() ?? 0,
            note: (it['note'] ?? '') as String,
          ),
        )
        .toList();
    return SelfOrder(
      id: (j['id'] ?? '') as String,
      tableName: (j['tableName'] ?? j['tableCode'] ?? '') as String,
      items: items,
      total: (j['total'] as num?)?.toInt() ?? 0,
      createdAt: _date(j['createdAt']),
      status: _status(j['status']),
    );
  }

  Future<List<SelfOrder>> list() async {
    final data = await _client.get('/self-orders', query: {'limit': '100'});
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map(_map).toList();
  }

  Future<SelfOrder> updateStatus(String id, SelfOrderStatus status) async {
    final s = switch (status) {
      SelfOrderStatus.placed => 'placed',
      SelfOrderStatus.preparing => 'preparing',
      SelfOrderStatus.completed => 'completed',
    };
    final data = await _client.patch('/self-orders/$id/status', body: {'status': s});
    return _map(data as Map<String, dynamic>);
  }
}
