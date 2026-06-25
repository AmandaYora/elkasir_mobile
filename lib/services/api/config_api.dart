import 'api_client.dart';

/// Konfigurasi POS dari server (GET /pos/config): harga (layanan/PPN), fitur yang aktif
/// (untuk hide di klien), dan ambang persetujuan supervisor. Default = fail-open (semua
/// fitur tampil) agar kasir tak pernah terblokir saat offline; server tetap menegakkan.
class PosConfig {
  const PosConfig({
    this.servicePercent = 2,
    this.taxPercent = 11,
    this.taxEnabled = false,
    this.featureQris = true,
    this.featureSelfOrder = true,
    this.featurePayAtCashier = true,
    this.maxDiscountPercent = 10,
    this.maxOperationalExpense = 200000,
    this.cashVarianceTolerance = 5000,
  });

  final int servicePercent;
  final int taxPercent;
  final bool taxEnabled;
  final bool featureQris;
  final bool featureSelfOrder;
  final bool featurePayAtCashier;
  final int maxDiscountPercent;
  final int maxOperationalExpense;
  final int cashVarianceTolerance;

  factory PosConfig.fromJson(Map<String, dynamic> json) {
    final pricing = (json['pricing'] as Map<String, dynamic>?) ?? const {};
    final features = (json['features'] as Map<String, dynamic>?) ?? const {};
    final thresholds = (json['thresholds'] as Map<String, dynamic>?) ?? const {};
    const d = PosConfig();
    return PosConfig(
      servicePercent: (pricing['servicePercent'] as num?)?.toInt() ?? d.servicePercent,
      taxPercent: (pricing['taxPercent'] as num?)?.toInt() ?? d.taxPercent,
      taxEnabled: (pricing['taxEnabled'] as bool?) ?? d.taxEnabled,
      featureQris: (features['qris'] as bool?) ?? d.featureQris,
      featureSelfOrder: (features['selfOrder'] as bool?) ?? d.featureSelfOrder,
      featurePayAtCashier: (features['payAtCashier'] as bool?) ?? d.featurePayAtCashier,
      maxDiscountPercent: (thresholds['maxDiscountPercent'] as num?)?.toInt() ?? d.maxDiscountPercent,
      maxOperationalExpense:
          (thresholds['maxOperationalExpense'] as num?)?.toInt() ?? d.maxOperationalExpense,
      cashVarianceTolerance:
          (thresholds['cashVarianceTolerance'] as num?)?.toInt() ?? d.cashVarianceTolerance,
    );
  }
}

class ConfigApi {
  ConfigApi(this._client);

  final ApiClient _client;

  Future<PosConfig> get() async {
    final data = await _client.get('/pos/config') as Map<String, dynamic>;
    return PosConfig.fromJson(data);
  }
}
