import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/pricing.dart';
import '../models/pos_models.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../services/api/api_exception.dart';
import '../services/api/api_providers.dart';
import '../services/api/config_api.dart';
import '../services/api/transactions_api.dart';
import '../services/config_store.dart';
import '../services/printer_service.dart';
import '../services/printer_settings_store.dart';
import '../services/thermal_printer_service.dart';

final appControllerProvider = NotifierProvider<AppController, PosAppState>(
  AppController.new,
);

class PosAppState {
  const PosAppState({
    required this.isAuthenticated,
    required this.cashierName,
    required this.cashierRole,
    required this.store,
    required this.currentShift,
    required this.products,
    required this.tables,
    required this.cart,
    required this.selectedCategory,
    required this.productSearch,
    required this.selectedOrderType,
    required this.customerName,
    required this.tableLabel,
    required this.discount,
    required this.discountApprovedBy,
    required this.selectedPaymentMethod,
    required this.amountReceived,
    required this.transactions,
    required this.incomingOrders,
    required this.selectedTransaction,
    required this.lastTransaction,
    required this.cashMovements,
    required this.printer,
    required this.screen,
    required this.transactionSearch,
    required this.transactionStatusFilter,
    this.servicePercent = 2,
    this.taxPercent = 11,
    this.taxEnabled = false,
    this.featureQris = true,
    this.featureSelfOrder = true,
    this.maxDiscountPercent = 10,
    this.maxOperationalExpense = 200000,
    this.cashVarianceTolerance = 5000,
    this.restoring = false,
  });

  factory PosAppState.initial() {
    return const PosAppState(
      isAuthenticated: false,
      cashierName: '',
      cashierRole: StaffRole.cashier,
      store: storeProfile,
      currentShift: null,
      products: [],
      tables: [],
      cart: [],
      selectedCategory: 'Semua',
      productSearch: '',
      selectedOrderType: OrderType.takeaway,
      customerName: '',
      tableLabel: '',
      discount: 0,
      discountApprovedBy: '',
      selectedPaymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      transactions: [],
      incomingOrders: [],
      selectedTransaction: null,
      lastTransaction: null,
      cashMovements: [],
      printer: PrinterDevice(paperWidth: '80 mm'),
      screen: AppScreen.pos,
      transactionSearch: '',
      transactionStatusFilter: 'Semua',
    );
  }

  final bool isAuthenticated;
  final String cashierName;
  final StaffRole cashierRole;
  final StoreProfile store;
  final Shift? currentShift;
  final List<Product> products;
  final List<DiningTable> tables;
  final List<CartItem> cart;
  final String selectedCategory;
  final String productSearch;
  final OrderType selectedOrderType;
  final String customerName;
  final String tableLabel;
  final int discount;
  final String discountApprovedBy;
  final PaymentMethod selectedPaymentMethod;
  final int amountReceived;
  final List<SaleTransaction> transactions;
  final List<SelfOrder> incomingOrders;
  final SaleTransaction? selectedTransaction;
  final SaleTransaction? lastTransaction;
  final List<CashMovement> cashMovements;
  final PrinterDevice printer;
  final AppScreen screen;
  final String transactionSearch;
  final String transactionStatusFilter;
  final int servicePercent; // biaya layanan % (dari server /pos/config)
  final int taxPercent; // PPN %
  final bool taxEnabled; // PPN aktif?
  final bool featureQris; // metode QRIS aktif? (hide tombol QRIS bila false)
  final bool featureSelfOrder; // self-order aktif? (hide tab "Pesanan Masuk" bila false)
  final int maxDiscountPercent; // ambang diskon butuh persetujuan (% subtotal)
  final int maxOperationalExpense; // ambang biaya butuh persetujuan (Rp)
  final int cashVarianceTolerance; // toleransi selisih kas tutup shift (Rp)
  final bool restoring; // true saat memulihkan sesi tersimpan di cold start (tampilkan splash)

  bool get hasOpenShift => currentShift?.status == ShiftStatus.open;

  /// Supervisor melihat fitur penuh; kasir hanya fitur kasir (sisanya disembunyikan).
  bool get isSupervisor => cashierRole == StaffRole.supervisor;

  int get newSelfOrderCount =>
      incomingOrders.where((o) => o.status == SelfOrderStatus.placed).length;

  int get subtotal => cart.fold(0, (sum, item) => sum + item.lineTotal);

  // Layanan & PPN memakai aturan SAMA dengan server (lihat core/pricing.dart); gateway fee = 0 di kasir.
  int get service => serviceChargeOf(subtotal, servicePercent);

  int get tax => taxOf(subtotal, taxPercent, taxEnabled);

  int get serviceLine => service;

  int get total => math.max(0, subtotal - discount + service + tax);

  int get cashChange =>
      selectedPaymentMethod == PaymentMethod.cash ? amountReceived - total : 0;

  int get totalItems => cart.fold(0, (sum, item) => sum + item.quantity);

  List<String> get categories {
    final set = <String>{};
    for (final p in products) {
      if (p.category.isNotEmpty) set.add(p.category);
    }
    final sorted = set.toList()..sort();
    return ['Semua', ...sorted];
  }

  List<Product> get visibleProducts {
    final query = productSearch.trim().toLowerCase();
    return products.where((product) {
      final categoryMatches =
          selectedCategory == 'Semua' || product.category == selectedCategory;
      final queryMatches =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return product.status == ProductStatus.active &&
          categoryMatches &&
          queryMatches;
    }).toList();
  }

  List<SaleTransaction> get visibleTransactions {
    final query = transactionSearch.trim().toLowerCase();
    // Scoping: kasir hanya melihat transaksi shift aktifnya sendiri.
    final shiftId = currentShift?.id;
    if (shiftId == null) {
      return const [];
    }
    return transactions.where((transaction) {
      final shiftMatches = transaction.shiftId == shiftId;
      final statusMatches =
          transactionStatusFilter == 'Semua' ||
          transaction.status.label == transactionStatusFilter;
      final queryMatches =
          query.isEmpty ||
          transaction.code.toLowerCase().contains(query) ||
          transaction.cashierName.toLowerCase().contains(query) ||
          transaction.orderType.label.toLowerCase().contains(query) ||
          transaction.customerName.toLowerCase().contains(query) ||
          transaction.tableLabel.toLowerCase().contains(query) ||
          transaction.paymentMethod.label.toLowerCase().contains(query);
      return shiftMatches && statusMatches && queryMatches;
    }).toList();
  }

  PosAppState copyWith({
    bool? isAuthenticated,
    String? cashierName,
    StaffRole? cashierRole,
    StoreProfile? store,
    Object? currentShift = _unset,
    List<Product>? products,
    List<DiningTable>? tables,
    List<CartItem>? cart,
    String? selectedCategory,
    String? productSearch,
    OrderType? selectedOrderType,
    String? customerName,
    String? tableLabel,
    int? discount,
    String? discountApprovedBy,
    PaymentMethod? selectedPaymentMethod,
    int? amountReceived,
    List<SaleTransaction>? transactions,
    List<SelfOrder>? incomingOrders,
    Object? selectedTransaction = _unset,
    Object? lastTransaction = _unset,
    List<CashMovement>? cashMovements,
    PrinterDevice? printer,
    AppScreen? screen,
    String? transactionSearch,
    String? transactionStatusFilter,
    int? servicePercent,
    int? taxPercent,
    bool? taxEnabled,
    bool? featureQris,
    bool? featureSelfOrder,
    int? maxDiscountPercent,
    int? maxOperationalExpense,
    int? cashVarianceTolerance,
    bool? restoring,
  }) {
    return PosAppState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      cashierName: cashierName ?? this.cashierName,
      cashierRole: cashierRole ?? this.cashierRole,
      store: store ?? this.store,
      currentShift: currentShift == _unset
          ? this.currentShift
          : currentShift as Shift?,
      products: products ?? this.products,
      tables: tables ?? this.tables,
      cart: cart ?? this.cart,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      productSearch: productSearch ?? this.productSearch,
      selectedOrderType: selectedOrderType ?? this.selectedOrderType,
      customerName: customerName ?? this.customerName,
      tableLabel: tableLabel ?? this.tableLabel,
      discount: discount ?? this.discount,
      discountApprovedBy: discountApprovedBy ?? this.discountApprovedBy,
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      amountReceived: amountReceived ?? this.amountReceived,
      transactions: transactions ?? this.transactions,
      incomingOrders: incomingOrders ?? this.incomingOrders,
      selectedTransaction: selectedTransaction == _unset
          ? this.selectedTransaction
          : selectedTransaction as SaleTransaction?,
      lastTransaction: lastTransaction == _unset
          ? this.lastTransaction
          : lastTransaction as SaleTransaction?,
      cashMovements: cashMovements ?? this.cashMovements,
      printer: printer ?? this.printer,
      screen: screen ?? this.screen,
      transactionSearch: transactionSearch ?? this.transactionSearch,
      transactionStatusFilter:
          transactionStatusFilter ?? this.transactionStatusFilter,
      servicePercent: servicePercent ?? this.servicePercent,
      taxPercent: taxPercent ?? this.taxPercent,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      featureQris: featureQris ?? this.featureQris,
      featureSelfOrder: featureSelfOrder ?? this.featureSelfOrder,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      maxOperationalExpense: maxOperationalExpense ?? this.maxOperationalExpense,
      cashVarianceTolerance: cashVarianceTolerance ?? this.cashVarianceTolerance,
      restoring: restoring ?? this.restoring,
    );
  }
}

class AppController extends Notifier<PosAppState> {
  final _printerService = PrinterService();
  final _thermal = ThermalPrinterService();
  final _printerSettings = PrinterSettingsStore();
  final _configStore = ConfigStore();

  /// PIN supervisor untuk diskon di atas plafon — sesaat, TIDAK dipersistensi; dikirim ke server saat checkout lalu dibersihkan.
  String _discountSupervisorPin = '';

  /// Idempotency-Key penjualan: dibuat sekali per upaya bayar dan dipertahankan saat retry, agar server me-replay (bukan transaksi/stok ganda).
  String? _pendingSaleKey;

  @override
  PosAppState build() {
    _hydratePrinter();
    _hydrateConfig();
    _restoreSession();
    return PosAppState.initial().copyWith(restoring: true);
  }

  // ── Session restore (cold start) ──────────────────────────────────────────

  /// Pulihkan sesi dari token tersimpan agar kasir tak perlu login ulang; token invalid → ke layar login.
  Future<void> _restoreSession() async {
    try {
      await ref.read(tokenStoreProvider).load();
      final session = await ref.read(authApiProvider).me();
      if (session != null && session.actor == 'staff') {
        final role = session.role == 'supervisor'
            ? StaffRole.supervisor
            : StaffRole.cashier;
        state = state.copyWith(
          isAuthenticated: true,
          cashierName: session.name,
          cashierRole: role,
        );
        await _loadSession();
      }
    } catch (_) {
      // token tidak valid / gagal → biarkan ke layar login
    } finally {
      state = state.copyWith(restoring: false);
    }
  }

  // ── Config (server-driven feature flags + pricing + thresholds) ───────────

  PosAppState _withConfig(PosAppState s, PosConfig c) {
    var next = s.copyWith(
      servicePercent: c.servicePercent,
      taxPercent: c.taxPercent,
      taxEnabled: c.taxEnabled,
      featureQris: c.featureQris,
      featureSelfOrder: c.featureSelfOrder,
      maxDiscountPercent: c.maxDiscountPercent,
      maxOperationalExpense: c.maxOperationalExpense,
      cashVarianceTolerance: c.cashVarianceTolerance,
    );
    // Bila QRIS dimatikan saat metode itu terpilih, jatuhkan ke tunai (hindari state mustahil).
    if (!next.featureQris &&
        next.selectedPaymentMethod == PaymentMethod.qris) {
      next = next.copyWith(
        selectedPaymentMethod: PaymentMethod.cash,
        amountReceived: 0,
      );
    }
    return next;
  }

  /// Muat konfigurasi last-known-good saat start agar flag akurat lebih awal.
  Future<void> _hydrateConfig() async {
    final cached = await _configStore.load();
    if (cached != null) state = _withConfig(state, cached);
  }

  /// Refresh konfigurasi dari server saat app kembali ke foreground; fail-open: gagal → pertahankan nilai terakhir.
  Future<void> refreshConfig() async {
    if (!state.isAuthenticated) return;
    try {
      final cfg = await ref.read(configApiProvider).get();
      await _configStore.save(cfg);
      state = _withConfig(state, cfg);
    } catch (_) {}
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  /// POS staff login (`/auth/staff/login`); on success loads session from server. Returns error message, or null on success.
  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final session = await ref
          .read(authApiProvider)
          .staffLogin(identifier, password);
      final role = session.role == 'supervisor'
          ? StaffRole.supervisor
          : StaffRole.cashier;
      final name = session.name.isEmpty ? identifier.trim() : session.name;
      state = state.copyWith(
        isAuthenticated: true,
        cashierName: name,
        cashierRole: role,
        cart: const [],
        discount: 0,
        discountApprovedBy: '',
        amountReceived: 0,
        screen: AppScreen.pos,
      );
      await _loadSession();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal masuk. Periksa koneksi lalu coba lagi.';
    }
  }

  /// Logout: revoke refresh token + clear local session. Open shift NOT closed — stays open server-side, resumes next login.
  void logout() {
    unawaited(ref.read(authApiProvider).logout());
    state = PosAppState.initial().copyWith(isAuthenticated: false);
  }

  // ── Session loading ──────────────────────────────────────────────────────

  Future<void> _loadSession() async {
    final name = state.cashierName;
    List<Product> products = const [];
    List<DiningTable> tables = const [];
    Shift? shift;
    PosConfig? cfg;
    try {
      products = await ref.read(productsApiProvider).list();
    } catch (_) {}
    try {
      tables = await ref.read(tablesApiProvider).list();
    } catch (_) {}
    try {
      shift = await ref.read(shiftsApiProvider).current(name);
    } catch (_) {}
    try {
      // Simpan last-known-good agar flag/harga akurat di cold start berikutnya.
      cfg = await ref.read(configApiProvider).get();
      await _configStore.save(cfg);
    } catch (_) {}
    state = state.copyWith(
      products: products,
      tables: tables,
      currentShift: shift,
      tableLabel: tables.isNotEmpty ? tables.first.name : '',
    );
    if (cfg != null) {
      state = _withConfig(state, cfg);
    }
    if (shift != null) {
      await _loadShiftData();
    }
  }

  Future<void> _loadShiftData() async {
    final name = state.cashierName;
    final tablesById = {for (final t in state.tables) t.id: t.name};
    List<SaleTransaction> txns = const [];
    List<CashMovement> movements = const [];
    List<SelfOrder> incoming = const [];
    try {
      txns = await ref.read(transactionsApiProvider).list(
        cashierName: name,
        tableName: (id) => tablesById[id] ?? '',
      );
    } catch (_) {}
    // Mutasi kas = supervisor-only di server; kasir tak perlu (dan akan ditolak 403).
    if (state.isSupervisor) {
      try {
        movements = await ref.read(cashMovementsApiProvider).list(name);
      } catch (_) {}
    }
    try {
      incoming = await ref.read(selfOrdersApiProvider).list();
    } catch (_) {}
    state = state.copyWith(
      transactions: txns,
      cashMovements: movements,
      incomingOrders: incoming,
    );
  }

  Future<void> refreshSession() => _loadSession();

  // ── Shift ────────────────────────────────────────────────────────────────

  Future<String?> openShift({required int initialCash, String notes = ''}) async {
    try {
      final shift = await ref
          .read(shiftsApiProvider)
          .open(initialCash: initialCash, cashierName: state.cashierName);
      state = state.copyWith(
        currentShift: shift.copyWith(notes: notes),
        screen: AppScreen.pos,
        cart: const [],
        discount: 0,
        amountReceived: 0,
      );
      await _loadShiftData();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal membuka shift. Coba lagi.';
    }
  }

  void startNewShift() {
    state = state.copyWith(
      currentShift: null,
      cart: const [],
      discount: 0,
      amountReceived: 0,
      lastTransaction: null,
      selectedTransaction: null,
      transactions: const [],
      cashMovements: const [],
      screen: AppScreen.pos,
    );
  }

  Future<String?> closeShift({
    required int actualCash,
    String notes = '',
    String approvedBy = '',
    String supervisorPin = '',
  }) async {
    final shift = state.currentShift;
    if (shift == null || shift.status != ShiftStatus.open) {
      return 'Tidak ada shift aktif.';
    }
    try {
      final closed = await ref.read(shiftsApiProvider).close(
        shiftId: shift.id,
        actualCash: actualCash,
        drawerOpenCount: shift.drawerOpenCount,
        closeApprovedBy: approvedBy,
        supervisorPin: supervisorPin,
        cashierName: state.cashierName,
      );
      state = state.copyWith(
        currentShift: closed.copyWith(
          closeNotes: notes.isEmpty ? closed.closeNotes : notes,
        ),
        cart: const [],
        discount: 0,
        amountReceived: 0,
        screen: AppScreen.shiftSummary,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal menutup shift. Coba lagi.';
    }
  }

  // ── Navigation & cart (local UI state) ────────────────────────────────────

  void navigate(AppScreen screen) {
    if (screen == AppScreen.pos && !state.hasOpenShift) {
      return;
    }
    // Layar supervisor-only tak dapat diakses kasir (sejalan dgn penegakan server).
    if (!state.isSupervisor &&
        (screen == AppScreen.cashMovements ||
            screen == AppScreen.printerSettings)) {
      return;
    }
    // Pesanan masuk hilang bila self-order dimatikan admin.
    if (!state.featureSelfOrder && screen == AppScreen.incomingOrders) {
      return;
    }
    state = state.copyWith(screen: screen);
  }

  void setProductSearch(String query) =>
      state = state.copyWith(productSearch: query);

  void setCategory(String category) =>
      state = state.copyWith(selectedCategory: category);

  void setOrderType(OrderType orderType) =>
      state = state.copyWith(selectedOrderType: orderType);

  void setCustomerName(String value) =>
      state = state.copyWith(customerName: value.trim());

  void setTableLabel(String value) => state = state.copyWith(tableLabel: value);

  void addProduct(Product product) {
    if (!state.hasOpenShift) {
      return;
    }
    final cart = [...state.cart];
    final index = cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final existing = cart[index];
      cart[index] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      cart.add(CartItem(product: product, quantity: 1));
    }
    state = state.copyWith(cart: cart);
  }

  void updateQuantity(String productId, int quantity) {
    final cart = state.cart
        .map(
          (item) => item.product.id == productId
              ? item.copyWith(quantity: quantity)
              : item,
        )
        .where((item) => item.quantity > 0)
        .toList();
    state = state.copyWith(cart: cart);
  }

  void setItemNote(String productId, String note) {
    final cart = state.cart
        .map(
          (item) =>
              item.product.id == productId ? item.copyWith(note: note) : item,
        )
        .toList();
    state = state.copyWith(cart: cart);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      cart: state.cart.where((item) => item.product.id != productId).toList(),
    );
  }

  void clearCart() {
    _discountSupervisorPin = '';
    _pendingSaleKey = null; // batalkan upaya bayar tertunda saat keranjang dikosongkan
    state = state.copyWith(
      cart: const [],
      discount: 0,
      discountApprovedBy: '',
      amountReceived: 0,
      customerName: '',
    );
  }

  /// Diskon di atas max-discount percent (/pos/config) hanya berlaku bila [supervisorApproved]; selain itu di-clamp.
  void setDiscount(
    int value, {
    bool supervisorApproved = false,
    String approvedBy = '',
    String supervisorPin = '',
  }) {
    final subtotal = state.subtotal;
    var amount = math.max(0, math.min(value, subtotal));
    final cap = (subtotal * state.maxDiscountPercent / 100).floor();
    if (!supervisorApproved && amount > cap) {
      amount = cap;
    }
    // PIN hanya untuk kasir yang menyetujui via PIN; supervisor login → PIN kosong, server mengenali rolenya.
    _discountSupervisorPin = supervisorApproved ? supervisorPin : '';
    state = state.copyWith(
      discount: amount,
      discountApprovedBy: supervisorApproved ? approvedBy : '',
    );
  }

  int get discountCap =>
      (state.subtotal * state.maxDiscountPercent / 100).floor();

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      selectedPaymentMethod: method,
      amountReceived: method == PaymentMethod.cash ? state.amountReceived : 0,
    );
  }

  void setAmountReceived(int value) =>
      state = state.copyWith(amountReceived: math.max(0, value));

  String? _tableIdFor(String label) {
    for (final t in state.tables) {
      if (t.name == label) return t.id;
    }
    return null;
  }

  // ── Sale ──────────────────────────────────────────────────────────────────

  /// Submit cart as cashier sale (`POST /transactions`, idempotent). Returns error message, or null on success.
  Future<String?> completePayment() async {
    final shift = state.currentShift;
    if (shift == null || shift.status != ShiftStatus.open) {
      return 'Buka shift dulu sebelum menerima pembayaran.';
    }
    if (state.cart.isEmpty) {
      return 'Keranjang masih kosong.';
    }
    final method = state.selectedPaymentMethod;
    final amountReceived = method == PaymentMethod.cash
        ? state.amountReceived
        : state.total;
    if (method == PaymentMethod.cash && amountReceived < state.total) {
      return 'Uang diterima kurang dari total.';
    }

    final dineIn = state.selectedOrderType == OrderType.dineIn;
    final lines = state.cart
        .map(
          (i) => TransactionLine(
            productId: i.product.id,
            quantity: i.quantity,
            note: i.note,
          ),
        )
        .toList();
    // Key dipertahankan antar-retry: time-out lalu "Bayar" lagi → key sama, server me-replay, bukan penjualan baru.
    final idemKey =
        _pendingSaleKey ??= 'pos-${DateTime.now().microsecondsSinceEpoch}-${shift.id}';

    try {
      final created = await ref.read(transactionsApiProvider).create(
        idempotencyKey: idemKey,
        items: lines,
        paymentMethod: method,
        orderType: state.selectedOrderType,
        amountReceived: method == PaymentMethod.cash ? amountReceived : null,
        discount: state.discount,
        tableId: dineIn ? _tableIdFor(state.tableLabel) : null,
        customerNote: dineIn ? '' : state.customerName,
        discountApprovedBy: state.discountApprovedBy,
        supervisorPin: _discountSupervisorPin,
      );

      // Struk dibangun dari nilai SERVER-authoritative (subtotal/layanan/PPN/total/kembalian) agar sama persis dengan backend.
      final transaction = SaleTransaction(
        id: created.id,
        code: created.code,
        shiftId: shift.id,
        createdAt: DateTime.now(),
        cashierName: state.cashierName,
        orderType: state.selectedOrderType,
        customerName: dineIn ? '' : state.customerName,
        tableLabel: dineIn ? state.tableLabel : '',
        paymentMethod: method,
        status: TransactionStatus.paid,
        items: state.cart
            .map(
              (item) => TransactionItem(
                productName: item.product.name,
                category: item.product.category,
                quantity: item.quantity,
                price: item.product.price,
                note: item.note,
              ),
            )
            .toList(),
        subtotal: created.subtotal,
        discount: created.discount,
        tax: created.tax,
        serviceCharge: created.serviceCharge,
        gatewayFee: created.gatewayFee,
        serviceLine: created.serviceLine,
        total: created.total,
        amountReceived: created.amountReceived,
        change: created.change,
      );

      _discountSupervisorPin = '';
      _pendingSaleKey = null; // sukses → penjualan berikutnya memakai key baru
      state = state.copyWith(
        currentShift: _shiftAfterSale(shift, transaction),
        transactions: [transaction, ...state.transactions],
        cart: const [],
        discount: 0,
        discountApprovedBy: '',
        customerName: '',
        selectedPaymentMethod: PaymentMethod.cash,
        amountReceived: 0,
        selectedTransaction: transaction,
        lastTransaction: transaction,
        screen: AppScreen.receipt,
      );
      return null;
    } on ApiException catch (e) {
      // Server merespons (bukan time-out) → tidak ter-commit; buang key agar retry tak ditolak sebagai duplikat.
      _pendingSaleKey = null;
      return e.message;
    } catch (_) {
      // Time-out/jaringan: status server tak pasti → TAHAN key, retry akan di-replay bila tadi sempat ter-commit.
      return 'Pembayaran gagal. Coba lagi.';
    }
  }

  // ── Self-orders ────────────────────────────────────────────────────────────

  Future<String?> acceptSelfOrder(String id) async {
    if (!state.hasOpenShift) {
      return 'Buka shift dulu untuk menerima pesanan.';
    }
    try {
      await ref
          .read(selfOrdersApiProvider)
          .updateStatus(id, SelfOrderStatus.preparing);
      final orders = [...state.incomingOrders];
      final index = orders.indexWhere((o) => o.id == id);
      if (index >= 0) {
        orders[index] = orders[index].copyWith(
          status: SelfOrderStatus.preparing,
        );
      }
      state = state.copyWith(incomingOrders: orders);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal memproses pesanan. Coba lagi.';
    }
  }

  Future<String?> completeSelfOrder(String id) async {
    try {
      await ref
          .read(selfOrdersApiProvider)
          .updateStatus(id, SelfOrderStatus.completed);
      state = state.copyWith(
        incomingOrders: state.incomingOrders.where((o) => o.id != id).toList(),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal menyelesaikan pesanan. Coba lagi.';
    }
  }

  /// Tebus pesanan bayar-di-kasir via kode klaim: terima tunai → server tandai lunas & catat transaksi ke shift.
  Future<String?> redeemSelfOrder(String claimCode) async {
    if (claimCode.trim().isEmpty) {
      return 'Masukkan kode tebus.';
    }
    if (!state.hasOpenShift) {
      return 'Buka shift dulu untuk menerima pembayaran.';
    }
    try {
      await ref.read(selfOrdersApiProvider).redeemCheckout(claimCode.trim());
      await _loadShiftData();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal menerima pembayaran. Coba lagi.';
    }
  }

  // ── Transactions list (local view state) ──────────────────────────────────

  void selectTransaction(SaleTransaction? transaction) =>
      state = state.copyWith(selectedTransaction: transaction);

  void setTransactionSearch(String query) =>
      state = state.copyWith(transactionSearch: query);

  void setTransactionStatusFilter(String status) =>
      state = state.copyWith(transactionStatusFilter: status);

  // ── Cetak struk ────────────────────────────────────────────────────────────

  /// Cetak struk sesuai mode aktif; mengembalikan pesan error, atau null bila OK.
  Future<String?> printReceipt(SaleTransaction transaction) async {
    final p = state.printer;
    if (p.mode == PrintMode.bluetooth) {
      if (!p.hasDevice) {
        return 'Pilih printer Bluetooth dulu di Pengaturan Struk.';
      }
      if (!await _thermal.ensureConnected(p.deviceAddress)) {
        _syncConnection();
        return 'Printer Bluetooth tidak tersambung.';
      }
      final printed = await _thermal.printReceipt(
        state.store,
        transaction,
        p.paperWidth,
      );
      _syncConnection();
      return printed ? null : 'Gagal mengirim struk ke printer. Coba lagi.';
    }
    await _printerService.printReceipt(state.store, transaction, p.paperWidth);
    return null;
  }

  /// Bagikan struk sebagai PDF (tersedia di semua mode).
  Future<void> shareReceipt(SaleTransaction transaction) =>
      _printerService.shareReceipt(
        state.store,
        transaction,
        state.printer.paperWidth,
      );

  Future<String?> reprintReceipt(SaleTransaction transaction) async {
    state = state.copyWith(lastTransaction: transaction);
    return printReceipt(transaction);
  }

  /// Void: hanya transaksi TUNAI shift berjalan; kasir wajib [supervisorPin] (diverifikasi server); server restock & keluarkan dari rekap.
  Future<String?> voidTransaction(
    SaleTransaction tx, {
    String reason = '',
    String supervisorPin = '',
  }) async {
    try {
      await ref
          .read(transactionsApiProvider)
          .voidTransaction(txId: tx.id, reason: reason, supervisorPin: supervisorPin);
      final cancelled = tx.copyWith(status: TransactionStatus.cancelled);
      state = state.copyWith(
        transactions: state.transactions
            .map((t) => t.id == tx.id ? cancelled : t)
            .toList(),
        selectedTransaction: state.selectedTransaction?.id == tx.id
            ? cancelled
            : state.selectedTransaction,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal membatalkan transaksi.';
    }
  }

  Future<String?> testPrint() async {
    final p = state.printer;
    if (p.mode == PrintMode.bluetooth) {
      if (!p.hasDevice) return 'Pilih printer Bluetooth dulu.';
      if (!await _thermal.ensureConnected(p.deviceAddress)) {
        _syncConnection();
        return 'Printer Bluetooth tidak tersambung.';
      }
      final printed = await _thermal.printSample(state.store, p.paperWidth);
      _syncConnection();
      return printed ? null : 'Gagal mengirim ke printer. Coba lagi.';
    }
    await _printerService.printSample(state.store, p.paperWidth);
    return null;
  }

  /// Buka laci kas — hanya mode thermal (pulsa via printer).
  Future<String?> openCashDrawer() async {
    final p = state.printer;
    if (p.mode != PrintMode.bluetooth) {
      return 'Buka laci hanya tersedia untuk printer Bluetooth.';
    }
    if (!p.hasDevice) return 'Pilih printer Bluetooth dulu.';
    if (!await _thermal.ensureConnected(p.deviceAddress)) {
      _syncConnection();
      return 'Printer Bluetooth tidak tersambung.';
    }
    final opened = await _thermal.openDrawer();
    _syncConnection();
    return opened ? null : 'Gagal membuka laci. Coba lagi.';
  }

  void setPaperWidth(String paperWidth) {
    final printer = state.printer.copyWith(paperWidth: paperWidth);
    state = state.copyWith(printer: printer);
    _printerSettings.save(printer);
  }

  void setPrintMode(PrintMode mode) {
    final printer = state.printer.copyWith(mode: mode);
    state = state.copyWith(printer: printer);
    _printerSettings.save(printer);
  }

  /// Minta izin Bluetooth (Android 12+); true bila diberikan.
  Future<bool> requestBluetoothPermission() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> get isBluetoothOn => _thermal.isBluetoothOn;

  Future<List<BluetoothInfo>> scanPrinters() => _thermal.pairedDevices();

  Future<String?> selectPrinter(String name, String macAddress) async {
    final ok = await _thermal.connect(macAddress);
    final printer = state.printer.copyWith(
      deviceName: name,
      deviceAddress: macAddress,
      connected: ok,
    );
    state = state.copyWith(printer: printer);
    await _printerSettings.save(printer);
    return ok ? null : 'Gagal menyambung ke $name. Coba lagi.';
  }

  Future<void> _hydratePrinter() async {
    final saved = await _printerSettings.load();
    final connected =
        saved.mode == PrintMode.bluetooth ? await _thermal.isConnected : false;
    state = state.copyWith(printer: saved.copyWith(connected: connected));
  }

  Future<void> _syncConnection() async {
    final connected = await _thermal.isConnected;
    if (connected != state.printer.connected) {
      state = state.copyWith(
        printer: state.printer.copyWith(connected: connected),
      );
    }
  }

  // ── Cash movements ─────────────────────────────────────────────────────────

  Future<String?> addCashMovement({
    required CashMovementType type,
    required int amount,
    String notes = '',
    String approvedBy = '',
  }) async {
    final shift = state.currentShift;
    if (shift == null) {
      return 'Tidak ada shift aktif.';
    }
    try {
      final movement = await ref.read(cashMovementsApiProvider).create(
        type: type,
        amount: amount,
        notes: notes,
        approvedBy: approvedBy,
        createdBy: state.cashierName,
      );
      state = state.copyWith(
        cashMovements: [movement, ...state.cashMovements],
        currentShift: _shiftAfterMovement(
          shift,
          type,
          _normalizeMovementAmount(type, amount),
        ),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal mencatat mutasi kas. Coba lagi.';
    }
  }

  // ── Local shift running-total helpers (for live display only) ─────────────

  Shift _shiftAfterSale(Shift shift, SaleTransaction transaction) {
    switch (transaction.paymentMethod) {
      case PaymentMethod.cash:
        return shift.copyWith(cashSales: shift.cashSales + transaction.total);
      case PaymentMethod.qris:
        return shift.copyWith(qrisSales: shift.qrisSales + transaction.total);
    }
  }

  Shift _shiftAfterMovement(
    Shift shift,
    CashMovementType type,
    int normalizedAmount,
  ) {
    switch (type) {
      case CashMovementType.initialCapital:
        return shift;
      case CashMovementType.additionalCapital:
        return shift.copyWith(
          additionalCapital: shift.additionalCapital + normalizedAmount,
        );
      case CashMovementType.ownerWithdrawal:
        return shift.copyWith(
          withdrawals: shift.withdrawals + normalizedAmount.abs(),
        );
      case CashMovementType.operationalExpense:
        return shift.copyWith(expenses: shift.expenses + normalizedAmount.abs());
      case CashMovementType.cashAdjustment:
        return shift.copyWith(adjustments: shift.adjustments + normalizedAmount);
      case CashMovementType.manualDrawerOpen:
        return shift.copyWith(drawerOpenCount: shift.drawerOpenCount + 1);
    }
  }

  int _normalizeMovementAmount(CashMovementType type, int amount) {
    switch (type) {
      case CashMovementType.initialCapital:
      case CashMovementType.additionalCapital:
        return amount.abs();
      case CashMovementType.ownerWithdrawal:
      case CashMovementType.operationalExpense:
        return -amount.abs();
      case CashMovementType.cashAdjustment:
        return amount;
      case CashMovementType.manualDrawerOpen:
        return 0;
    }
  }
}

const _unset = Object();
