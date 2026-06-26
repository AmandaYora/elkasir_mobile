import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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

  // Hitung per pecahan (opsional): mengurangi salah hitung kas saat tutup shift.
  static const _denoms = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100];
  final Map<int, int> _denomCounts = {};
  bool _denomOpen = false;
  int get _denomTotal =>
      _denoms.fold(0, (sum, d) => sum + d * (_denomCounts[d] ?? 0));

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
              subtitle: 'Masukkan kas aktual untuk menutup shift.',
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _denomOpen = !_denomOpen),
                      icon: Icon(
                        _denomOpen ? Icons.expand_less_rounded : Icons.calculate_rounded,
                        size: 18,
                      ),
                      label: const Text('Hitung per pecahan'),
                    ),
                  ),
                  if (_denomOpen) _DenominationTally(
                    denoms: _denoms,
                    counts: _denomCounts,
                    total: _denomTotal,
                    onChanged: (denom, count) {
                      setState(() {
                        if (count <= 0) {
                          _denomCounts.remove(denom);
                        } else {
                          _denomCounts[denom] = count;
                        }
                        _actualCashController.text = _denomTotal.toString();
                      });
                    },
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
                            var approverPin = '';
                            final tol = state.cashVarianceTolerance;
                            if (variance.abs() > tol) {
                              // Supervisor menutup langsung; kasir butuh PIN supervisor.
                              if (state.isSupervisor) {
                                approver = state.cashierName;
                              } else {
                                final result =
                                    await showSupervisorApprovalDialog(
                                  context,
                                  title: 'Persetujuan Selisih Kas',
                                  message:
                                      'Selisih kas melebihi toleransi '
                                      '(${formatIDR(tol)}). '
                                      'Diperlukan PIN supervisor untuk '
                                      'menutup shift.',
                                );
                                if (result == null) {
                                  return;
                                }
                                approver = result.name;
                                approverPin = result.pin;
                              }
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
                                supervisorPin: approverPin,
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
              title: 'Hitung Kas Fisik',
              subtitle:
                  'Hitung seluruh uang fisik di laci, lalu masukkan jumlahnya.',
              expandChild: true,
              child: const EmptyState(
                icon: Icons.calculate_rounded,
                title: 'Perhitungan tertutup',
                message:
                    'Perkiraan kas dan selisih sengaja disembunyikan agar '
                    'tidak memengaruhi hitungan. Rinciannya tampil setelah '
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

/// Tally per pecahan: jumlah tiap pecahan otomatis mengisi "Kas Aktual" — mengurangi salah hitung manual.
class _DenominationTally extends StatelessWidget {
  const _DenominationTally({
    required this.denoms,
    required this.counts,
    required this.total,
    required this.onChanged,
  });

  final List<int> denoms;
  final Map<int, int> counts;
  final int total;
  final void Function(int denom, int count) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final d in denoms)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      formatIDR(d),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×', style: TextStyle(color: AppColors.mutedForeground)),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      key: ValueKey('denom-$d'),
                      initialValue: (counts[d] ?? 0) > 0 ? '${counts[d]}' : '',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                      onChanged: (v) => onChanged(d, int.tryParse(v) ?? 0),
                    ),
                  ),
                  const Spacer(),
                  Text(formatIDR(d * (counts[d] ?? 0))),
                ],
              ),
            ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total hitungan', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(formatIDR(total), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
