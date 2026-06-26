import 'package:shared_preferences/shared_preferences.dart';

import 'api/config_api.dart';

/// Cache last-known-good PosConfig sebagai fallback saat offline/gagal fetch;
/// in-code default tetap jadi jaring pengaman terakhir bila cache belum ada.
class ConfigStore {
  static const _kService = 'cfg_service_percent';
  static const _kTax = 'cfg_tax_percent';
  static const _kTaxOn = 'cfg_tax_enabled';
  static const _kQris = 'cfg_feature_qris';
  static const _kSelfOrder = 'cfg_feature_self_order';
  static const _kPayCashier = 'cfg_feature_pay_at_cashier';
  static const _kMaxDisc = 'cfg_max_discount_percent';
  static const _kMaxExp = 'cfg_max_operational_expense';
  static const _kVariance = 'cfg_cash_variance_tolerance';
  static const _kHas = 'cfg_present';

  Future<PosConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kHas) ?? false)) return null;
    const d = PosConfig();
    return PosConfig(
      servicePercent: prefs.getInt(_kService) ?? d.servicePercent,
      taxPercent: prefs.getInt(_kTax) ?? d.taxPercent,
      taxEnabled: prefs.getBool(_kTaxOn) ?? d.taxEnabled,
      featureQris: prefs.getBool(_kQris) ?? d.featureQris,
      featureSelfOrder: prefs.getBool(_kSelfOrder) ?? d.featureSelfOrder,
      featurePayAtCashier: prefs.getBool(_kPayCashier) ?? d.featurePayAtCashier,
      maxDiscountPercent: prefs.getInt(_kMaxDisc) ?? d.maxDiscountPercent,
      maxOperationalExpense: prefs.getInt(_kMaxExp) ?? d.maxOperationalExpense,
      cashVarianceTolerance: prefs.getInt(_kVariance) ?? d.cashVarianceTolerance,
    );
  }

  Future<void> save(PosConfig c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kService, c.servicePercent);
    await prefs.setInt(_kTax, c.taxPercent);
    await prefs.setBool(_kTaxOn, c.taxEnabled);
    await prefs.setBool(_kQris, c.featureQris);
    await prefs.setBool(_kSelfOrder, c.featureSelfOrder);
    await prefs.setBool(_kPayCashier, c.featurePayAtCashier);
    await prefs.setInt(_kMaxDisc, c.maxDiscountPercent);
    await prefs.setInt(_kMaxExp, c.maxOperationalExpense);
    await prefs.setInt(_kVariance, c.cashVarianceTolerance);
    await prefs.setBool(_kHas, true);
  }
}
