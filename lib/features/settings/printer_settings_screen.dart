import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/theme/app_theme.dart';
import '../../models/pos_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../app_controller.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final printer = state.printer;
    final isBluetooth = printer.mode == PrintMode.bluetooth;

    Future<void> run(
      Future<String?> Function() action, {
      required String okMessage,
    }) async {
      final error = await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? okMessage)));
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Metode Cetak',
                  subtitle: 'Pilih cara mencetak struk.',
                  child: SegmentedButton<PrintMode>(
                    segments: const [
                      ButtonSegment(
                        value: PrintMode.system,
                        label: Text('Sistem / PDF'),
                        icon: Icon(Icons.picture_as_pdf_rounded),
                      ),
                      ButtonSegment(
                        value: PrintMode.bluetooth,
                        label: Text('Thermal Bluetooth'),
                        icon: Icon(Icons.bluetooth_rounded),
                      ),
                    ],
                    selected: {printer.mode},
                    onSelectionChanged: (selection) =>
                        controller.setPrintMode(selection.first),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Ukuran Kertas',
                  child: DropdownButtonFormField<String>(
                    value: printer.paperWidth,
                    decoration: const InputDecoration(labelText: 'Lebar Kertas'),
                    items: const ['58 mm', '80 mm']
                        .map(
                          (width) =>
                              DropdownMenuItem(value: width, child: Text(width)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.setPaperWidth(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (isBluetooth)
                  _BluetoothCard(printer: printer, onPick: () => _pickPrinter(context, ref), run: run)
                else
                  SectionCard(
                    title: 'Tes Cetak',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => run(
                            controller.testPrint,
                            okMessage: 'Membuka dialog cetak…',
                          ),
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Cetak Struk Contoh'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Saat mencetak, pilih printer yang tersambung ke '
                          'perangkat — atau simpan struk sebagai PDF.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPrinter(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final granted = await controller.requestBluetoothPermission();
    if (!context.mounted) return;
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Izin Bluetooth diperlukan.')),
      );
      return;
    }
    if (!await controller.isBluetoothOn) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nyalakan Bluetooth terlebih dahulu.')),
      );
      return;
    }
    final devices = await controller.scanPrinters();
    if (!context.mounted) return;

    final selected = await showModalBottomSheet<BluetoothInfo>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: devices.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tidak ada printer terpasang. Pasangkan printer di '
                  'Pengaturan Bluetooth perangkat dulu, lalu coba lagi.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Pilih printer thermal'),
                  ),
                  for (final device in devices)
                    ListTile(
                      leading: const Icon(Icons.print_rounded),
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      onTap: () => Navigator.pop(sheetContext, device),
                    ),
                ],
              ),
      ),
    );
    if (selected == null) return;
    final error = await controller.selectPrinter(
      selected.name,
      selected.macAdress,
    );
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Tersambung ke ${selected.name}')),
    );
  }
}

class _BluetoothCard extends ConsumerWidget {
  const _BluetoothCard({
    required this.printer,
    required this.onPick,
    required this.run,
  });

  final PrinterDevice printer;
  final VoidCallback onPick;
  final Future<void> Function(
    Future<String?> Function() action, {
    required String okMessage,
  })
  run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    return SectionCard(
      title: 'Printer Bluetooth',
      subtitle: 'Pasangkan printer di Pengaturan Bluetooth perangkat dulu, '
          'lalu pilih di sini.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              printer.connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_rounded,
              color: printer.connected
                  ? AppColors.success
                  : AppColors.mutedForeground,
            ),
            title: Text(
              printer.hasDevice ? printer.deviceName : 'Belum ada printer dipilih',
            ),
            subtitle: Text(
              printer.hasDevice
                  ? '${printer.deviceAddress} · '
                        '${printer.connected ? 'Tersambung' : 'Tidak tersambung'}'
                  : 'Ketuk "Pilih Printer" untuk memilih.',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text('Pilih Printer'),
              ),
              FilledButton.icon(
                onPressed: printer.hasDevice
                    ? () => run(
                        controller.testPrint,
                        okMessage: 'Struk contoh dikirim',
                      )
                    : null,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Tes Cetak'),
              ),
              OutlinedButton.icon(
                onPressed: printer.hasDevice
                    ? () => run(
                        controller.openCashDrawer,
                        okMessage: 'Laci kas terbuka',
                      )
                    : null,
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Tes Buka Laci'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
