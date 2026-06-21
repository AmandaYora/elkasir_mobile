import '../../models/pos_models.dart';
import 'api_client.dart';

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

/// Result of a created sale — server-authoritative id/code + full money breakdown
/// (subtotal, layanan, gateway, PPN, total, kembalian).
class CreatedSale {
  const CreatedSale({
    required this.id,
    required this.code,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.serviceCharge,
    required this.gatewayFee,
    required this.serviceLine,
    required this.total,
    required this.amountReceived,
    required this.change,
  });
  final String id;
  final String code;
  final int subtotal;
  final int discount;
  final int tax;
  final int serviceCharge;
  final int gatewayFee;
  final int serviceLine;
  final int total;
  final int amountReceived;
  final int change;
}

class TransactionLine {
  const TransactionLine({
    required this.productId,
    required this.quantity,
    this.note = '',
  });
  final String productId;
  final int quantity;
  final String note;
}

/// Cashier sales (`/transactions`). Create is staff-only and idempotent.
class TransactionsApi {
  TransactionsApi(this._client);

  final ApiClient _client;

  Future<CreatedSale> create({
    required String idempotencyKey,
    required List<TransactionLine> items,
    required PaymentMethod paymentMethod,
    required OrderType orderType,
    int? amountReceived,
    int discount = 0,
    String? tableId,
    String customerNote = '',
    String discountApprovedBy = '',
  }) async {
    final body = <String, dynamic>{
      'items': items
          .map((i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                if (i.note.isNotEmpty) 'note': i.note,
              })
          .toList(),
      'paymentMethod': paymentMethod == PaymentMethod.qris ? 'qris' : 'cash',
      'orderType': orderType == OrderType.dineIn ? 'dineIn' : 'takeaway',
      if (paymentMethod == PaymentMethod.cash && amountReceived != null)
        'amountReceived': amountReceived,
      if (discount > 0) 'discount': discount,
      if (tableId != null && tableId.isNotEmpty) 'tableId': tableId,
      if (customerNote.isNotEmpty) 'customerNote': customerNote,
      if (discountApprovedBy.isNotEmpty) 'discountApprovedBy': discountApprovedBy,
    };
    final data = await _client.post(
      '/transactions',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Map<String, dynamic>;
    int n(String k) => (data[k] as num?)?.toInt() ?? 0;
    return CreatedSale(
      id: (data['id'] ?? '') as String,
      code: (data['code'] ?? '') as String,
      subtotal: n('subtotal'),
      discount: n('discount'),
      tax: n('tax'),
      serviceCharge: n('serviceCharge'),
      gatewayFee: n('gatewayFee'),
      serviceLine: n('serviceLine'),
      total: n('total'),
      amountReceived: n('amountReceived'),
      change: n('changeAmount'),
    );
  }

  /// Recent transactions (mapped for the history list). cashierName comes from
  /// the session; tableLabel is resolved from [tableName].
  Future<List<SaleTransaction>> list({
    required String cashierName,
    String Function(String tableId)? tableName,
    int limit = 100,
  }) async {
    final data = await _client.get('/transactions', query: {'limit': '$limit'});
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map((j) => _map(j, cashierName, tableName)).toList();
  }

  SaleTransaction _map(
    Map<String, dynamic> j,
    String cashierName,
    String Function(String tableId)? tableName,
  ) {
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
    final tableId = (j['tableId'] ?? '') as String;
    return SaleTransaction(
      id: (j['id'] ?? '') as String,
      code: (j['code'] ?? '') as String,
      shiftId: (j['shiftId'] ?? '') as String,
      createdAt: _date(j['createdAt']),
      cashierName: cashierName,
      orderType: (j['orderType'] == 'dineIn')
          ? OrderType.dineIn
          : OrderType.takeaway,
      customerName: (j['customerNote'] ?? '') as String,
      tableLabel: tableId.isEmpty ? '' : (tableName?.call(tableId) ?? ''),
      paymentMethod: (j['paymentMethod'] == 'qris')
          ? PaymentMethod.qris
          : PaymentMethod.cash,
      status: TransactionStatus.paid,
      items: items,
      subtotal: (j['subtotal'] as num?)?.toInt() ?? 0,
      discount: (j['discount'] as num?)?.toInt() ?? 0,
      tax: (j['tax'] as num?)?.toInt() ?? 0,
      serviceCharge: (j['serviceCharge'] as num?)?.toInt() ?? 0,
      gatewayFee: (j['gatewayFee'] as num?)?.toInt() ?? 0,
      serviceLine: (j['serviceLine'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      amountReceived: (j['amountReceived'] as num?)?.toInt() ?? 0,
      change: (j['changeAmount'] as num?)?.toInt() ?? 0,
      source: (j['source'] == 'self_order')
          ? OrderSource.selfOrder
          : OrderSource.cashier,
    );
  }
}
