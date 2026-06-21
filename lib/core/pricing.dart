/// Pricing rules — MUST stay identical to the server (apps/api/internal/domain/pricing.go).
/// Dipakai POS untuk menghitung Layanan & PPN agar total konsisten dengan backend.
library;

/// Pembulatan biaya layanan KE ATAS: sisa thd ribuan ≤500 → x.500, >500 → ribuan berikutnya.
/// Contoh: 1350→1500, 1650→2000, 480→500, 540→1000, 1500→1500.
int roundUpService(int n) {
  if (n <= 0) return 0;
  final rem = n % 1000;
  if (rem == 0) return n;
  final base = n - rem;
  return rem <= 500 ? base + 500 : base + 1000;
}

/// Biaya layanan = roundUpService(percent% × subtotal).
int serviceChargeOf(int subtotal, int percent) =>
    (percent <= 0 || subtotal <= 0) ? 0 : roundUpService(subtotal * percent ~/ 100);

/// PPN = percent% × subtotal bila enabled (tidak dibulatkan).
int taxOf(int subtotal, int percent, bool enabled) =>
    (!enabled || percent <= 0 || subtotal <= 0) ? 0 : subtotal * percent ~/ 100;
