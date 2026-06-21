/// Centralized runtime configuration for the POS app.
///
/// Default base URL targets PRODUCTION (https://elkasir.elcodelabs.com/api/v1),
/// so a plain `flutter run`/release build talks to the live server.
///
/// Override for local/LAN dev without editing code, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1     # Android emulator → host
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8081/api/v1  # physical device → LAN
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://elkasir.elcodelabs.com/api/v1',
  );
}
