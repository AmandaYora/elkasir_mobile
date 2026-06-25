import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/app_widgets.dart';
import 'app_controller.dart';
import 'app_shell.dart';
import 'auth/login_screen.dart';
import 'shift/open_shift_screen.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    // Splash sementara memulihkan sesi tersimpan (hindari kedip layar login saat cold start).
    if (state.restoring) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogoMark(size: 56),
              SizedBox(height: 20),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }
    if (!state.isAuthenticated) {
      return const LoginScreen();
    }
    if (state.currentShift == null) {
      return const OpenShiftScreen();
    }
    return const AppShell();
  }
}
