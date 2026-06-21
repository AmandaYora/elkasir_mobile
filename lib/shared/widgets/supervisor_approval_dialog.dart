import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/api_providers.dart';

/// Dialog persetujuan supervisor (step-up authorization).
///
/// Supervisor memasukkan kredensial staf-nya untuk mengotorisasi satu aksi
/// (diverifikasi ke server via `/auth/staff/login` tanpa mengganggu sesi kasir).
/// Mengembalikan nama supervisor penyetuju bila disetujui, atau `null` bila
/// dibatalkan/gagal.
Future<String?> showSupervisorApprovalDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _SupervisorApprovalDialog(title: title, message: message),
  );
}

class _SupervisorApprovalDialog extends ConsumerStatefulWidget {
  const _SupervisorApprovalDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  ConsumerState<_SupervisorApprovalDialog> createState() =>
      _SupervisorApprovalDialogState();
}

class _SupervisorApprovalDialogState
    extends ConsumerState<_SupervisorApprovalDialog> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await ref.read(authApiProvider).verifyStaff(
        _identifierController.text,
        _passwordController.text,
        requireSupervisor: true,
      );
      if (!mounted) return;
      if (name == null) {
        setState(() {
          _busy = false;
          _error = 'Akun ini bukan supervisor.';
        });
        return;
      }
      Navigator.pop(context, name);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 401 ? 'Kredensial tidak valid.' : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Tidak dapat memverifikasi. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _identifierController,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Username Supervisor',
                prefixIcon: Icon(Icons.shield_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onSubmitted: (_) => _approve(),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified_user_rounded),
          label: Text(_busy ? 'Memverifikasi…' : 'Setujui'),
        ),
      ],
    );
  }
}
