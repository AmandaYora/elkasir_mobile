import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/formatters.dart';
import '../models/pos_models.dart';

/// Cetak struk NYATA: merender struk menjadi PDF lalu mengirimnya ke dialog cetak
/// bawaan perangkat (printer apa pun yang dikenal sistem) atau membagikannya.
/// Tidak memerlukan perangkat keras khusus.
class PrinterService {
  PdfPageFormat _format(String paperWidth) =>
      paperWidth.trim().startsWith('58')
      ? PdfPageFormat.roll57
      : PdfPageFormat.roll80;

  /// Buka dialog cetak sistem untuk struk transaksi.
  Future<void> printReceipt(
    StoreProfile store,
    SaleTransaction transaction,
    String paperWidth,
  ) async {
    final bytes = await _buildReceipt(store, transaction, _format(paperWidth));
    await Printing.layoutPdf(
      name: 'Struk ${transaction.code}',
      onLayout: (_) async => bytes,
    );
  }

  /// Bagikan struk sebagai berkas PDF (WhatsApp, email, simpan, dll).
  Future<void> shareReceipt(
    StoreProfile store,
    SaleTransaction transaction,
    String paperWidth,
  ) async {
    final bytes = await _buildReceipt(store, transaction, _format(paperWidth));
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'struk-${transaction.code}.pdf',
    );
  }

  /// Cetak struk contoh untuk memastikan printer berfungsi.
  Future<void> printSample(StoreProfile store, String paperWidth) async {
    final bytes = await _buildSample(store, _format(paperWidth));
    await Printing.layoutPdf(name: 'Tes Cetak', onLayout: (_) async => bytes);
  }

  pw.Document _doc() => pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.courier(),
      bold: pw.Font.courierBold(),
    ),
  );

  pw.Widget _divider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Text('--------------------------------'),
  );

  pw.Widget _line(String left, String right, {bool bold = false}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Text(
          left,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
      pw.SizedBox(width: 6),
      pw.Text(
        right,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );

  pw.Widget _center(String text, {double size = 8, bool bold = false}) =>
      pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget _header(StoreProfile store) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _center(store.name.toUpperCase(), size: 10, bold: true),
      if (store.outlet.isNotEmpty || store.phone.isNotEmpty)
        _center(
          [store.outlet, store.phone].where((s) => s.isNotEmpty).join(' · '),
        ),
      if (store.address.isNotEmpty) _center(store.address),
    ],
  );

  Future<Uint8List> _buildReceipt(
    StoreProfile store,
    SaleTransaction transaction,
    PdfPageFormat format,
  ) async {
    final doc = _doc();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(store),
            _divider(),
            _line('No.', transaction.code),
            _line('Tanggal', formatDateTime(transaction.createdAt)),
            _line('Kasir', transaction.cashierName),
            _line('Pesanan', transaction.orderType.label),
            if (transaction.tableLabel.isNotEmpty)
              _line('Meja', transaction.tableLabel),
            if (transaction.customerName.isNotEmpty)
              _line('Pelanggan', transaction.customerName),
            _divider(),
            for (final item in transaction.items) ...[
              _line(
                '${item.quantity} x ${item.productName}',
                formatIDR(item.lineTotal),
              ),
              if (item.note.isNotEmpty)
                pw.Text(
                  '  ${item.note}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
            ],
            _divider(),
            _line('Subtotal', formatIDR(transaction.subtotal)),
            if (transaction.discount > 0)
              _line('Diskon', '-${formatIDR(transaction.discount)}'),
            if (transaction.serviceLine > 0)
              _line('Layanan', formatIDR(transaction.serviceLine)),
            if (transaction.tax > 0) _line('PPN', formatIDR(transaction.tax)),
            _line('Total', formatIDR(transaction.total), bold: true),
            _line(
              'Bayar (${transaction.paymentMethod.label})',
              formatIDR(transaction.amountReceived),
            ),
            _line('Kembalian', formatIDR(transaction.change)),
            _divider(),
            _center('Terima kasih telah berkunjung'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _buildSample(
    StoreProfile store,
    PdfPageFormat format,
  ) async {
    final doc = _doc();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(store),
            _divider(),
            _center('TES CETAK', size: 10, bold: true),
            pw.SizedBox(height: 4),
            _center(formatDateTime(DateTime.now())),
            pw.SizedBox(height: 4),
            _center('Printer berfungsi dengan baik.'),
            _divider(),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
