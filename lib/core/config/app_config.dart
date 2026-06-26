/// Default base URL targets PRODUCTION; override per build with
/// --dart-define=API_BASE_URL=... (e.g. http://10.0.2.2:8081/api/v1 for the Android emulator).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://elkasir.elcodelabs.com/api/v1',
  );
}
