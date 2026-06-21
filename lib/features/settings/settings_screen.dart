import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(
                  child: SectionCard(
                    title: 'Profil Toko',
                    subtitle:
                        'Profil usaha yang terhubung dengan Elkasir Admin.',
                    expandChild: true,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const AppLogoMark(size: 68),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.store.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      state.store.outlet,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          KeyValueRow(
                            label: 'Jenis Usaha',
                            value: state.store.businessType.label,
                          ),
                          KeyValueRow(
                            label: 'Nomor Telepon',
                            value: state.store.phone,
                          ),
                          KeyValueRow(
                            label: 'Alamat',
                            value: state.store.address,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SectionCard(
                    title: 'Profil Staf',
                    subtitle:
                        'Keluar tidak menutup shift — modal awal tetap tersimpan.',
                    expandChild: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyValueRow(label: 'Nama', value: state.cashierName),
                        KeyValueRow(
                          label: 'Peran',
                          value: state.cashierRole.label,
                        ),
                        KeyValueRow(
                          label: 'Shift Aktif',
                          value:
                              state.currentShift?.status.label ?? 'Tidak ada',
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: controller.logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Keluar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: SectionCard(
              title: 'Pratinjau Struk',
              subtitle: 'Footer dan tata letak mengikuti pengaturan admin.',
              expandChild: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: Container(
                          width: 290,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.restaurant_menu_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                state.store.name.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                state.store.outlet,
                                style: const TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 12,
                                ),
                              ),
                              const Divider(),
                              _ReceiptSampleRow(
                                '1 x Chicken Teriyaki Rice',
                                formatIDR(52000),
                              ),
                              _ReceiptSampleRow(
                                '2 x Iced Tea',
                                formatIDR(36000),
                              ),
                              const Divider(),
                              _ReceiptSampleRow(
                                'TOTAL',
                                formatIDR(88000),
                                bold: true,
                              ),
                              _ReceiptSampleRow('QRIS', formatIDR(88000)),
                              const Divider(),
                              const Text(
                                'Terima kasih telah berkunjung',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  KeyValueRow(
                    label: 'Versi Aplikasi',
                    value: '1.0.0',
                  ),
                  KeyValueRow(label: 'Status', value: 'Online'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSampleRow extends StatelessWidget {
  const _ReceiptSampleRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
