import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/supervisor_approval_dialog.dart';
import '../app_controller.dart';

class CashMovementsScreen extends ConsumerWidget {
  const CashMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final shift = state.currentShift;
    final currentMovements = shift == null
        ? state.cashMovements
        : state.cashMovements
              .where((movement) => movement.shiftId == shift.id)
              .toList();
    final cashIn = currentMovements
        .where((movement) => movement.amount > 0)
        .fold(0, (sum, movement) => sum + movement.amount);
    final cashOut = currentMovements
        .where((movement) => movement.amount < 0)
        .fold(0, (sum, movement) => sum + movement.amount.abs());
    final net = cashIn - cashOut;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SizedBox(
            height: 124,
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Kas Masuk',
                    value: formatIDR(cashIn),
                    icon: Icons.arrow_downward_rounded,
                    accent: AppColors.success,
                    softAccent: AppColors.successSoft,
                    caption: 'Modal awal dan tambahan',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Kas Keluar',
                    value: formatIDR(cashOut),
                    icon: Icons.arrow_upward_rounded,
                    accent: AppColors.warning,
                    softAccent: AppColors.warningSoft,
                    caption: 'Biaya dan penarikan',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Mutasi Bersih',
                    value: '${net >= 0 ? '+' : ''}${formatIDR(net)}',
                    icon: Icons.scale_rounded,
                    accent: net >= 0
                        ? AppColors.primary
                        : AppColors.destructive,
                    softAccent: net >= 0
                        ? AppColors.primarySoft
                        : AppColors.destructiveSoft,
                    caption: 'Untuk shift aktif',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SectionCard(
              title: 'Riwayat Mutasi',
              subtitle: 'Semua aktivitas kas fisik di laci',
              actions: FilledButton.icon(
                onPressed: state.hasOpenShift
                    ? () => _showMovementDialog(context, ref)
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Mutasi Baru'),
              ),
              padding: EdgeInsets.zero,
              expandChild: true,
              child: currentMovements.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Belum ada mutasi kas',
                      message: 'Catatan mutasi kas akan muncul di sini.',
                    )
                  : ListView.separated(
                      itemCount: currentMovements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final movement = currentMovements[index];
                        return _MovementRow(movement: movement);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMovementDialog(
    BuildContext context,
    WidgetRef ref, {
    CashMovementType initialType = CashMovementType.additionalCapital,
  }) async {
    var type = initialType;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final amount = int.tryParse(amountController.text) ?? 0;
            final canSave = amount > 0;
            return AlertDialog(
              title: const Text('Mutasi Kas Baru'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<CashMovementType>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Jenis'),
                      items:
                          const [
                                CashMovementType.additionalCapital,
                                CashMovementType.operationalExpense,
                              ]
                              .map(
                                (movementType) => DropdownMenuItem(
                                  value: movementType,
                                  child: Text(movementType.label),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                    if (type == CashMovementType.operationalExpense)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Di atas ${formatIDR(ref.read(appControllerProvider).maxOperationalExpense)} '
                          'butuh persetujuan supervisor.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: canSave
                      ? () async {
                          final appState = ref.read(appControllerProvider);
                          final controller = ref.read(
                            appControllerProvider.notifier,
                          );
                          final plafon = appState.maxOperationalExpense;
                          var approvedBy = '';
                          if (type == CashMovementType.operationalExpense &&
                              amount > plafon) {
                            // Layar ini supervisor-only → supervisor menyetujui otomatis;
                            // PIN hanya diperlukan bila (mis.) admin membuka via konteks lain.
                            if (appState.isSupervisor) {
                              approvedBy = appState.cashierName;
                            } else {
                              final approver =
                                  await showSupervisorApprovalDialog(
                                context,
                                title: 'Persetujuan Supervisor',
                                message:
                                    'Biaya operasional ${formatIDR(amount)} melebihi '
                                    'plafon ${formatIDR(plafon)}. '
                                    'Diperlukan PIN supervisor untuk melanjutkan.',
                              );
                              if (approver == null) {
                                return;
                              }
                              approvedBy = approver;
                            }
                          }
                          final error = await controller.addCashMovement(
                            type: type,
                            amount: amount,
                            notes: notesController.text,
                            approvedBy: approvedBy,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(context);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        }
                      : null,
                  child: const Text('Simpan Mutasi'),
                ),
              ],
            );
          },
        );
      },
    );
    // Controllers are intentionally not disposed here: doing so right after the
    // dialog is popped races its exit animation (use-after-dispose). They are
    // short-lived and garbage-collected once the closure goes out of scope.
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final positive = movement.amount >= 0;
    final icon = switch (movement.type) {
      CashMovementType.initialCapital => Icons.flag_rounded,
      CashMovementType.additionalCapital => Icons.arrow_downward_rounded,
      CashMovementType.ownerWithdrawal => Icons.arrow_upward_rounded,
      CashMovementType.operationalExpense => Icons.receipt_rounded,
      CashMovementType.cashAdjustment => Icons.tune_rounded,
      CashMovementType.manualDrawerOpen => Icons.lock_open_rounded,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: positive ? AppColors.successSoft : AppColors.destructiveSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: positive ? AppColors.success : AppColors.destructive,
        ),
      ),
      title: Row(
        children: [
          Text(
            movement.type.label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          if (movement.type == CashMovementType.manualDrawerOpen)
            const StatusPill(label: 'Buka Laci Manual'),
        ],
      ),
      subtitle: Text(
        '${formatDateTime(movement.createdAt)} - ${movement.createdBy}\n${movement.notes}',
      ),
      trailing: Text(
        movement.amount == 0
            ? formatIDR(0)
            : '${positive ? '+' : ''}${formatIDR(movement.amount)}',
        style: TextStyle(
          color: movement.amount == 0
              ? AppColors.mutedForeground
              : positive
              ? AppColors.success
              : AppColors.destructive,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
