import 'package:flutter/material.dart';
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

    return Padding(
      padding: const EdgeInsets.all(18),
      child: SectionCard(
        title: 'Pesanan Masuk',
        subtitle: 'Self-order pelanggan via QR meja — QRIS sudah lunas.',
        padding: EdgeInsets.zero,
        expandChild: true,
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
                    onAccept: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await controller.acceptSelfOrder(order.id);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                    onComplete: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await controller.completeSelfOrder(order.id);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onAccept,
    required this.onComplete,
  });

  final SelfOrder order;
  final VoidCallback onAccept;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final isNew = order.status == SelfOrderStatus.placed;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
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
                child: const Icon(
                  Icons.table_restaurant_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meja ${order.tableName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${formatTime(order.createdAt)} · ${order.items.length} item',
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: order.status.label),
              const SizedBox(width: 8),
              const StatusPill(label: 'QRIS Lunas'),
            ],
          ),
          const Divider(height: 20),
          ...order.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${it.quantity}×',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
              Text(
                formatIDR(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isNew)
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
