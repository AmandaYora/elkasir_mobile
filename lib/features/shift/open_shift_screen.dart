import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class OpenShiftScreen extends ConsumerStatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  ConsumerState<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends ConsumerState<OpenShiftScreen> {
  final _initialCashController = TextEditingController(text: '500000');
  final _notesController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _initialCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openShift(int initialCash) async {
    setState(() => _busy = true);
    final error = await ref
        .read(appControllerProvider.notifier)
        .openShift(initialCash: initialCash, notes: _notesController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final initialCash = int.tryParse(_initialCashController.text) ?? 0;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppLogoMark(size: 46),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.store.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${state.store.outlet} terminal POS',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: SectionCard(
                      title: 'Buka Shift',
                      subtitle:
                          'Staf tidak dapat membuka Kasir sebelum shift dibuka.',
                      expandChild: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _initialCashController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Kas Awal',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _notesController,
                            minLines: 4,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Catatan',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: (initialCash <= 0 || _busy)
                                ? null
                                : () => _openShift(initialCash),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(
                              _busy ? 'Membuka…' : 'Buka Shift & Masuk Kasir',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: 'Staf',
                            value: state.cashierName,
                            icon: Icons.person_rounded,
                            accent: AppColors.primary,
                            softAccent: AppColors.primarySoft,
                            caption: 'Profil aktif',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: MetricTile(
                            label: 'Jenis Usaha',
                            value: state.store.businessType.label,
                            icon: Icons.restaurant_rounded,
                            accent: AppColors.accentWarm,
                            softAccent: AppColors.accentWarmSoft,
                            caption: 'Diatur oleh admin',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: MetricTile(
                            label: 'Kas Awal',
                            value: formatIDR(initialCash),
                            icon: Icons.payments_rounded,
                            accent: AppColors.success,
                            softAccent: AppColors.successSoft,
                            caption: 'Dicatat sebagai Modal Awal',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: MetricTile(
                            label: 'Aturan Usaha',
                            value: 'Wajib buka shift',
                            icon: Icons.verified_user_rounded,
                            accent: AppColors.warning,
                            softAccent: AppColors.warningSoft,
                            caption: 'Setiap transaksi terikat pada shift',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
