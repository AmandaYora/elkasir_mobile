import '../../models/pos_models.dart';
import 'api_client.dart';

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

/// Shift lifecycle for the POS staff (`/shifts`). Open/close are staff-only on
/// the server; figures are reconciled server-side at close.
class ShiftsApi {
  ShiftsApi(this._client);

  final ApiClient _client;

  Shift _map(Map<String, dynamic> j, String cashierName) => Shift(
    id: (j['id'] ?? '') as String,
    cashierName: cashierName,
    openedAt: _date(j['openedAt']),
    closedAt: j['closedAt'] == null ? null : _date(j['closedAt']),
    initialCash: (j['initialCash'] as num?)?.toInt() ?? 0,
    status: (j['status'] == 'closed') ? ShiftStatus.closed : ShiftStatus.open,
    cashSales: (j['cashSales'] as num?)?.toInt() ?? 0,
    qrisSales: (j['qrisSales'] as num?)?.toInt() ?? 0,
    additionalCapital: (j['additionalCapital'] as num?)?.toInt() ?? 0,
    expenses: (j['expenses'] as num?)?.toInt() ?? 0,
    withdrawals: (j['withdrawals'] as num?)?.toInt() ?? 0,
    adjustments: (j['adjustments'] as num?)?.toInt() ?? 0,
    drawerOpenCount: (j['drawerOpenCount'] as num?)?.toInt() ?? 0,
    actualCash: (j['actualCash'] as num?)?.toInt(),
    closeNotes: (j['closeApprovedBy'] ?? '') as String,
  );

  /// The currently open shift for the store, or null (HTTP 204) if none.
  Future<Shift?> current(String cashierName) async {
    final data = await _client.get('/shifts/current');
    if (data == null) return null;
    return _map(data as Map<String, dynamic>, cashierName);
  }

  Future<Shift> open({
    required int initialCash,
    required String cashierName,
  }) async {
    final data = await _client.post('/shifts', body: {'initialCash': initialCash});
    return _map(data as Map<String, dynamic>, cashierName);
  }

  Future<Shift> close({
    required String shiftId,
    required int actualCash,
    int drawerOpenCount = 0,
    String closeApprovedBy = '',
    String supervisorPin = '',
    required String cashierName,
  }) async {
    final data = await _client.post(
      '/shifts/$shiftId/close',
      body: {
        'actualCash': actualCash,
        'drawerOpenCount': drawerOpenCount,
        if (closeApprovedBy.isNotEmpty) 'closeApprovedBy': closeApprovedBy,
        if (supervisorPin.isNotEmpty) 'supervisorPin': supervisorPin,
      },
    );
    return _map(data as Map<String, dynamic>, cashierName);
  }
}
