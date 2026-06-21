import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../services/receipt_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  const ReceiptPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final transaction = state.lastTransaction ?? state.selectedTransaction;

    if (transaction == null) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: SectionCard(
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada struk dipilih',
            message:
                'Selesaikan pembayaran atau pilih transaksi untuk pratinjau.',
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: SectionCard(
              title: 'Transaksi Berhasil',
              subtitle:
                  '${transaction.code} selesai dengan ${transaction.paymentMethod.label}',
              expandChild: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StatusPill(label: transaction.status.label),
                      const Spacer(),
                      Text(
                        formatIDR(transaction.total),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final error = await controller.printReceipt(
                              transaction,
                            );
                            if (context.mounted && error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error)),
                              );
                            }
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Cetak Struk'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await controller.shareReceipt(transaction);
                          },
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Bagikan Struk'),
                        ),
                        if (state.printer.mode == PrintMode.bluetooth) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final error = await controller.openCashDrawer();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error ?? 'Laci kas terbuka'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.point_of_sale_rounded),
                            label: const Text('Buka Laci Kas'),
                          ),
                        ],
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => controller.navigate(AppScreen.pos),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Pesanan Baru'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: _ReceiptPaper(store: state.store, transaction: transaction),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPaper extends StatelessWidget {
  const _ReceiptPaper({required this.store, required this.transaction});

  final StoreProfile store;
  final SaleTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final receiptText = ReceiptService().buildPlainTextReceipt(
      store,
      transaction,
    );

    return SectionCard(
      title: 'Pratinjau Struk',
      subtitle: 'Struk yang akan dicetak',
      expandChild: true,
      child: Center(
        child: Container(
          width: 330,
          constraints: const BoxConstraints(maxHeight: double.infinity),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
                const SizedBox(height: 8),
                Text(
                  store.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  store.address,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                KeyValueRow(label: 'Transaksi', value: transaction.code),
                KeyValueRow(
                  label: 'Tanggal',
                  value: formatDateTime(transaction.createdAt),
                ),
                KeyValueRow(label: 'Staf', value: transaction.cashierName),
                KeyValueRow(
                  label: 'Jenis Pesanan',
                  value: transaction.orderType.label,
                ),
                if (transaction.tableLabel.isNotEmpty)
                  KeyValueRow(label: 'Meja', value: transaction.tableLabel),
                if (transaction.customerName.isNotEmpty)
                  KeyValueRow(
                    label: 'Pelanggan',
                    value: transaction.customerName,
                  ),
                const Divider(),
                ...transaction.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} x ${item.productName}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(formatIDR(item.lineTotal)),
                          ],
                        ),
                        if (item.note.isNotEmpty)
                          Text(
                            item.note,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                KeyValueRow(
                  label: 'Subtotal',
                  value: formatIDR(transaction.subtotal),
                ),
                if (transaction.discount > 0)
                  KeyValueRow(
                    label: 'Diskon',
                    value: '-${formatIDR(transaction.discount)}',
                  ),
                if (transaction.serviceLine > 0)
                  KeyValueRow(
                    label: 'Layanan',
                    value: formatIDR(transaction.serviceLine),
                  ),
                if (transaction.tax > 0)
                  KeyValueRow(label: 'PPN', value: formatIDR(transaction.tax)),
                KeyValueRow(
                  label: 'Total',
                  value: formatIDR(transaction.total),
                  bold: true,
                ),
                KeyValueRow(
                  label: 'Pembayaran',
                  value: transaction.paymentMethod.label,
                ),
                KeyValueRow(
                  label: 'Kembalian',
                  value: formatIDR(transaction.change),
                ),
                const Divider(),
                Text(
                  'Terima kasih telah berkunjung',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Teks Struk'),
                  children: [
                    SelectableText(
                      receiptText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
