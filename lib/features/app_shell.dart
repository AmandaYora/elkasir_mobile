import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/pos_models.dart';
import '../shared/widgets/app_widgets.dart';
import 'app_controller.dart';
import 'cash_movements/cash_movements_screen.dart';
import 'checkout/checkout_screen.dart';
import 'incoming/incoming_orders_screen.dart';
import 'pos/pos_screen.dart';
import 'receipt/receipt_preview_screen.dart';
import 'settings/printer_settings_screen.dart';
import 'settings/settings_screen.dart';
import 'shift/close_shift_screen.dart';
import 'shift/shift_summary_screen.dart';
import 'transactions/transactions_screen.dart';

const _expandedSidebarWidth = 250.0;
const _collapsedSidebarWidth = 72.0;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final shift = state.currentShift;
    final title = state.screen.label;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: state.screen,
            hasOpenShift: state.hasOpenShift,
            expanded: _sidebarExpanded,
            store: state.store,
            newOrders: state.newSelfOrderCount,
            onSelect: controller.navigate,
            onToggleExpanded: () =>
                setState(() => _sidebarExpanded = !_sidebarExpanded),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: title,
                  subtitle: _subtitleFor(state.screen),
                  cashierName: state.cashierName,
                  store: state.store,
                  shift: shift,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _screenFor(state.screen, state.hasOpenShift),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _screenFor(AppScreen screen, bool hasOpenShift) {
    if (!hasOpenShift && screen == AppScreen.pos) {
      return const ShiftSummaryScreen(key: ValueKey('shift-closed-summary'));
    }
    switch (screen) {
      case AppScreen.pos:
        return const PosScreen(key: ValueKey('pos'));
      case AppScreen.checkout:
        return const CheckoutScreen(key: ValueKey('checkout'));
      case AppScreen.receipt:
        return const ReceiptPreviewScreen(key: ValueKey('receipt'));
      case AppScreen.transactions:
        return const TransactionsScreen(key: ValueKey('transactions'));
      case AppScreen.incomingOrders:
        return const IncomingOrdersScreen(key: ValueKey('incoming-orders'));
      case AppScreen.shiftSummary:
        return const ShiftSummaryScreen(key: ValueKey('shift-summary'));
      case AppScreen.closeShift:
        return const CloseShiftScreen(key: ValueKey('close-shift'));
      case AppScreen.cashMovements:
        return const CashMovementsScreen(key: ValueKey('cash-movements'));
      case AppScreen.printerSettings:
        return const PrinterSettingsScreen(key: ValueKey('printer-settings'));
      case AppScreen.settings:
        return const SettingsScreen(key: ValueKey('settings'));
    }
  }

  String _subtitleFor(AppScreen screen) {
    switch (screen) {
      case AppScreen.pos:
        return 'Pilih menu, atur pesanan, dan lanjut ke pembayaran.';
      case AppScreen.checkout:
        return 'Pilih metode pembayaran dan selesaikan transaksi.';
      case AppScreen.receipt:
        return 'Pratinjau, cetak, cetak ulang, dan buka laci kas.';
      case AppScreen.transactions:
        return 'Cari transaksi, lihat detail, dan cetak ulang struk.';
      case AppScreen.incomingOrders:
        return 'Pesanan self-order dari QR meja yang menunggu diproses.';
      case AppScreen.shiftSummary:
        return 'Penjualan shift, perkiraan kas, dan selisih.';
      case AppScreen.closeShift:
        return 'Masukkan kas aktual dan rekonsiliasi laci kas.';
      case AppScreen.cashMovements:
        return 'Pantau kas masuk dan kas keluar dari laci.';
      case AppScreen.printerSettings:
        return 'Atur ukuran kertas dan cetak struk.';
      case AppScreen.settings:
        return 'Profil usaha, pratinjau struk, profil staf, dan versi aplikasi.';
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.hasOpenShift,
    required this.expanded,
    required this.store,
    required this.newOrders,
    required this.onSelect,
    required this.onToggleExpanded,
  });

  final AppScreen selected;
  final bool hasOpenShift;
  final bool expanded;
  final StoreProfile store;
  final int newOrders;
  final ValueChanged<AppScreen> onSelect;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? _expandedSidebarWidth : _collapsedSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: expanded ? 82 : 112,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 14 : 8,
                vertical: expanded ? 12 : 8,
              ),
              child: expanded
                  ? Row(
                      children: [
                        const AppLogoMark(size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appBrandName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                store.outlet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('sidebar-toggle'),
                          onPressed: onToggleExpanded,
                          tooltip: 'Ciutkan menu',
                          icon: const Icon(Icons.menu_open_rounded),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogoMark(size: 38),
                        const SizedBox(height: 6),
                        IconButton(
                          key: const ValueKey('sidebar-toggle'),
                          onPressed: onToggleExpanded,
                          tooltip: 'Bentangkan menu',
                          icon: const Icon(Icons.menu_rounded),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 8,
                vertical: 14,
              ),
              children: [
                _NavGroup(
                  label: 'Penjualan',
                  expanded: expanded,
                  children: [
                    _NavItem(
                      key: const ValueKey('nav-pos'),
                      icon: Icons.point_of_sale_rounded,
                      label: 'Kasir',
                      selected: selected == AppScreen.pos,
                      enabled: hasOpenShift,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.pos),
                    ),
                    _NavItem(
                      key: const ValueKey('nav-transactions'),
                      icon: Icons.receipt_long_rounded,
                      label: 'Transaksi',
                      selected: selected == AppScreen.transactions,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.transactions),
                    ),
                    _NavItem(
                      key: const ValueKey('nav-incoming'),
                      icon: Icons.notifications_active_rounded,
                      label: 'Pesanan Masuk',
                      selected: selected == AppScreen.incomingOrders,
                      expanded: expanded,
                      badgeCount: newOrders,
                      onTap: () => onSelect(AppScreen.incomingOrders),
                    ),
                  ],
                ),
                _NavGroup(
                  label: 'Operasional',
                  expanded: expanded,
                  children: [
                    _NavItem(
                      key: const ValueKey('nav-shift-summary'),
                      icon: Icons.schedule_rounded,
                      label: 'Ringkasan Shift',
                      selected: selected == AppScreen.shiftSummary,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.shiftSummary),
                    ),
                    _NavItem(
                      key: const ValueKey('nav-cash-movements'),
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Mutasi Kas',
                      selected: selected == AppScreen.cashMovements,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.cashMovements),
                    ),
                    _NavItem(
                      key: const ValueKey('nav-printer-settings'),
                      icon: Icons.print_rounded,
                      label: 'Pengaturan Struk',
                      selected: selected == AppScreen.printerSettings,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.printerSettings),
                    ),
                  ],
                ),
                _NavGroup(
                  label: 'Sistem',
                  expanded: expanded,
                  children: [
                    _NavItem(
                      key: const ValueKey('nav-settings'),
                      icon: Icons.settings_rounded,
                      label: 'Pengaturan',
                      selected: selected == AppScreen.settings,
                      expanded: expanded,
                      onTap: () => onSelect(AppScreen.settings),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(expanded ? 12 : 8),
            child: _NavItem(
              key: const ValueKey('nav-close-shift'),
              icon: Icons.lock_clock_rounded,
              label: 'Tutup Shift',
              selected: selected == AppScreen.closeShift,
              enabled: hasOpenShift,
              expanded: expanded,
              onTap: () => onSelect(AppScreen.closeShift),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  const _NavGroup({
    required this.label,
    required this.children,
    required this.expanded,
  });

  final String label;
  final List<Widget> children;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: expanded ? 18 : 10),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.expanded,
    this.enabled = true,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final bool expanded;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.foreground;
    final iconColor = enabled ? foreground : AppColors.mutedForeground;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: label,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
              child: expanded
                  ? Row(
                      children: [
                        Icon(icon, color: iconColor, size: 19),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: enabled
                                      ? foreground
                                      : AppColors.mutedForeground,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (badgeCount > 0) _NavBadge(count: badgeCount),
                      ],
                    )
                  : Center(
                      child: badgeCount > 0
                          ? Badge(
                              label: Text('$badgeCount'),
                              child: Icon(icon, color: iconColor, size: 21),
                            )
                          : Icon(icon, color: iconColor, size: 21),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.cashierName,
    required this.store,
    required this.shift,
  });

  final String title;
  final String subtitle;
  final String cashierName;
  final StoreProfile store;
  final Shift? shift;

  @override
  Widget build(BuildContext context) {
    final activeShift = shift;
    final headerActions = [
      if (activeShift != null) ...[
        StatusPill(label: activeShift.status.label),
        const SizedBox(width: 10),
        _HeaderChip(
          icon: Icons.schedule_rounded,
          label: 'Mulai ${formatTime(activeShift.openedAt)}',
        ),
        const SizedBox(width: 10),
      ],
      _HeaderChip(icon: Icons.storefront_rounded, label: store.outlet),
      const SizedBox(width: 10),
      _HeaderChip(icon: Icons.person_rounded, label: cashierName),
    ];

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xCCF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: headerActions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
