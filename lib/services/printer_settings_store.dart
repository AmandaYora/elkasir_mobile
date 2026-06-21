import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_models.dart';

/// Menyimpan preferensi printer (mode, lebar kertas, printer Bluetooth terpilih)
/// secara lokal di perangkat agar bertahan antar sesi.
class PrinterSettingsStore {
  static const _kMode = 'printer_mode';
  static const _kPaper = 'printer_paper_width';
  static const _kName = 'printer_device_name';
  static const _kAddr = 'printer_device_address';

  Future<PrinterDevice> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_kMode) == 'bluetooth'
        ? PrintMode.bluetooth
        : PrintMode.system;
    return PrinterDevice(
      mode: mode,
      paperWidth: prefs.getString(_kPaper) ?? '80 mm',
      deviceName: prefs.getString(_kName) ?? '',
      deviceAddress: prefs.getString(_kAddr) ?? '',
    );
  }

  Future<void> save(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kMode,
      device.mode == PrintMode.bluetooth ? 'bluetooth' : 'system',
    );
    await prefs.setString(_kPaper, device.paperWidth);
    await prefs.setString(_kName, device.deviceName);
    await prefs.setString(_kAddr, device.deviceAddress);
  }
}
