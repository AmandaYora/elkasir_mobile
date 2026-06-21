import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/constants.dart';
import 'core/theme/app_theme.dart';
import 'features/app_gate.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');
}

Future<void> main() async {
  await bootstrapApp();
  runApp(const ProviderScope(child: ElkasirPosApp()));
}

class ElkasirPosApp extends StatelessWidget {
  const ElkasirPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$appBrandName POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppGate(),
    );
  }
}
