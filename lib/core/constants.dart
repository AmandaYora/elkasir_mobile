import '../models/pos_models.dart';

/// App identity.
const appBrandName = 'Elkasir';
const appAdminProductName = 'Elkasir Admin';

/// Gambar default (di object storage) untuk produk tanpa gambar. Bucket dipakai
/// bersama dev & prod, jadi URL ini stabil di semua environment.
const defaultProductImageUrl =
    'https://is3.cloudhost.id/elcodelabs/elkasir/upload/defaults/no-image.jpg';

/// Authorization thresholds enforced for UX (mirror the server's store settings;
/// the server is the source of truth and re-checks them).
/// Discounts above this percent of subtotal need supervisor approval.
const maxDiscountPercentWithoutApproval = 10;

/// Operational expenses above this (Rupiah) need supervisor approval.
const maxOperationalExpenseWithoutApproval = 200000;

/// Cash variance above this tolerance (Rupiah) needs supervisor approval on close.
const cashVarianceToleranceWithoutApproval = 5000;

/// Store/outlet identity for this terminal. Configure per device via dart-define;
/// defaults to the brand with blank contact details (no placeholder data).
const storeProfile = StoreProfile(
  name: String.fromEnvironment('STORE_NAME', defaultValue: appBrandName),
  outlet: String.fromEnvironment('STORE_OUTLET', defaultValue: 'POS'),
  address: String.fromEnvironment('STORE_ADDRESS', defaultValue: ''),
  phone: String.fromEnvironment('STORE_PHONE', defaultValue: ''),
  businessType: BusinessType.genericFnb,
  features: BusinessFeatureFlags(),
);
