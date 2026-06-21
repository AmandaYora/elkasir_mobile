import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../core/utils/formatters.dart';
import '../models/pos_models.dart';

/// Cetak struk NYATA ke printer thermal ESC/POS via Bluetooth (classic SPP),
/// termasuk perintah buka laci kas (cash drawer kick).
///
/// Catatan: printer harus sudah dipasangkan (paired) di Pengaturan Bluetooth
/// Android terlebih dahulu. Memerlukan perangkat fisik untuk diuji.
class ThermalPrinterService {
  Future<bool> get isBluetoothOn => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<BluetoothInfo>> pairedDevices() =>
      PrintBluetoothThermal.pairedBluetooths;

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String macAddress) =>
      PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

  Future<bool> get disconnect => PrintBluetoothThermal.disconnect;

  PaperSize _size(String paperWidth) =>
      paperWidth.trim().startsWith('58') ? PaperSize.mm58 : PaperSize.mm80;

  /// Pastikan tersambung ke [macAddress]; sambungkan bila belum.
  Future<bool> ensureConnected(String macAddress) async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    if (macAddress.isEmpty) return false;
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> printReceipt(
    StoreProfile store,
    SaleTransaction transaction,
    String paperWidth,
  ) async {
    if (!await PrintBluetoothThermal.connectionStatus) return false;
    final bytes = await _receiptBytes(store, transaction, paperWidth);
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<bool> printSample(StoreProfile store, String paperWidth) async {
    if (!await PrintBluetoothThermal.connectionStatus) return false;
    final profile = await CapabilityProfile.load();
    final gen = Generator(_size(paperWidth), profile);
    final bytes = <int>[
      ..._headerBytes(gen, store),
      ...gen.hr(),
      ...gen.text(
        'TES CETAK',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...gen.text(
        formatDateTime(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...gen.text(
        'Printer berfungsi dengan baik.',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...gen.feed(2),
      ...gen.cut(),
    ];
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Kirim pulsa buka laci kas (RJ11 lewat printer).
  Future<bool> openDrawer() async {
    if (!await PrintBluetoothThermal.connectionStatus) return false;
    final profile = await CapabilityProfile.load();
    final gen = Generator(PaperSize.mm80, profile);
    return PrintBluetoothThermal.writeBytes(gen.drawer());
  }

  List<int> _headerBytes(Generator gen, StoreProfile store) {
    final bytes = <int>[];
    bytes.addAll(
      gen.text(
        store.name.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    final sub = [store.outlet, store.phone].where((s) => s.isNotEmpty).join('  ');
    if (sub.isNotEmpty) {
      bytes.addAll(gen.text(sub, styles: const PosStyles(align: PosAlign.center)));
    }
    if (store.address.isNotEmpty) {
      bytes.addAll(
        gen.text(store.address, styles: const PosStyles(align: PosAlign.center)),
      );
    }
    return bytes;
  }

  Future<List<int>> _receiptBytes(
    StoreProfile store,
    SaleTransaction t,
    String paperWidth,
  ) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(_size(paperWidth), profile);
    final bytes = <int>[];

    bytes.addAll(_headerBytes(gen, store));
    bytes.addAll(gen.hr());

    void kv(String label, String value) {
      bytes.addAll(
        gen.row([
          PosColumn(text: label, width: 5),
          PosColumn(
            text: value,
            width: 7,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    kv('No.', t.code);
    kv('Tanggal', formatDateTime(t.createdAt));
    kv('Kasir', t.cashierName);
    kv('Pesanan', t.orderType.label);
    if (t.tableLabel.isNotEmpty) kv('Meja', t.tableLabel);
    if (t.customerName.isNotEmpty) kv('Pelanggan', t.customerName);
    bytes.addAll(gen.hr());

    for (final item in t.items) {
      bytes.addAll(
        gen.row([
          PosColumn(text: '${item.quantity} x ${item.productName}', width: 8),
          PosColumn(
            text: formatIDR(item.lineTotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      if (item.note.isNotEmpty) {
        bytes.addAll(gen.text('  ${item.note}'));
      }
    }
    bytes.addAll(gen.hr());

    kv('Subtotal', formatIDR(t.subtotal));
    if (t.discount > 0) kv('Diskon', '-${formatIDR(t.discount)}');
    if (t.serviceLine > 0) kv('Layanan', formatIDR(t.serviceLine));
    if (t.tax > 0) kv('PPN', formatIDR(t.tax));
    bytes.addAll(
      gen.row([
        PosColumn(text: 'TOTAL', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: formatIDR(t.total),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    kv('Bayar (${t.paymentMethod.label})', formatIDR(t.amountReceived));
    kv('Kembalian', formatIDR(t.change));
    bytes.addAll(gen.hr());
    bytes.addAll(
      gen.text(
        'Terima kasih telah berkunjung',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(gen.feed(2));
    bytes.addAll(gen.cut());
    return bytes;
  }
}
