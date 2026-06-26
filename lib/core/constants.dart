import '../models/pos_models.dart';

const appBrandName = 'Elkasir';
const appAdminProductName = 'Elkasir Admin';

/// Gambar default untuk produk tanpa gambar; bucket dipakai bersama dev & prod.
const defaultProductImageUrl =
    'https://is3.cloudhost.id/elcodelabs/elkasir/upload/defaults/no-image.jpg';

// Approval thresholds (max discount %, expense ceiling, cash-variance tolerance) come from
// the server via GET /pos/config; the server stays the source of truth and re-checks them.

/// Store/outlet identity per terminal; configure via dart-define.
const storeProfile = StoreProfile(
  name: String.fromEnvironment('STORE_NAME', defaultValue: appBrandName),
  outlet: String.fromEnvironment('STORE_OUTLET', defaultValue: 'POS'),
  address: String.fromEnvironment('STORE_ADDRESS', defaultValue: ''),
  phone: String.fromEnvironment('STORE_PHONE', defaultValue: ''),
  businessType: BusinessType.genericFnb,
);
