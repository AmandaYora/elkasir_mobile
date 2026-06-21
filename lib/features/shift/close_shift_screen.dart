import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/supervisor_approval_dialog.dart';
import '../app_controller.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final shift = state.currentShift;

    if (shift == null || shift.status != ShiftStatus.open) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: SectionCard(
          child: EmptyState(
            icon: Icons.lock_clock_rounded,
            title: 'Tidak ada shift aktif',
            message: 'Buka shift baru sebelum menutup laci kas.',
          ),
        ),
      );
    }

    // Blind count: tidak ada prefill kas aktual; kasir menghitung fisik dulu.
    final parsedActual = int.tryParse(_actualCashController.text.trim());
    final canClose = parsedActual != null && parsedActual >= 0;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: SectionCard(
              title: 'Tutup Shift',
              subtitle: 'Penutupan shift membutuhkan input kas aktual.',
              expandChild: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _actualCashController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Kas Aktual',
                      prefixIcon: Icon(Icons.payments_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    minLines: 4,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penutupan',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: !canClose
                        ? null
                        : () async {
                            final actualCash = parsedActual;
                            final expectedCash = shift.expectedCash;
                            final variance = actualCash - expectedCash;
                            var approver = '';
                            if (variance.abs() >
                                cashVarianceToleranceWithoutApproval) {
                              final result = await showSupervisorApprovalDialog(
                                context,
                                title: 'Persetujuan Selisih Kas',
                                message:
                                    'Selisih kas melebihi toleransi '
                                    '(${formatIDR(cashVarianceToleranceWithoutApproval)}). '
                                    'Diperlukan persetujuan supervisor untuk '
                                    'menutup shift.',
                              );
                              if (result == null) {
                                return;
                              }
                              approver = result;
                            }
                            if (!context.mounted) {
                              return;
                            }
                            final confirmed = await _confirmClose(
                              context,
                              actualCash,
                              expectedCash,
                              variance,
                            );
                            if (confirmed == true) {
                              final error = await controller.closeShift(
                                actualCash: actualCash,
                                notes: _notesController.text,
                                approvedBy: approver,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error ?? 'Shift ditutup'),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Tutup Shift'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 5,
            child: SectionCard(
              title: 'Hitung Kas Fisik (Blind Count)',
              subtitle:
                  'Hitung seluruh uang fisik di laci, lalu masukkan jumlahnya.',
              expandChild: true,
              child: const EmptyState(
                icon: Icons.calculate_rounded,
                title: 'Perhitungan tertutup',
                message:
                    'Perkiraan kas & selisih sengaja disembunyikan untuk '
                    'mencegah penyesuaian. Rincian rekonsiliasi tampil setelah '
                    'Anda menekan Tutup Shift dan mengonfirmasi.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmClose(
    BuildContext context,
    int actualCash,
    int expectedCash,
    int variance,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutup shift ini?'),
        content: Text(
          'Perkiraan Kas: ${formatIDR(expectedCash)}\n'
          'Kas Aktual: ${formatIDR(actualCash)}\n'
          'Selisih: ${variance >= 0 ? '+' : ''}${formatIDR(variance)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup Shift'),
          ),
        ],
      ),
    );
  }
}
