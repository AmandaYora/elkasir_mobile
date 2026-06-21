import '../../models/pos_models.dart';
import 'api_client.dart';

/// Dining tables for the dine-in flow (`GET /tables`, read-only for POS staff).
class TablesApi {
  TablesApi(this._client);

  final ApiClient _client;

  Future<List<DiningTable>> list() async {
    final data = await _client.get('/tables', query: {'limit': '200'});
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows
        .where((t) => t['status'] != 'inactive')
        .map(
          (t) => DiningTable(
            id: (t['id'] ?? '') as String,
            name: ((t['name'] ?? t['code'] ?? '') as String),
            area: (t['area'] ?? '') as String,
            seats: (t['seats'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }
}
