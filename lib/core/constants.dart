import '../models/pos_models.dart';

/// App identity.
const appBrandName = 'Elkasir';
const appAdminProductName = 'Elkasir Admin';

/// Gambar default (di object storage) untuk produk tanpa gambar. Bucket dipakai
/// bersama dev & prod, jadi URL ini stabil di semua environment.
const defaultProductImageUrl =
    'https://is3.cloudhost.id/elcodelabs/elkasir/upload/defaults/no-image.jpg';

// Approval thresholds (max discount %, expense ceiling, cash-variance tolerance) now come
// from the server via GET /pos/config (PosAppState.maxDiscountPercent, etc.) so they match
// the admin's store settings; the server remains the source of truth and re-checks them.

/// Store/outlet identity for this terminal. Configure per device via dart-define;
/// defaults to the brand with blank contact details (no placeholder data).
const storeProfile = StoreProfile(
  name: String.fromEnvironment('STORE_NAME', defaultValue: appBrandName),
  outlet: String.fromEnvironment('STORE_OUTLET', defaultValue: 'POS'),
  address: String.fromEnvironment('STORE_ADDRESS', defaultValue: ''),
  phone: String.fromEnvironment('STORE_PHONE', defaultValue: ''),
  businessType: BusinessType.genericFnb,
);
