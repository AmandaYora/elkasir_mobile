import '../../models/pos_models.dart';
import 'api_client.dart';

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

/// Cash drawer movements (`/cash-movements`). The server's type enum is
/// capital | expense | adjustment; the POS maps its richer enum onto these.
class CashMovementsApi {
  CashMovementsApi(this._client);

  final ApiClient _client;

  static String? _apiType(CashMovementType type) {
    switch (type) {
      case CashMovementType.additionalCapital:
        return 'capital';
      case CashMovementType.operationalExpense:
        return 'expense';
      case CashMovementType.cashAdjustment:
        return 'adjustment';
      case CashMovementType.initialCapital:
      case CashMovementType.ownerWithdrawal:
      case CashMovementType.manualDrawerOpen:
        return null; // not posted to /cash-movements
    }
  }

  Future<CashMovement> create({
    required CashMovementType type,
    required int amount,
    String notes = '',
    String approvedBy = '',
    required String createdBy,
  }) async {
    final apiType = _apiType(type);
    if (apiType == null) {
      throw ArgumentError('CashMovementType $type is not a server cash movement');
    }
    final data = await _client.post('/cash-movements', body: {
      'type': apiType,
      'amount': amount.abs(),
      if (notes.isNotEmpty) 'notes': notes,
      if (approvedBy.isNotEmpty) 'approvedBy': approvedBy,
    });
    return _map(data as Map<String, dynamic>, createdBy);
  }

  Future<List<CashMovement>> list(String createdBy) async {
    final data = await _client.get('/cash-movements', query: {'limit': '200'});
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map((j) => _map(j, createdBy)).toList();
  }

  CashMovement _map(Map<String, dynamic> j, String createdBy) {
    final apiType = (j['type'] ?? '') as String;
    final type = switch (apiType) {
      'capital' => CashMovementType.additionalCapital,
      'expense' => CashMovementType.operationalExpense,
      _ => CashMovementType.cashAdjustment,
    };
    final raw = (j['amount'] as num?)?.toInt() ?? 0;
    // POS convention: cash-out is negative for display.
    final signed = type == CashMovementType.operationalExpense ? -raw.abs() : raw;
    return CashMovement(
      id: (j['id'] ?? '') as String,
      createdAt: _date(j['createdAt']),
      type: type,
      amount: signed,
      notes: (j['notes'] ?? '') as String,
      createdBy: ((j['createdBy'] ?? '') as String).isEmpty
          ? createdBy
          : (j['createdBy'] as String),
      shiftId: (j['shiftId'] ?? '') as String,
    );
  }
}
