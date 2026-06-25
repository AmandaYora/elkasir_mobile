enum AppScreen {
  pos,
  checkout,
  receipt,
  transactions,
  incomingOrders,
  shiftSummary,
  closeShift,
  cashMovements,
  printerSettings,
  settings,
}

enum ProductStatus { active, inactive, draft }

enum TransactionStatus { paid, cancelled, refunded }

enum ShiftStatus { open, closed }

enum PaymentMethod { cash, qris }

enum StaffRole { cashier, supervisor }

extension StaffRoleLabel on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.cashier:
        return 'Kasir';
      case StaffRole.supervisor:
        return 'Supervisor';
    }
  }
}

enum BusinessType { cafe, restaurant, quickService, bakery, genericFnb }

enum OrderType { dineIn, takeaway, pickup, delivery }

/// Kanal asal order: dibuat kasir, atau self-order pelanggan via QR meja.
enum OrderSource { cashier, selfOrder }

/// Status pemenuhan self-order di kasir.
enum SelfOrderStatus { placed, preparing, completed }

extension OrderSourceLabel on OrderSource {
  String get label {
    switch (this) {
      case OrderSource.cashier:
        return 'Kasir';
      case OrderSource.selfOrder:
        return 'Self-order (QR Meja)';
    }
  }
}

extension SelfOrderStatusLabel on SelfOrderStatus {
  String get label {
    switch (this) {
      case SelfOrderStatus.placed:
        return 'Baru';
      case SelfOrderStatus.preparing:
        return 'Disiapkan';
      case SelfOrderStatus.completed:
        return 'Selesai';
    }
  }
}

enum CashMovementType {
  initialCapital,
  additionalCapital,
  ownerWithdrawal,
  operationalExpense,
  cashAdjustment,
  manualDrawerOpen,
}

extension AppScreenLabel on AppScreen {
  String get label {
    switch (this) {
      case AppScreen.pos:
        return 'Kasir';
      case AppScreen.checkout:
        return 'Pembayaran';
      case AppScreen.receipt:
        return 'Pratinjau Struk';
      case AppScreen.transactions:
        return 'Transaksi';
      case AppScreen.incomingOrders:
        return 'Pesanan Masuk';
      case AppScreen.shiftSummary:
        return 'Ringkasan Shift';
      case AppScreen.closeShift:
        return 'Tutup Shift';
      case AppScreen.cashMovements:
        return 'Mutasi Kas';
      case AppScreen.printerSettings:
        return 'Pengaturan Struk';
      case AppScreen.settings:
        return 'Pengaturan';
    }
  }
}

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai';
      case PaymentMethod.qris:
        return 'QRIS';
    }
  }
}

extension BusinessTypeLabel on BusinessType {
  String get label {
    switch (this) {
      case BusinessType.cafe:
        return 'Kafe';
      case BusinessType.restaurant:
        return 'Restoran';
      case BusinessType.quickService:
        return 'Layanan Cepat';
      case BusinessType.bakery:
        return 'Toko Roti';
      case BusinessType.genericFnb:
        return 'F&B';
    }
  }
}

extension OrderTypeLabel on OrderType {
  String get label {
    switch (this) {
      case OrderType.dineIn:
        return 'Makan di Tempat';
      case OrderType.takeaway:
        return 'Bawa Pulang';
      case OrderType.pickup:
        return 'Ambil Sendiri';
      case OrderType.delivery:
        return 'Antar';
    }
  }
}

extension TransactionStatusLabel on TransactionStatus {
  String get label {
    switch (this) {
      case TransactionStatus.paid:
        return 'Lunas';
      case TransactionStatus.cancelled:
        return 'Dibatalkan';
      case TransactionStatus.refunded:
        return 'Dikembalikan';
    }
  }
}

extension ShiftStatusLabel on ShiftStatus {
  String get label {
    switch (this) {
      case ShiftStatus.open:
        return 'Aktif';
      case ShiftStatus.closed:
        return 'Ditutup';
    }
  }
}

extension CashMovementTypeLabel on CashMovementType {
  String get label {
    switch (this) {
      case CashMovementType.initialCapital:
        return 'Modal Awal';
      case CashMovementType.additionalCapital:
        return 'Modal Tambahan';
      case CashMovementType.ownerWithdrawal:
        return 'Penarikan Pemilik';
      case CashMovementType.operationalExpense:
        return 'Biaya Operasional';
      case CashMovementType.cashAdjustment:
        return 'Penyesuaian Kas';
      case CashMovementType.manualDrawerOpen:
        return 'Buka Laci Manual';
    }
  }
}

class StoreProfile {
  const StoreProfile({
    required this.name,
    required this.outlet,
    required this.address,
    required this.phone,
    required this.businessType,
  });

  final String name;
  final String outlet;
  final String address;
  final String phone;
  final BusinessType businessType;
}

class DiningTable {
  const DiningTable({
    required this.id,
    required this.name,
    required this.area,
    required this.seats,
  });

  final String id;
  final String name;
  final String area;
  final int seats;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    required this.status,
    required this.description,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final int price;
  final int cost;
  final int stock;
  final ProductStatus status;
  final String description;

  /// URL gambar produk dari API ('' bila belum diunggah → pakai default).
  final String imageUrl;
}

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.note = '',
  });

  final Product product;
  final int quantity;
  final String note;

  int get lineTotal => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity, String? note}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }
}

class TransactionItem {
  const TransactionItem({
    required this.productName,
    required this.category,
    required this.quantity,
    required this.price,
    this.note = '',
  });

  final String productName;
  final String category;
  final int quantity;
  final int price;
  final String note;

  int get lineTotal => price * quantity;
}

class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.code,
    required this.shiftId,
    required this.createdAt,
    required this.cashierName,
    this.orderType = OrderType.takeaway,
    this.customerName = '',
    this.tableLabel = '',
    required this.paymentMethod,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    this.serviceCharge = 0,
    this.gatewayFee = 0,
    this.serviceLine = 0,
    required this.total,
    required this.amountReceived,
    required this.change,
    this.source = OrderSource.cashier,
  });

  final String id;
  final String code;
  final String shiftId;
  final DateTime createdAt;
  final String cashierName;
  final OrderType orderType;
  final String customerName;
  final String tableLabel;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final List<TransactionItem> items;
  final int subtotal;
  final int discount;
  final int tax; // PPN
  final int serviceCharge; // biaya layanan 2% (rounded)
  final int gatewayFee; // biaya gateway QRIS (0 utk kasir)
  final int serviceLine; // "Layanan" = serviceCharge + gatewayFee
  final int total;
  final int amountReceived;
  final int change;
  final OrderSource source;
}

class SelfOrder {
  const SelfOrder({
    required this.id,
    required this.tableName,
    required this.items,
    required this.total,
    required this.createdAt,
    this.status = SelfOrderStatus.placed,
    this.paymentMethod = PaymentMethod.qris,
    this.paymentStatus = 'paid',
    this.claimCode = '',
  });

  final String id;
  final String tableName;
  final List<TransactionItem> items;
  final int total;
  final DateTime createdAt;
  final SelfOrderStatus status;
  final PaymentMethod paymentMethod; // cash (bayar di kasir) | qris
  final String paymentStatus; // pending | paid | unpaid | expired | failed
  final String claimCode; // kode tebus (barcode) untuk pesanan bayar-di-kasir

  /// Pesanan bayar-di-kasir yang belum lunas → kasir harus menebus & menerima tunai dulu.
  bool get awaitingCashPayment =>
      paymentMethod == PaymentMethod.cash && paymentStatus != 'paid';

  bool get isPaid => paymentStatus == 'paid';

  SelfOrder copyWith({SelfOrderStatus? status, String? paymentStatus}) {
    return SelfOrder(
      id: id,
      tableName: tableName,
      items: items,
      total: total,
      createdAt: createdAt,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      claimCode: claimCode,
    );
  }
}

class Shift {
  const Shift({
    required this.id,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    required this.initialCash,
    this.notes = '',
    required this.status,
    this.cashSales = 0,
    this.qrisSales = 0,
    this.additionalCapital = 0,
    this.expenses = 0,
    this.withdrawals = 0,
    this.adjustments = 0,
    this.drawerOpenCount = 0,
    this.actualCash,
    this.closeNotes = '',
  });

  final String id;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int initialCash;
  final String notes;
  final ShiftStatus status;
  final int cashSales;
  final int qrisSales;
  final int additionalCapital;
  final int expenses;
  final int withdrawals;
  final int adjustments;
  final int drawerOpenCount;
  final int? actualCash;
  final String closeNotes;

  int get expectedCash =>
      initialCash +
      cashSales +
      additionalCapital -
      expenses -
      withdrawals +
      adjustments;

  int? get variance => actualCash == null ? null : actualCash! - expectedCash;

  int get totalSales => cashSales + qrisSales;

  Shift copyWith({
    String? id,
    String? cashierName,
    DateTime? openedAt,
    Object? closedAt = _unset,
    int? initialCash,
    String? notes,
    ShiftStatus? status,
    int? cashSales,
    int? qrisSales,
    int? additionalCapital,
    int? expenses,
    int? withdrawals,
    int? adjustments,
    int? drawerOpenCount,
    Object? actualCash = _unset,
    String? closeNotes,
  }) {
    return Shift(
      id: id ?? this.id,
      cashierName: cashierName ?? this.cashierName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt == _unset ? this.closedAt : closedAt as DateTime?,
      initialCash: initialCash ?? this.initialCash,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      cashSales: cashSales ?? this.cashSales,
      qrisSales: qrisSales ?? this.qrisSales,
      additionalCapital: additionalCapital ?? this.additionalCapital,
      expenses: expenses ?? this.expenses,
      withdrawals: withdrawals ?? this.withdrawals,
      adjustments: adjustments ?? this.adjustments,
      drawerOpenCount: drawerOpenCount ?? this.drawerOpenCount,
      actualCash: actualCash == _unset ? this.actualCash : actualCash as int?,
      closeNotes: closeNotes ?? this.closeNotes,
    );
  }
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.amount,
    required this.notes,
    required this.createdBy,
    required this.shiftId,
  });

  final String id;
  final DateTime createdAt;
  final CashMovementType type;
  final int amount;
  final String notes;
  final String createdBy;
  final String shiftId;
}

/// Cara mencetak struk: lewat dialog/printer sistem (PDF), atau langsung ke
/// printer thermal ESC/POS via Bluetooth.
enum PrintMode { system, bluetooth }

class PrinterDevice {
  const PrinterDevice({
    this.mode = PrintMode.system,
    this.paperWidth = '80 mm',
    this.deviceName = '',
    this.deviceAddress = '',
    this.connected = false,
  });

  final PrintMode mode;

  /// Lebar kertas struk ('58 mm' atau '80 mm').
  final String paperWidth;

  /// Printer Bluetooth terpilih (mode ESC/POS).
  final String deviceName;
  final String deviceAddress;

  /// Status koneksi Bluetooth saat ini (runtime, tidak disimpan).
  final bool connected;

  bool get hasDevice => deviceAddress.isNotEmpty;

  PrinterDevice copyWith({
    PrintMode? mode,
    String? paperWidth,
    String? deviceName,
    String? deviceAddress,
    bool? connected,
  }) {
    return PrinterDevice(
      mode: mode ?? this.mode,
      paperWidth: paperWidth ?? this.paperWidth,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      connected: connected ?? this.connected,
    );
  }
}

const _unset = Object();
