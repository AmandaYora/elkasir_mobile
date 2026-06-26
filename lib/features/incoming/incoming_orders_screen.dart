import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class IncomingOrdersScreen extends ConsumerWidget {
  const IncomingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final orders = state.incomingOrders;

    Future<void> snack(String? error, [String ok = 'Berhasil']) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? ok)));
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: SectionCard(
        title: 'Pesanan Masuk',
        subtitle:
            'Pesanan dari QR meja. QRIS otomatis lunas; "bayar di kasir" perlu ditebus.',
        padding: EdgeInsets.zero,
        expandChild: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _showRedeemDialog(context, ref),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Tebus Kode'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? const EmptyState(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Belum ada pesanan masuk',
                      message: 'Pesanan dari QR meja akan muncul di sini.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _OrderCard(
                          order: order,
                          onAccept: () async =>
                              snack(await controller.acceptSelfOrder(order.id), 'Pesanan diterima'),
                          onComplete: () async => snack(
                              await controller.completeSelfOrder(order.id), 'Pesanan selesai'),
                          onRedeem: () async => snack(
                              await controller.redeemSelfOrder(order.claimCode),
                              'Pembayaran tunai diterima'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tebus manual: kasir ketik/scan kode klaim pelanggan untuk menerima tunai.
Future<void> _showRedeemDialog(BuildContext context, WidgetRef ref) async {
  final codeController = TextEditingController();
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          if (busy) return;
          setState(() {
            busy = true;
            error = null;
          });
          final err = await ref
              .read(appControllerProvider.notifier)
              .redeemSelfOrder(codeController.text);
          if (!context.mounted) return;
          if (err == null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pembayaran tunai diterima')),
            );
          } else {
            setState(() {
              busy = false;
              error = err;
            });
          }
        }

        return AlertDialog(
          title: const Text('Tebus Kode'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Scan atau ketik kode tebus dari struk pelanggan.'),
                const SizedBox(height: 14),
                TextField(
                  controller: codeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'Kode tebus',
                    hintText: 'mis. ELK-A1-3F9C2',
                    prefixIcon: Icon(Icons.qr_code_rounded),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(
                          color: AppColors.destructive, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments_rounded),
              label: Text(busy ? 'Memproses…' : 'Terima Tunai'),
            ),
          ],
        );
      },
    ),
  );
}

/// Memaksa input huruf besar (kode tebus seragam).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onAccept,
    required this.onComplete,
    required this.onRedeem,
  });

  final SelfOrder order;
  final VoidCallback onAccept;
  final VoidCallback onComplete;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final isNew = order.status == SelfOrderStatus.placed;
    final awaitingCash = order.awaitingCashPayment;
    // Pill pembayaran yang JUJUR (bukan hardcode "QRIS Lunas").
    final payLabel = order.isPaid
        ? (order.paymentMethod == PaymentMethod.qris ? 'QRIS Lunas' : 'Tunai Lunas')
        : 'Belum Bayar';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: awaitingCash ? AppColors.primary : AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meja ${order.tableName}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    Text(
                      '${formatTime(order.createdAt)} · ${order.items.length} item',
                      style: const TextStyle(
                          color: AppColors.mutedForeground, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusPill(label: order.status.label),
              const SizedBox(width: 8),
              StatusPill(label: payLabel),
            ],
          ),
          if (awaitingCash && order.claimCode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    'Kode tebus: ${order.claimCode}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          ...order.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('${it.quantity}×',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(it.productName)),
                  Text(formatIDR(it.lineTotal)),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(formatIDR(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          // Bayar-di-kasir belum lunas → kasir HARUS menerima tunai dulu (tidak bisa "Selesai").
          if (awaitingCash)
            FilledButton.icon(
              onPressed: onRedeem,
              icon: const Icon(Icons.payments_rounded),
              label: Text('Terima Pembayaran Tunai · ${formatIDR(order.total)}'),
            )
          else if (isNew)
            FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Terima Pesanan'),
            )
          else
            OutlinedButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Tandai Selesai'),
            ),
        ],
      ),
    );
  }
}
