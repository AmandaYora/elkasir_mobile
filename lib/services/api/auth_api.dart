import 'api_client.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// The authenticated principal returned by the API (`/auth/me`, login `user`).
class AuthSession {
  const AuthSession({
    required this.id,
    required this.name,
    required this.role,
    required this.storeId,
    required this.actor,
  });

  final String id;
  final String name;
  final String role; // cashier | supervisor (staff actor)
  final String storeId;
  final String actor; // staff | admin

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    id: (json['id'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    role: (json['role'] ?? '') as String,
    storeId: (json['storeId'] ?? '') as String,
    actor: (json['actor'] ?? '') as String,
  );
}

/// Auth endpoints for POS staff (actor = staff).
class AuthApi {
  AuthApi(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  /// POS staff login with username + password. Persists the token pair and
  /// returns the staff session on success; throws [ApiException] otherwise.
  Future<AuthSession> staffLogin(String username, String password) async {
    final data =
        await _client.post(
              '/auth/staff/login',
              body: {'username': username.trim(), 'password': password},
              auth: false,
            )
            as Map<String, dynamic>;
    await _tokens.save(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return AuthSession.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Step-up check: confirm a staff credential without saving tokens (current
  /// session untouched). Returns the name, or null if invalid or
  /// [requireSupervisor] is set and the role is not supervisor.
  Future<String?> verifyStaff(
    String username,
    String password, {
    bool requireSupervisor = false,
  }) async {
    final data = await _client.post(
      '/auth/staff/login',
      body: {'username': username.trim(), 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    final session = AuthSession.fromJson(data['user'] as Map<String, dynamic>);
    if (requireSupervisor && session.role != 'supervisor') return null;
    return session.name;
  }

  /// Verify a supervisor approval PIN (`POST /pos/approvals/verify-pin`, rate-limited)
  /// for in-place authorization of cashier actions over a threshold. Returns the
  /// supervisor's name, or null if the PIN is invalid.
  Future<String?> verifySupervisorPin(String pin) async {
    try {
      final data = await _client.post(
        '/pos/approvals/verify-pin',
        body: {'pin': pin.trim()},
      ) as Map<String, dynamic>;
      final name = (data['approvedByName'] ?? '') as String;
      return name.isEmpty ? null : name;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null; // PIN salah
      rethrow;
    }
  }

  /// Resolve the current principal from a stored token (for session restore).
  Future<AuthSession?> me() async {
    if (!_tokens.hasSession) return null;
    final data = await _client.get('/auth/me') as Map<String, dynamic>;
    return AuthSession.fromJson(data);
  }

  /// Best-effort: revoke the refresh token server-side, then clear local tokens.
  Future<void> logout() async {
    final refresh = _tokens.refresh;
    if (refresh != null) {
      try {
        await _client.post(
          '/auth/logout',
          body: {'refreshToken': refresh},
          auth: false,
        );
      } catch (_) {
        // ignore — logout is best effort
      }
    }
    await _tokens.clear();
  }
}
