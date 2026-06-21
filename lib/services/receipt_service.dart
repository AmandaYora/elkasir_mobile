import '../core/utils/formatters.dart';
import '../models/pos_models.dart';

class ReceiptService {
  String buildPlainTextReceipt(
    StoreProfile store,
    SaleTransaction transaction,
  ) {
    final buffer = StringBuffer()
      ..writeln(store.name.toUpperCase())
      ..writeln('${store.outlet} - ${store.phone}')
      ..writeln(store.address)
      ..writeln('--------------------------------')
      ..writeln(transaction.code)
      ..writeln(formatDateTime(transaction.createdAt))
      ..writeln('Staf: ${transaction.cashierName}')
      ..writeln('Pesanan: ${transaction.orderType.label}')
      ..write(
        transaction.tableLabel.isEmpty
            ? ''
            : 'Meja: ${transaction.tableLabel}\n',
      )
      ..write(
        transaction.customerName.isEmpty
            ? ''
            : 'Pelanggan: ${transaction.customerName}\n',
      )
      ..writeln('--------------------------------');

    for (final item in transaction.items) {
      buffer.writeln(
        '${item.quantity} x ${item.productName} ${formatIDR(item.lineTotal)}',
      );
      if (item.note.isNotEmpty) {
        buffer.writeln('  Catatan: ${item.note}');
      }
    }

    buffer
      ..writeln('--------------------------------')
      ..writeln('Subtotal: ${formatIDR(transaction.subtotal)}');
    if (transaction.discount > 0) {
      buffer.writeln('Diskon: -${formatIDR(transaction.discount)}');
    }
    if (transaction.serviceLine > 0) {
      buffer.writeln('Layanan: ${formatIDR(transaction.serviceLine)}');
    }
    if (transaction.tax > 0) {
      buffer.writeln('PPN: ${formatIDR(transaction.tax)}');
    }
    buffer
      ..writeln('Total: ${formatIDR(transaction.total)}')
      ..writeln('Pembayaran: ${transaction.paymentMethod.label}')
      ..writeln('Kembalian: ${formatIDR(transaction.change)}')
      ..writeln('--------------------------------')
      ..writeln('Terima kasih telah berkunjung');

    return buffer.toString();
  }
}
