import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _cashController = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    if (state.cart.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: SectionCard(
          child: EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Tidak ada pesanan aktif',
            message: 'Kembali ke Kasir dan tambah menu sebelum membayar.',
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
              title: 'Ringkasan Pesanan',
              subtitle: '${state.totalItems} item siap dibayar',
              expandChild: true,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final item = state.cart[index];
                        return Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${item.quantity} x ${formatIDR(item.product.price)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
                                  ),
                                  if (item.note.isNotEmpty)
                                    Text(
                                      item.note,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.accentWarm,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              formatIDR(item.lineTotal),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  KeyValueRow(
                    label: 'Subtotal',
                    value: formatIDR(state.subtotal),
                  ),
                  KeyValueRow(
                    label: 'Diskon',
                    value: state.discount == 0
                        ? formatIDR(0)
                        : '-${formatIDR(state.discount)}',
                    valueColor: state.discount == 0 ? null : AppColors.success,
                  ),
                  if (state.serviceLine > 0)
                    KeyValueRow(
                      label: 'Layanan',
                      value: formatIDR(state.serviceLine),
                    ),
                  if (state.tax > 0)
                    KeyValueRow(label: 'PPN', value: formatIDR(state.tax)),
                  KeyValueRow(
                    label: 'Total',
                    value: formatIDR(state.total),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: SectionCard(
              title: 'Metode Pembayaran',
              subtitle:
                  'Tunai memengaruhi kas laci. QRIS diterima di luar laci kas.',
              expandChild: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: PaymentMethod.values.map((method) {
                      final selected = state.selectedPaymentMethod == method;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                controller.setPaymentMethod(method),
                            icon: Icon(_paymentIcon(method)),
                            label: Text(method.label),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selected
                                  ? AppColors.primarySoft
                                  : Colors.white,
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Expanded(child: _paymentBody(state)),
                  const Divider(),
                  KeyValueRow(
                    label: 'Total Tagihan',
                    value: formatIDR(state.total),
                    bold: true,
                  ),
                  if (state.selectedPaymentMethod == PaymentMethod.cash)
                    KeyValueRow(
                      label: 'Kembalian',
                      value: formatIDR(
                        state.cashChange > 0 ? state.cashChange : 0,
                      ),
                      valueColor: AppColors.success,
                      bold: true,
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => controller.navigate(AppScreen.pos),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Kembali'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _processing
                              ? null
                              : () => _completePayment(state),
                          icon: _processing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(_buttonLabel(state)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBody(PosAppState state) {
    final controller = ref.read(appControllerProvider.notifier);
    switch (state.selectedPaymentMethod) {
      case PaymentMethod.cash:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              onChanged: (value) =>
                  controller.setAmountReceived(int.tryParse(value) ?? 0),
              decoration: const InputDecoration(
                labelText: 'Uang Diterima',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>{state.total, 50000, 100000, 150000, 200000}
                  .map(
                    (amount) => ActionChip(
                      label: Text(formatIDR(amount)),
                      onPressed: () {
                        _cashController.text = amount.toString();
                        controller.setAmountReceived(amount);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case PaymentMethod.qris:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'QRIS Statis',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Minta pelanggan scan QRIS di meja kasir, masukkan nominal '
                '${formatIDR(state.total)}, lalu bayar. Setelah memeriksa bukti '
                'pembayaran, tekan "Lunas" untuk menyelesaikan transaksi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _completePayment(PosAppState state) async {
    final controller = ref.read(appControllerProvider.notifier);
    setState(() => _processing = true);
    final error = await controller.completePayment();
    setState(() => _processing = false);
    if (!mounted) {
      return;
    }
    // On success the controller navigates to the receipt screen.
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _buttonLabel(PosAppState state) {
    switch (state.selectedPaymentMethod) {
      case PaymentMethod.cash:
        return 'Bayar Tunai';
      case PaymentMethod.qris:
        return 'Lunas';
    }
  }

  IconData _paymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.qris:
        return Icons.qr_code_rounded;
    }
  }
}
