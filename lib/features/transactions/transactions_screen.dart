import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/supervisor_approval_dialog.dart';
import '../app_controller.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final transactions = state.visibleTransactions;
    final selected =
        state.selectedTransaction ??
        (transactions.isNotEmpty ? transactions.first : null);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: SectionCard(
              title: 'Riwayat Transaksi',
              subtitle: '${transactions.length} transaksi pada shift aktif',
              padding: EdgeInsets.zero,
              expandChild: true,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: controller.setTransactionSearch,
                            decoration: const InputDecoration(
                              hintText:
                                  'Cari kode, staf, jenis pesanan, atau metode',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<String>(
                            value: state.transactionStatusFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items:
                                const [
                                      'Semua',
                                      'Lunas',
                                      'Dibatalkan',
                                      'Dikembalikan',
                                    ]
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) => controller
                                .setTransactionStatusFilter(value ?? 'Semua'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: transactions.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Transaksi tidak ditemukan',
                            message: 'Sesuaikan pencarian atau filter status.',
                          )
                        : ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              final active = selected?.id == transaction.id;
                              return _TransactionRow(
                                transaction: transaction,
                                active: active,
                                onTap: () =>
                                    controller.selectTransaction(transaction),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: selected == null
                ? const SectionCard(
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Belum ada detail',
                      message: 'Pilih transaksi untuk melihat detail.',
                    ),
                  )
                : _TransactionDetail(transaction: selected),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.active,
    required this.onTap,
  });

  final SaleTransaction transaction;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: active ? AppColors.primarySoft : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: active ? Colors.white : AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                transaction.paymentMethod == PaymentMethod.cash
                    ? Icons.payments_rounded
                    : Icons.qr_code_rounded,
                color: active ? AppColors.primary : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.code,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatDateTime(transaction.createdAt)} - ${transaction.orderType.label} - ${transaction.cashierName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(label: transaction.paymentMethod.label),
            const SizedBox(width: 10),
            Text(
              formatIDR(transaction.total),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetail extends ConsumerWidget {
  const _TransactionDetail({required this.transaction});

  final SaleTransaction transaction;

  // Void: konfirmasi → kasir wajib PIN supervisor → panggil controller.
  Future<void> _void(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan ${transaction.code}?'),
        content: const Text(
          'Stok item dikembalikan dan transaksi dikeluarkan dari rekap shift. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var pin = '';
    if (!ref.read(appControllerProvider).isSupervisor) {
      final approval = await showSupervisorApprovalDialog(
        context,
        title: 'Persetujuan Pembatalan',
        message:
            'Pembatalan transaksi ${transaction.code} memerlukan PIN supervisor.',
      );
      if (approval == null) return;
      pin = approval.pin;
    }
    if (!context.mounted) return;
    final error = await ref
        .read(appControllerProvider.notifier)
        .voidTransaction(transaction, supervisorPin: pin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Transaksi dibatalkan')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    final canVoid =
        transaction.status == TransactionStatus.paid &&
        transaction.paymentMethod == PaymentMethod.cash;
    return SectionCard(
      title: transaction.code,
      subtitle: formatDateTime(transaction.createdAt),
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(label: transaction.status.label),
              StatusPill(label: transaction.paymentMethod.label),
              StatusPill(label: transaction.orderType.label),
              Text(
                formatIDR(transaction.total),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: transaction.items.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, index) {
                final item = transaction.items[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${item.quantity} x ${formatIDR(item.price)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Text(formatIDR(item.lineTotal)),
                  ],
                );
              },
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
            label: 'Jenis Pesanan',
            value: transaction.orderType.label,
          ),
          if (transaction.tableLabel.isNotEmpty)
            KeyValueRow(label: 'Meja', value: transaction.tableLabel),
          if (transaction.customerName.isNotEmpty)
            KeyValueRow(label: 'Pelanggan', value: transaction.customerName),
          KeyValueRow(
            label: 'Total Dibayar',
            value: formatIDR(transaction.total),
            bold: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final error = await controller.reprintReceipt(transaction);
                    if (context.mounted && error != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Cetak Ulang'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    controller.selectTransaction(transaction);
                    controller.navigate(AppScreen.receipt);
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Pratinjau'),
                ),
              ),
            ],
          ),
          if (canVoid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _void(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: const BorderSide(color: AppColors.destructive),
                ),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Batalkan Transaksi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
