import 'api_client.dart';

/// Konfigurasi harga toko untuk POS (GET /pos/pricing). Default aman bila gagal.
class PosPricing {
  const PosPricing({
    this.servicePercent = 2,
    this.taxPercent = 11,
    this.taxEnabled = false,
  });

  final int servicePercent;
  final int taxPercent;
  final bool taxEnabled;
}

class PricingApi {
  PricingApi(this._client);

  final ApiClient _client;

  Future<PosPricing> get() async {
    final data = await _client.get('/pos/pricing') as Map<String, dynamic>;
    return PosPricing(
      servicePercent: (data['servicePercent'] as num?)?.toInt() ?? 2,
      taxPercent: (data['taxPercent'] as num?)?.toInt() ?? 11,
      taxEnabled: (data['taxEnabled'] as bool?) ?? false,
    );
  }
}
