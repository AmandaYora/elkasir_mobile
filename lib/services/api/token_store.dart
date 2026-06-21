import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT access/refresh token pair for the POS session.
/// Kept in memory for fast access and mirrored to SharedPreferences so the
/// cashier stays signed in across app restarts.
class TokenStore {
  static const _kAccess = 'elkasir.accessToken';
  static const _kRefresh = 'elkasir.refreshToken';

  String? _access;
  String? _refresh;

  String? get access => _access;
  String? get refresh => _refresh;
  bool get hasSession => _access != null;

  /// Load any persisted tokens into memory (call once at startup).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_kAccess);
    _refresh = prefs.getString(_kRefresh);
  }

  Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, access);
    await prefs.setString(_kRefresh, refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
