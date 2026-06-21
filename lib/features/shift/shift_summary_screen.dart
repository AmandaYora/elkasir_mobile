import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class ShiftSummaryScreen extends ConsumerWidget {
  const ShiftSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final shift = state.currentShift;

    if (shift == null) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: SectionCard(
          child: EmptyState(
            icon: Icons.schedule_rounded,
            title: 'Belum ada shift dipilih',
            message: 'Buka shift untuk melihat operasional staf.',
          ),
        ),
      );
    }

    final shiftTransactions = state.transactions
        .where((tx) => tx.shiftId == shift.id)
        .toList();
    final variance = shift.variance;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Penjualan Tunai',
                    value: formatIDR(shift.cashSales),
                    icon: Icons.payments_rounded,
                    accent: AppColors.success,
                    softAccent: AppColors.successSoft,
                    caption: 'Menambah kas laci',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Penjualan QRIS',
                    value: formatIDR(shift.qrisSales),
                    icon: Icons.qr_code_rounded,
                    accent: AppColors.primary,
                    softAccent: AppColors.primarySoft,
                    caption: 'Tidak menambah kas laci',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Perkiraan Kas',
                    value: shift.status == ShiftStatus.open
                        ? '•••'
                        : formatIDR(shift.expectedCash),
                    icon: Icons.account_balance_wallet_rounded,
                    accent: AppColors.warning,
                    softAccent: AppColors.warningSoft,
                    caption: shift.status == ShiftStatus.open
                        ? 'Tampil setelah tutup shift (blind count)'
                        : 'Kas awal + penjualan tunai + modal - pengeluaran',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Selisih',
                    value: variance == null
                        ? 'Aktif'
                        : '${variance >= 0 ? '+' : ''}${formatIDR(variance)}',
                    icon: Icons.scale_rounded,
                    accent: variance == null || variance == 0
                        ? AppColors.success
                        : AppColors.destructive,
                    softAccent: variance == null || variance == 0
                        ? AppColors.successSoft
                        : AppColors.destructiveSoft,
                    caption: shift.status.label,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: SectionCard(
                    title: 'Rekonsiliasi Kas',
                    subtitle:
                        'Perkiraan Kas = Kas Awal + Penjualan Tunai + Modal Tambahan - Biaya - Penarikan',
                    expandChild: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusPill(label: shift.status.label),
                                ),
                                const SizedBox(height: 16),
                                KeyValueRow(
                                  label: 'Staf',
                                  value: shift.cashierName,
                                ),
                                KeyValueRow(
                                  label: 'Dibuka',
                                  value: formatDateTime(shift.openedAt),
                                ),
                                if (shift.closedAt != null)
                                  KeyValueRow(
                                    label: 'Ditutup',
                                    value: formatDateTime(shift.closedAt!),
                                  ),
                                const Divider(),
                                KeyValueRow(
                                  label: 'Kas Awal',
                                  value: formatIDR(shift.initialCash),
                                ),
                                KeyValueRow(
                                  label: 'Penjualan Tunai',
                                  value: formatIDR(shift.cashSales),
                                ),
                                KeyValueRow(
                                  label: 'Modal Tambahan',
                                  value: formatIDR(shift.additionalCapital),
                                ),
                                KeyValueRow(
                                  label: 'Biaya Operasional',
                                  value: '-${formatIDR(shift.expenses)}',
                                ),
                                KeyValueRow(
                                  label: 'Penarikan Pemilik',
                                  value: '-${formatIDR(shift.withdrawals)}',
                                ),
                                KeyValueRow(
                                  label: 'Penyesuaian Kas',
                                  value:
                                      '${shift.adjustments >= 0 ? '+' : ''}${formatIDR(shift.adjustments)}',
                                ),
                                const Divider(),
                                KeyValueRow(
                                  label: 'Perkiraan Kas',
                                  value: shift.status == ShiftStatus.open
                                      ? '••• (tutup shift untuk lihat)'
                                      : formatIDR(shift.expectedCash),
                                  bold: true,
                                ),
                                KeyValueRow(
                                  label: 'Kas Aktual',
                                  value: shift.actualCash == null
                                      ? '-'
                                      : formatIDR(shift.actualCash!),
                                  bold: true,
                                ),
                                KeyValueRow(
                                  label: 'Jumlah Buka Laci Manual',
                                  value: '${shift.drawerOpenCount}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (shift.status == ShiftStatus.open)
                          FilledButton.icon(
                            onPressed: () =>
                                controller.navigate(AppScreen.closeShift),
                            icon: const Icon(Icons.lock_clock_rounded),
                            label: const Text('Tutup Shift'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: controller.startNewShift,
                            icon: const Icon(Icons.lock_open_rounded),
                            label: const Text('Buka Shift Baru'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
                  child: SectionCard(
                    title: 'Transaksi Shift',
                    subtitle:
                        '${shiftTransactions.length} transaksi di shift ini',
                    padding: EdgeInsets.zero,
                    expandChild: true,
                    child: shiftTransactions.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Belum ada transaksi shift',
                            message:
                                'Penjualan yang selesai akan muncul di sini.',
                          )
                        : ListView.separated(
                            itemCount: shiftTransactions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final transaction = shiftTransactions[index];
                              return ListTile(
                                leading: Icon(
                                  transaction.paymentMethod ==
                                          PaymentMethod.cash
                                      ? Icons.payments_rounded
                                      : Icons.qr_code_rounded,
                                ),
                                title: Text(transaction.code),
                                subtitle: Text(
                                  '${formatDateTime(transaction.createdAt)} - ${transaction.orderType.label} - ${transaction.paymentMethod.label}',
                                ),
                                trailing: Text(
                                  formatIDR(transaction.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onTap: () {
                                  controller.selectTransaction(transaction);
                                  controller.navigate(AppScreen.receipt);
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
