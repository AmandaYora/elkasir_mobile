/// A failure returned by the API layer, carrying a user-facing message plus
/// optional HTTP status and machine-readable error code from the API envelope.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => code == 'network';

  @override
  String toString() => message;
}
