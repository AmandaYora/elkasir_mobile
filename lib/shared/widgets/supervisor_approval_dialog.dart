import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/api_providers.dart';

/// Hasil persetujuan supervisor. PIN dibawa agar aksi final menyertakannya — server
/// memverifikasi ulang & mencatat penyetuju (anti-spoof). Sesaat: jangan dipersistensi.
class SupervisorApproval {
  const SupervisorApproval({required this.pin, required this.name});

  final String pin;
  final String name;
}

/// Dialog persetujuan supervisor: PIN diverifikasi ke server (`/pos/approvals/verify-pin`,
/// rate-limited) tanpa mengganti sesi kasir. Mengembalikan [SupervisorApproval] atau `null`.
Future<SupervisorApproval?> showSupervisorApprovalDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<SupervisorApproval>(
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
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_busy) return;
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Masukkan PIN supervisor (4–6 digit).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await ref.read(authApiProvider).verifySupervisorPin(pin);
      if (!mounted) return;
      if (name == null) {
        setState(() {
          _busy = false;
          _error = 'PIN supervisor salah.';
        });
        return;
      }
      Navigator.pop(context, SupervisorApproval(pin: pin, name: name));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 429
            ? 'Terlalu banyak percobaan. Tunggu sebentar.'
            : e.message;
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
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _approve(),
              decoration: const InputDecoration(
                labelText: 'PIN Supervisor',
                counterText: '',
                prefixIcon: Icon(Icons.password_rounded),
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
