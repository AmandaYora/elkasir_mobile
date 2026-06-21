import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import 'app_shell.dart';
import 'auth/login_screen.dart';
import 'shift/open_shift_screen.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (!state.isAuthenticated) {
      return const LoginScreen();
    }
    if (state.currentShift == null) {
      return const OpenShiftScreen();
    }
    return const AppShell();
  }
}
